--!strict

-- Pushes Kitty Caster callouts to Cat Rift players only.
-- Interactive chat stays on AiChatService. This does not call an LLM.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnnouncerLines = require(Shared:WaitForChild("AnnouncerLines"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local ModeService = require(script.Parent.Parent.Mode.ModeService)

local AnnouncerService = {}

local SPEAKER = "Kitty Caster"

type SnapshotFn = () -> Types.MatchSnapshot?

local getSnapshot: SnapshotFn = function()
	return nil
end

local firstBloodTaken = false
local streaks: { [number]: AnnouncerLines.StreakRow } = {}
local lastOrdinaryAt: number? = nil
local roll = 1

local function reset()
	firstBloodTaken = false
	streaks = {}
	lastOrdinaryAt = nil
	roll = 1
end

function AnnouncerService.init(snapshotFn: SnapshotFn)
	getSnapshot = snapshotFn
end

function AnnouncerService.reset()
	reset()
end

-- Humans seated in this rift whose mode is still Cat Rift.
-- Hub, Yarn Run, Koi, Party, and Arcade never get the remote.
local function listeners(): { Player }
	local snapshot = getSnapshot()
	if not snapshot or snapshot.phase == "Lobby" then
		return {}
	end
	local list: { Player } = {}
	for _, player in Players:GetPlayers() do
		local row = snapshot.players[tostring(player.UserId)]
		if row and row.isBot ~= true and ModeService.is(player, "Moba") then
			table.insert(list, player)
		end
	end
	return list
end

local function deliver(callout: AnnouncerLines.Callout)
	if not callout.speak or typeof(callout.line) ~= "string" or callout.line == "" then
		return
	end
	local message = {
		speaker = SPEAKER,
		text = callout.line,
		beat = callout.beat,
		cue = callout.cue,
	}
	for _, player in listeners() do
		Remotes.event("AnnouncerMessage"):FireClient(player, message)
	end
	roll += 1
end

local function deliverTo(player: Player, callout: AnnouncerLines.Callout)
	if not callout.speak or typeof(callout.line) ~= "string" or callout.line == "" then
		return
	end
	Remotes.event("AnnouncerMessage"):FireClient(player, {
		speaker = SPEAKER,
		text = callout.line,
		beat = callout.beat,
		cue = callout.cue,
	})
	roll += 1
end

function AnnouncerService.onDraft(practice: boolean, difficulty: string?)
	reset()
	deliver(AnnouncerLines.draft(practice, difficulty, roll))
end

function AnnouncerService.onLive()
	-- Roll 1 keeps the Studio live-pass line stable. Later beats still vary.
	deliver(AnnouncerLines.live(1))
end

function AnnouncerService.onChampionDown(info: {
	killerUserId: number?,
	killerName: string?,
	victimName: string,
	victimTeam: string,
	cause: string,
	living: number,
	teamSize: number,
})
	local now = os.clock()
	local streak = 0
	if info.cause == "champion" and typeof(info.killerUserId) == "number" then
		local count, nextBook = AnnouncerLines.advanceStreak(streaks, info.killerUserId, now)
		streaks = nextBook
		streak = count
	end
	local finisher = info.killerName
	if info.cause == "tower" then
		finisher = "a scratching post"
	elseif info.cause == "minion" or info.cause == "jungle" then
		finisher = "lane kittens"
	end
	local decision = AnnouncerLines.decideKill({
		now = now,
		firstBloodTaken = firstBloodTaken,
		cause = info.cause,
		streak = streak,
		ace = AnnouncerLines.isAce(info.living, info.teamSize),
		lastOrdinaryAt = lastOrdinaryAt,
		killer = info.killerName,
		victim = info.victimName,
		victimTeam = info.victimTeam,
		finisher = finisher,
		roll = roll,
	})
	firstBloodTaken = true
	-- Priority beats still speak inside the gap, then they start a new one
	-- so the next isolated kill does not pile on.
	if decision.speak then
		lastOrdinaryAt = now
	end
	deliver(decision)
end

function AnnouncerService.onStructure(info: {
	kind: string,
	tier: string,
	team: string,
	lane: string,
	who: string?,
	coreOpened: boolean,
})
	local callouts = AnnouncerLines.structures({
		kind = info.kind,
		tier = info.tier,
		team = info.team,
		lane = info.lane,
		who = info.who,
		coreOpened = info.coreOpened,
		roll = roll,
	})
	for _, callout in callouts do
		deliver(callout)
	end
end

function AnnouncerService.onEpic(team: string, who: string?)
	deliver(AnnouncerLines.epic(team, who, roll))
end

function AnnouncerService.onMatchEnd(winner: Types.TeamId)
	local snapshot = getSnapshot()
	if not snapshot then
		return
	end
	for _, player in listeners() do
		local row = snapshot.players[tostring(player.UserId)]
		if row then
			deliverTo(player, AnnouncerLines.matchEnd(row.team == winner, winner, roll))
		end
	end
end

return AnnouncerService
