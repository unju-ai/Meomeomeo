--!strict

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local AnnouncerLines = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("AnnouncerLines"))
local RiverEpic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RiverEpic"))
local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local PingCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PingCatalog"))
local PingLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PingLogic"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local DamageLog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DamageLog"))
local BountyJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BountyJuice"))
local FarmCredit = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("FarmCredit"))
local LastHitJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LastHitJuice"))
local PracticeRoster = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PracticeRoster"))
local RemakeLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RemakeLogic"))
local SurrenderLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SurrenderLogic"))
local Progression = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Progression"))
local XpJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("XpJuice"))
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local StructureLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("StructureLogic"))

local AnnouncerService = require(script.Parent.AnnouncerService)
local BotService = require(script.Parent.BotService)
local CombatService = require(script.Parent.CombatService)
local MatchTeleport = require(script.Parent.MatchTeleport)
local Config = require(script.Parent.Parent.Config)
local JungleService = require(script.Parent.JungleService)
local FxRelay = require(script.Parent.Parent.World.FxRelay)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local MemeStockService = require(script.Parent.Parent.Economy.MemeStockService)
local MinionService = require(script.Parent.MinionService)
local ShopService = require(script.Parent.ShopService)
local TowerService = require(script.Parent.TowerService)
local VisionService = require(script.Parent.VisionService)
local VoiceService = require(script.Parent.Parent.Voice.VoiceService)
local WardService = require(script.Parent.WardService)
local CosmeticService = require(script.Parent.Parent.Cosmetics.CosmeticService)
local ModeService = require(script.Parent.Parent.Mode.ModeService)

local MatchService = {}

local current: Types.MatchSnapshot? = nil
local lastPingAt: { [number]: number } = {}
local phaseToken = 0
-- Monotonic per team so a finished ballot's timer cannot resolve the next one.
local surrenderSerial: { [Types.TeamId]: number } = {
	Blue = 0,
	Red = 0,
}
local remakeSerial: { [Types.TeamId]: number } = {
	Blue = 0,
	Red = 0,
}
local onMatchCleared: (() -> ())? = nil
local nextBotId = -1001

local function blankSurrender(): Types.SurrenderView
	return {
		ballots = {},
		blueCooldownUntil = nil,
		redCooldownUntil = nil,
		noticeId = 0,
		notice = nil,
		noticeTeam = nil,
	}
end

local function blankRemake(): Types.RemakeView
	return {
		ballots = {},
		blueCooldownUntil = nil,
		redCooldownUntil = nil,
		noticeId = 0,
		notice = nil,
		noticeTeam = nil,
	}
end

local function blankPlayer(userId: number, displayName: string, team: Types.TeamId, isBot: boolean, championId: string?): Types.MatchPlayer
	return {
		userId = userId,
		displayName = displayName,
		team = team,
		championId = championId,
		ready = isBot,
		kills = 0,
		deaths = 0,
		assists = 0,
		gold = Config.Match.StartingGold,
		xp = 0,
		level = 1,
		ranks = Progression.autoRanks(1),
		respawnAt = nil,
		cs = 0,
		connected = true,
		items = {},
		damageDealt = 0,
		isBot = isBot,
	}
end

local function championTaken(players: { [string]: Types.MatchPlayer }, team: Types.TeamId, championId: string): boolean
	for _, matchPlayer in players do
		if matchPlayer.team == team and matchPlayer.championId == championId then
			return true
		end
	end
	return false
end

local function pickBotChampion(players: { [string]: Types.MatchPlayer }, team: Types.TeamId): string
	for _, id in Config.Bots.Pool do
		if ChampionCatalog.get(id) and not championTaken(players, team, id) then
			return id
		end
	end
	for _, id in ChampionCatalog.ids() do
		if not championTaken(players, team, id) then
			return id
		end
	end
	return ChampionCatalog.defaultId()
end

local function addBot(players: { [string]: Types.MatchPlayer }, team: Types.TeamId, deferChampion: boolean?)
	-- Practice allies wait until humans lock so they do not take the human's cat.
	local championId = if deferChampion then nil else pickBotChampion(players, team)
	local champ = if championId then ChampionCatalog.get(championId) else nil
	local userId = nextBotId
	nextBotId -= 1
	local label = if champ then champ.name else "Ally"
	players[tostring(userId)] = blankPlayer(userId, `{label} (Bot)`, team, true, championId)
end

local function countTeam(players: { [string]: Types.MatchPlayer }, team: Types.TeamId, botsOnly: boolean?): number
	local n = 0
	for _, matchPlayer in players do
		if matchPlayer.team == team then
			if botsOnly then
				if matchPlayer.isBot then
					n += 1
				end
			else
				n += 1
			end
		end
	end
	return n
end

local function fillBots(players: { [string]: Types.MatchPlayer }, practice: boolean, padQueue: boolean?)
	if practice then
		for _ = 1, Config.Bots.PracticeEnemies do
			addBot(players, "Red")
		end
		-- Humans are already seated. Ally bots only fill the Blue seats left
		-- under QueueFillTo, and never more than PracticeAllies. They still
		-- wait to lock a cat until the humans do.
		local blueHumans = countTeam(players, "Blue") - countTeam(players, "Blue", true)
		local allies = PracticeRoster.allyCount(blueHumans, Config.Bots.PracticeAllies, Config.Bots.QueueFillTo)
		for _ = 1, allies do
			addBot(players, "Blue", true)
		end
		return
	end
	if padQueue == false or (padQueue == nil and not Config.Match.PadQueueWithBots) then
		return
	end
	local fillTo = Config.Bots.QueueFillTo
	for _, team in { "Blue" :: Types.TeamId, "Red" :: Types.TeamId } do
		local have = countTeam(players, team)
		for _ = have + 1, fillTo do
			addBot(players, team)
		end
	end
end

local function teamInstance(teamId: Types.TeamId): Team?
	local name = if teamId == "Blue" then Constants.Teams.BlueInstance else Constants.Teams.RedInstance
	local team = Teams:FindFirstChild(name)
	if team and team:IsA("Team") then
		return team
	end
	return nil
end

local function broadcast()
	if current then
		current.objectives = MapBuilder.objectiveStates()
	end
	Remotes.event("MatchStateChanged"):FireAllClients(current)
end

local function feed(kind: Types.FeedKind, text: string)
	Remotes.event("KillFeed"):FireAllClients({
		kind = kind,
		text = text,
		at = Workspace:GetServerTimeNow(),
	} :: Types.FeedEvent)
end

local function teleport(player: Player, team: Types.TeamId?)
	local spawn = MapBuilder.getSpawn(team)
	player.RespawnLocation = spawn
	local character = player.Character
	if character then
		local ok = pcall(function()
			character:PivotTo(spawn.CFrame + Vector3.new(0, 5, 0))
		end)
		if not ok then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				root.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
			end
		end
	end
end

local function assignRobloxTeam(player: Player, teamId: Types.TeamId?)
	if teamId then
		player.Team = teamInstance(teamId)
		player.Neutral = false
	else
		player.Team = nil
		player.Neutral = true
	end
end

function MatchService.snapshot(): Types.MatchSnapshot?
	if current then
		current.objectives = MapBuilder.objectiveStates()
	end
	return current
end

function MatchService.isBusy(): boolean
	return current ~= nil
end

function MatchService.isEnded(): boolean
	return current ~= nil and current.phase == "Ended"
end

function MatchService.lobbyPlaceId(): number
	if current and current.lobbyPlaceId and current.lobbyPlaceId > 0 then
		return current.lobbyPlaceId
	end
	if Config.Match.LobbyPlaceId > 0 then
		return Config.Match.LobbyPlaceId
	end
	return game.PlaceId
end

function MatchService.isReserved(): boolean
	return current ~= nil and current.reserved == true
end

local function pickMvp(): number?
	if not current then
		return nil
	end
	local best: Types.MatchPlayer? = nil
	for _, matchPlayer in current.players do
		if not best then
			best = matchPlayer
		elseif matchPlayer.kills > best.kills then
			best = matchPlayer
		elseif matchPlayer.kills == best.kills then
			local dmg = matchPlayer.damageDealt or 0
			local bestDmg = best.damageDealt or 0
			if dmg > bestDmg then
				best = matchPlayer
			elseif dmg == bestDmg and matchPlayer.gold > best.gold then
				best = matchPlayer
			end
		end
	end
	return if best then best.userId else nil
end

function MatchService.returnToLobby(formQueue: boolean)
	local reserved = current ~= nil and current.reserved == true
	local lobbyId = MatchService.lobbyPlaceId()
	local humans: { Player } = {}
	if current then
		for _, matchPlayer in current.players do
			local person = Players:GetPlayerByUserId(matchPlayer.userId)
			if person then
				table.insert(humans, person)
			end
		end
	end
	if #humans == 0 then
		humans = Players:GetPlayers()
	end
	phaseToken += 1
	MinionService.stop()
	JungleService.stop()
	TowerService.stop()
	VisionService.stop()
	WardService.stop()
	BotService.stop()
	CombatService.clearAll()
	ShopService.clearAll()
	nextBotId = -1001
	for _, player in humans do
		if
			not ModeService.is(player, "YarnRun")
			and not ModeService.is(player, "KoiPond")
			and not ModeService.is(player, "YarnParty")
			and not ModeService.is(player, "MemeArcade")
		then
			assignRobloxTeam(player, nil)
			teleport(player, nil)
			ModeService.set(player, "Hub")
		end
	end
	VoiceService.onTeamsChanged()
	current = nil
	if reserved then
		MatchTeleport.returnToLobby(humans, lobbyId)
		Remotes.event("MatchStateChanged"):FireAllClients(nil)
		return
	end
	if formQueue and onMatchCleared then
		onMatchCleared()
	end
	Remotes.event("MatchStateChanged"):FireAllClients(nil)
end

local function lockDeferredBots()
	if not current then
		return
	end
	for _, matchPlayer in current.players do
		if matchPlayer.isBot and not matchPlayer.championId then
			local championId = pickBotChampion(current.players, matchPlayer.team)
			local champ = ChampionCatalog.get(championId)
			matchPlayer.championId = championId
			matchPlayer.displayName = `{(if champ then champ.name else championId)} (Bot)`
			matchPlayer.ready = true
		end
	end
end

local function autoAssignChampions()
	if not current then
		return
	end
	local used: { [string]: boolean } = {}
	for _, matchPlayer in current.players do
		if matchPlayer.championId then
			used[matchPlayer.championId] = true
		end
	end
	for _, matchPlayer in current.players do
		-- Deferred Practice allies lock after humans, from the bot pool.
		if matchPlayer.isBot then
			continue
		end
		if not matchPlayer.championId then
			for _, id in ChampionCatalog.ids() do
				if not used[id] then
					matchPlayer.championId = id
					used[id] = true
					break
				end
			end
			if not matchPlayer.championId then
				matchPlayer.championId = ChampionCatalog.defaultId()
			end
		end
		matchPlayer.ready = true
	end
	lockDeferredBots()
end

local function beginFight()
	if not current then
		return
	end
	current.phase = "InProgress"
	current.startedAt = Workspace:GetServerTimeNow()
	current.phaseEndsAt = nil
	current.riverEpic = {
		phase = "waiting",
		blueBuff = false,
		redBuff = false,
		nextAt = RiverEpic.dueAt(current.startedAt, "waiting", nil),
	}
	MapBuilder.build()
	current.objectives = MapBuilder.objectiveStates()
	current.structureFalls = {}

	ShopService.clearAll()
	for _, player in Players:GetPlayers() do
		local matchPlayer = current.players[tostring(player.UserId)]
		if matchPlayer and matchPlayer.championId then
			assignRobloxTeam(player, matchPlayer.team)
			CombatService.reset(player, matchPlayer.championId)
			teleport(player, matchPlayer.team)
		end
	end

	VoiceService.onTeamsChanged()
	MapBuilder.refreshNexusGate()
	MinionService.start()
	JungleService.start()
	TowerService.start()
	VisionService.start()
	WardService.start()
	BotService.start()
	AnnouncerService.onLive()
	broadcast()
end

local function riftHuman(userId: number?): Player?
	if typeof(userId) ~= "number" or not current then
		return nil
	end
	local matchPlayer = current.players[tostring(userId)]
	if not matchPlayer or matchPlayer.isBot then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local function surrenderView(): Types.SurrenderView?
	if not current then
		return nil
	end
	if not current.surrender then
		current.surrender = blankSurrender()
	end
	return current.surrender
end

local function surrenderSeats(): { SurrenderLogic.Seat }
	local seats: { SurrenderLogic.Seat } = {}
	if not current then
		return seats
	end
	for _, matchPlayer in current.players do
		table.insert(seats, SurrenderLogic.seat(
			matchPlayer.userId,
			matchPlayer.team,
			matchPlayer.isBot,
			matchPlayer.respawnAt,
			matchPlayer.connected
		))
	end
	return seats
end

local function ballotFor(team: Types.TeamId): Types.SurrenderBallot?
	local view = surrenderView()
	if not view then
		return nil
	end
	for _, ballot in view.ballots do
		if ballot.team == team then
			return ballot
		end
	end
	return nil
end

local function dropBallot(team: Types.TeamId)
	local view = surrenderView()
	if not view then
		return
	end
	local kept: { Types.SurrenderBallot } = {}
	for _, ballot in view.ballots do
		if ballot.team ~= team then
			table.insert(kept, ballot)
		end
	end
	view.ballots = kept
end

local function cooldownUntil(team: Types.TeamId): number?
	local view = surrenderView()
	if not view then
		return nil
	end
	if team == "Blue" then
		return view.blueCooldownUntil
	end
	return view.redCooldownUntil
end

local function setCooldown(team: Types.TeamId, at: number)
	local view = surrenderView()
	if not view then
		return
	end
	if team == "Blue" then
		view.blueCooldownUntil = at
	else
		view.redCooldownUntil = at
	end
end

local function surrenderNotice(team: Types.TeamId, text: string)
	local view = surrenderView()
	if not view then
		return
	end
	view.noticeId = (view.noticeId or 0) + 1
	view.notice = text
	view.noticeTeam = team
end

local function invalidateSurrender(team: Types.TeamId)
	surrenderSerial[team] += 1
end

local function failSurrender(team: Types.TeamId)
	if not current or current.phase ~= "InProgress" or not ballotFor(team) then
		return
	end
	invalidateSurrender(team)
	dropBallot(team)
	setCooldown(team, Workspace:GetServerTimeNow() + SurrenderLogic.CooldownSeconds)
	surrenderNotice(team, SurrenderLogic.failedNotice())
	broadcast()
end

local function passSurrender(team: Types.TeamId)
	if not current or current.phase ~= "InProgress" then
		return
	end
	local winner: Types.TeamId = if team == "Blue" then "Red" else "Blue"
	dropBallot(team)
	MatchService.endMatch(winner, "surrender")
end

local function resolveSurrender(team: Types.TeamId)
	local ballot = ballotFor(team)
	if not ballot or not current or current.phase ~= "InProgress" then
		return
	end
	local result = SurrenderLogic.tally(surrenderSeats(), ballot)
	if result.outcome == "pass" then
		passSurrender(team)
	elseif result.outcome == "fail" then
		failSurrender(team)
	end
end

local function armSurrender(team: Types.TeamId)
	invalidateSurrender(team)
	local token = surrenderSerial[team]
	local matchId = if current then current.id else ""
	task.delay(SurrenderLogic.WindowSeconds, function()
		if not current or current.id ~= matchId or current.phase ~= "InProgress" then
			return
		end
		if surrenderSerial[team] ~= token then
			return
		end
		local ballot = ballotFor(team)
		if not ballot then
			return
		end
		local result = SurrenderLogic.tally(surrenderSeats(), ballot)
		if SurrenderLogic.timeoutOutcome(result) == "pass" then
			passSurrender(team)
		else
			failSurrender(team)
		end
	end)
end

local function recheckSurrender(team: Types.TeamId)
	if ballotFor(team) then
		resolveSurrender(team)
	end
end

local function remakeView(): Types.RemakeView?
	if not current then
		return nil
	end
	if not current.remake then
		current.remake = blankRemake()
	end
	return current.remake
end

local function remakeSeats(): { RemakeLogic.Seat }
	local seats: { RemakeLogic.Seat } = {}
	if not current then
		return seats
	end
	for _, matchPlayer in current.players do
		table.insert(seats, RemakeLogic.seat(
			matchPlayer.userId,
			matchPlayer.team,
			matchPlayer.isBot,
			matchPlayer.respawnAt,
			matchPlayer.connected
		))
	end
	return seats
end

local function remakeBallotFor(team: Types.TeamId): Types.RemakeBallot?
	local view = remakeView()
	if not view then
		return nil
	end
	for _, ballot in view.ballots do
		if ballot.team == team then
			return ballot
		end
	end
	return nil
end

local function dropRemakeBallot(team: Types.TeamId)
	local view = remakeView()
	if not view then
		return
	end
	local kept: { Types.RemakeBallot } = {}
	for _, ballot in view.ballots do
		if ballot.team ~= team then
			table.insert(kept, ballot)
		end
	end
	view.ballots = kept
end

local function remakeCooldownUntil(team: Types.TeamId): number?
	local view = remakeView()
	if not view then
		return nil
	end
	if team == "Blue" then
		return view.blueCooldownUntil
	end
	return view.redCooldownUntil
end

local function setRemakeCooldown(team: Types.TeamId, at: number)
	local view = remakeView()
	if not view then
		return
	end
	if team == "Blue" then
		view.blueCooldownUntil = at
	else
		view.redCooldownUntil = at
	end
end

local function remakeNotice(team: Types.TeamId, text: string)
	local view = remakeView()
	if not view then
		return
	end
	view.noticeId = (view.noticeId or 0) + 1
	view.notice = text
	view.noticeTeam = team
end

local function invalidateRemake(team: Types.TeamId)
	remakeSerial[team] += 1
end

local function failRemake(team: Types.TeamId)
	if not current or current.phase ~= "InProgress" or not remakeBallotFor(team) then
		return
	end
	invalidateRemake(team)
	dropRemakeBallot(team)
	setRemakeCooldown(team, Workspace:GetServerTimeNow() + RemakeLogic.CooldownSeconds)
	remakeNotice(team, RemakeLogic.failedNotice())
	broadcast()
end

local function passRemake(team: Types.TeamId)
	if not current or current.phase ~= "InProgress" then
		return
	end
	dropRemakeBallot(team)
	MatchService.endMatch(nil, "remake")
end

local function resolveRemake(team: Types.TeamId)
	local ballot = remakeBallotFor(team)
	if not ballot or not current or current.phase ~= "InProgress" then
		return
	end
	local result = RemakeLogic.tally(remakeSeats(), ballot)
	if result.outcome == "pass" then
		passRemake(team)
	elseif result.outcome == "fail" then
		failRemake(team)
	end
end

local function armRemake(team: Types.TeamId)
	invalidateRemake(team)
	local token = remakeSerial[team]
	local matchId = if current then current.id else ""
	task.delay(RemakeLogic.WindowSeconds, function()
		if not current or current.id ~= matchId or current.phase ~= "InProgress" then
			return
		end
		if remakeSerial[team] ~= token then
			return
		end
		local ballot = remakeBallotFor(team)
		if not ballot then
			return
		end
		local result = RemakeLogic.tally(remakeSeats(), ballot)
		if RemakeLogic.timeoutOutcome(result) == "pass" then
			passRemake(team)
		else
			failRemake(team)
		end
	end)
end

local function recheckRemake(team: Types.TeamId)
	if remakeBallotFor(team) then
		resolveRemake(team)
	end
end

function MatchService.endMatch(winner: Types.TeamId?, reason: string)
	if not current or current.phase == "Ended" then
		return
	end
	local remake = reason == "remake"
	current.phase = "Ended"
	current.winner = if remake then nil else winner
	current.endReason = if remake then "remake" elseif reason == "surrender" then "surrender" else "nexus"
	current.endedAt = Workspace:GetServerTimeNow()
	current.phaseEndsAt = Workspace:GetServerTimeNow() + Config.Match.PostMatchSeconds
	if current.surrender then
		current.surrender.ballots = {}
	end
	if current.remake then
		current.remake.ballots = {}
	end
	surrenderSerial.Blue += 1
	surrenderSerial.Red += 1
	remakeSerial.Blue += 1
	remakeSerial.Red += 1
	MinionService.stop()
	JungleService.stop()
	TowerService.stop()
	VisionService.stop()
	WardService.stop()
	BotService.stop()
	current.mvpUserId = pickMvp()
	CombatService.clearAll()
	if remake then
		feed("announce", "Remake. Fight called early.")
		AnnouncerService.onMatchEnd(nil, "remake")
	elseif reason == "surrender" and winner then
		local folded: Types.TeamId = if winner == "Blue" then "Red" else "Blue"
		feed("announce", `{folded} surrendered. {winner} takes the night market.`)
		AnnouncerService.onMatchEnd(winner, "surrender")
	elseif winner then
		feed("announce", `{winner} destroyed the enemy nexus!`)
		AnnouncerService.onMatchEnd(winner, nil)
	end
	-- A remake has no winner, so it does not pay a rift win or a loss yarn.
	if not remake and winner then
		for _, matchPlayer in current.players do
			local player = riftHuman(matchPlayer.userId)
			if player then
				CosmeticService.noteRiftMatchEnd(player, matchPlayer.team == winner)
			end
		end
	end
	-- Sides stay assigned through the end screen. Rewrite lists in case a
	-- death at the nexus swapped the mic device.
	VoiceService.onTeamsChanged()
	broadcast()

	local token = phaseToken
	task.delay(Config.Match.PostMatchSeconds, function()
		if token ~= phaseToken then
			return
		end
		MatchService.returnToLobby(true)
	end)
end

function MatchService.start(
	participants: { Player },
	practice: boolean,
	difficulty: Types.BotDifficulty?,
	seats: { Types.MatchTeleportSeat }?,
	options: { lobbyPlaceId: number?, reserved: boolean?, padWithBots: boolean?, matchId: string? }?
)
	if MatchService.isBusy() then
		return false, "A match is already running."
	end
	if #participants == 0 and not (seats and #seats > 0) then
		return false, "Need at least one cat."
	end

	phaseToken += 1
	local token = phaseToken
	MapBuilder.build()

	local players: { [string]: Types.MatchPlayer } = {}
	if seats then
		for _, seat in seats do
			local present = Players:GetPlayerByUserId(seat.userId)
			players[tostring(seat.userId)] = blankPlayer(
				seat.userId,
				seat.displayName,
				seat.team,
				false,
				seat.championId
			)
			players[tostring(seat.userId)].connected = present ~= nil
			players[tostring(seat.userId)].ready = seat.championId ~= nil
			if present then
				assignRobloxTeam(present, seat.team)
				teleport(present, nil)
				ModeService.set(present, "Moba")
			end
		end
	end
	for index, player in participants do
		if players[tostring(player.UserId)] then
			continue
		end
		local team: Types.TeamId = if index % 2 == 1 then "Blue" else "Red"
		if practice then
			team = "Blue"
		end
		players[tostring(player.UserId)] = blankPlayer(player.UserId, player.DisplayName, team, false, nil)
		assignRobloxTeam(player, team)
		teleport(player, nil)
		ModeService.set(player, "Moba")
	end
	local pad = if options and options.padWithBots ~= nil then options.padWithBots else nil
	fillBots(players, practice, pad)

	current = {
		id = (options and options.matchId) or `meo-{token}`,
		phase = "ChampionSelect",
		practice = practice,
		phaseEndsAt = Workspace:GetServerTimeNow() + Config.Match.ChampionSelectSeconds,
		startedAt = nil,
		endedAt = nil,
		winner = nil,
		mvpUserId = nil,
		botDifficulty = difficulty or Config.Bots.DefaultDifficulty,
		players = players,
		objectives = MapBuilder.objectiveStates(),
		structureFalls = {},
		endReason = nil,
		surrender = blankSurrender(),
		remake = blankRemake(),
		riverEpic = {
			phase = "waiting",
			blueBuff = false,
			redBuff = false,
			nextAt = nil,
		},
		queueCount = 0,
		lobbyPlaceId = if options then options.lobbyPlaceId else nil,
		reserved = if options then options.reserved else false,
	}

	VoiceService.onTeamsChanged()
	AnnouncerService.onDraft(practice, current.botDifficulty)
	broadcast()

	task.delay(Config.Match.ChampionSelectSeconds, function()
		if token ~= phaseToken or not current or current.phase ~= "ChampionSelect" then
			return
		end
		autoAssignChampions()
		beginFight()
	end)

	return true, nil
end

function MatchService.selectChampion(player: Player, championId: unknown): Types.TradeResult
	if not current or current.phase ~= "ChampionSelect" then
		return { ok = false, error = "Not in champion select." }
	end
	if typeof(championId) ~= "string" or not ChampionCatalog.get(championId) then
		return { ok = false, error = "Unknown champion." }
	end
	local matchPlayer = current.players[tostring(player.UserId)]
	if not matchPlayer then
		return { ok = false, error = "You are not in this match." }
	end
	for _, other in current.players do
		if other.userId ~= player.UserId and other.championId == championId and other.team == matchPlayer.team then
			return { ok = false, error = "Teammate already locked that cat." }
		end
	end
	matchPlayer.championId = championId
	matchPlayer.ready = true
	broadcast()

	local allHumansReady = true
	for _, other in current.players do
		if not other.isBot and not other.championId then
			allHumansReady = false
			break
		end
	end
	if allHumansReady then
		phaseToken += 1
		autoAssignChampions()
		beginFight()
	end
	return { ok = true }
end

function MatchService.surrender(player: Player, action: unknown): Types.TradeResult
	if not current or current.phase ~= "InProgress" then
		return { ok = false, error = SurrenderLogic.QuietToast }
	end
	local view = surrenderView()
	if not view then
		return { ok = false, error = SurrenderLogic.QuietToast }
	end
	if typeof(action) ~= "string" or (action ~= "start" and action ~= "yes" and action ~= "no") then
		return { ok = false, error = SurrenderLogic.NoVoteToast }
	end
	local choice = action
	local matchPlayer = current.players[tostring(player.UserId)]
	if not matchPlayer then
		return { ok = false, error = "You are not in this match." }
	end
	local team = matchPlayer.team
	local ballot = ballotFor(team)
	if choice == "start" and ballot ~= nil then
		choice = "yes"
	end
	local now = Workspace:GetServerTimeNow()
	local alive = matchPlayer.respawnAt == nil
	local connected = matchPlayer.connected ~= false
	if choice == "start" then
		local blocked = RemakeLogic.blocksFold(remakeBallotFor(team) ~= nil)
		if blocked then
			return { ok = false, error = blocked }
		end
		local refusal = SurrenderLogic.startRefusal({
			phase = current.phase,
			elapsed = SurrenderLogic.elapsed(now, current.startedAt),
			isBot = matchPlayer.isBot == true,
			alive = alive,
			connected = connected,
			voteOpen = false,
			cooldownUntil = cooldownUntil(team),
			now = now,
		})
		if refusal then
			return { ok = false, error = refusal }
		end
		local opened: Types.SurrenderBallot = {
			team = team,
			endsAt = now + SurrenderLogic.WindowSeconds,
			yesUserIds = { player.UserId },
			noUserIds = {},
		}
		table.insert(view.ballots, opened)
		local result = SurrenderLogic.tally(surrenderSeats(), opened)
		if result.outcome == "pass" then
			passSurrender(team)
			return { ok = true }
		end
		if result.outcome == "fail" then
			failSurrender(team)
			return { ok = true }
		end
		surrenderNotice(team, SurrenderLogic.openedNotice(matchPlayer.displayName))
		armSurrender(team)
		broadcast()
		return { ok = true }
	end

	local already = if ballot then SurrenderLogic.voted(ballot, player.UserId) else false
	local refusal = SurrenderLogic.voteRefusal({
		isBot = matchPlayer.isBot == true,
		alive = alive,
		connected = connected,
		voteOpen = ballot ~= nil,
		already = already,
	})
	if refusal then
		return { ok = false, error = refusal }
	end
	local open = ballotFor(team)
	if not open then
		return { ok = false, error = SurrenderLogic.NoVoteToast }
	end
	if choice == "no" then
		table.insert(open.noUserIds, player.UserId)
	else
		table.insert(open.yesUserIds, player.UserId)
	end
	resolveSurrender(team)
	if current and current.phase == "InProgress" and ballotFor(team) then
		broadcast()
	end
	return { ok = true }
end

function MatchService.remake(player: Player, action: unknown): Types.TradeResult
	if not current or current.phase ~= "InProgress" then
		return { ok = false, error = RemakeLogic.QuietToast }
	end
	local view = remakeView()
	if not view then
		return { ok = false, error = RemakeLogic.QuietToast }
	end
	if typeof(action) ~= "string" or (action ~= "start" and action ~= "yes" and action ~= "no") then
		return { ok = false, error = RemakeLogic.NoVoteToast }
	end
	local choice = action
	local matchPlayer = current.players[tostring(player.UserId)]
	if not matchPlayer then
		return { ok = false, error = "You are not in this match." }
	end
	local team = matchPlayer.team
	local ballot = remakeBallotFor(team)
	if choice == "start" and ballot ~= nil then
		choice = "yes"
	end
	local now = Workspace:GetServerTimeNow()
	local alive = matchPlayer.respawnAt == nil
	local connected = matchPlayer.connected ~= false
	if choice == "start" then
		local seats = remakeSeats()
		local refusal = RemakeLogic.startRefusal({
			phase = current.phase,
			elapsed = RemakeLogic.elapsed(now, current.startedAt),
			isBot = matchPlayer.isBot == true,
			alive = alive,
			connected = connected,
			voteOpen = false,
			surrenderOpen = ballotFor(team) ~= nil,
			practice = current.practice == true,
			allyMissing = RemakeLogic.allyMissing(seats, team),
			cooldownUntil = remakeCooldownUntil(team),
			now = now,
		})
		if refusal then
			return { ok = false, error = refusal }
		end
		local opened: Types.RemakeBallot = {
			team = team,
			endsAt = now + RemakeLogic.WindowSeconds,
			yesUserIds = { player.UserId },
			noUserIds = {},
		}
		table.insert(view.ballots, opened)
		local result = RemakeLogic.tally(seats, opened)
		if result.outcome == "pass" then
			passRemake(team)
			return { ok = true }
		end
		if result.outcome == "fail" then
			failRemake(team)
			return { ok = true }
		end
		remakeNotice(team, RemakeLogic.openedNotice(matchPlayer.displayName))
		armRemake(team)
		broadcast()
		return { ok = true }
	end

	local already = if ballot then RemakeLogic.voted(ballot, player.UserId) else false
	local refusal = RemakeLogic.voteRefusal({
		isBot = matchPlayer.isBot == true,
		alive = alive,
		connected = connected,
		voteOpen = ballot ~= nil,
		already = already,
	})
	if refusal then
		return { ok = false, error = refusal }
	end
	local open = remakeBallotFor(team)
	if not open then
		return { ok = false, error = RemakeLogic.NoVoteToast }
	end
	if choice == "no" then
		table.insert(open.noUserIds, player.UserId)
	else
		table.insert(open.yesUserIds, player.UserId)
	end
	resolveRemake(team)
	if current and current.phase == "InProgress" and remakeBallotFor(team) then
		broadcast()
	end
	return { ok = true }
end

function MatchService.setQueueCount(count: number)
	if current then
		current.queueCount = count
	end
end

local function catLabel(matchPlayer: Types.MatchPlayer): string
	local champName: string? = nil
	if matchPlayer.championId then
		local champ = ChampionCatalog.get(matchPlayer.championId)
		if champ then
			champName = champ.name
		end
	end
	return AnnouncerLines.catName(champName, matchPlayer.displayName)
end

local function killingKind(victimUserId: number): string?
	local lines = DamageLog.recap(victimUserId, Workspace:GetServerTimeNow())
	for _, line in lines do
		if line.killingBlow then
			return line.sourceKind
		end
	end
	return nil
end

local function rosterLiving(team: Types.TeamId): (number, number)
	local living = 0
	local size = 0
	if not current then
		return living, size
	end
	for _, matchPlayer in current.players do
		if matchPlayer.team == team then
			size += 1
			if matchPlayer.respawnAt == nil then
				living += 1
			end
		end
	end
	return living, size
end

function MatchService.init(cleared: () -> ())
	onMatchCleared = cleared
	AnnouncerService.init(MatchService.snapshot)

	-- Lane kitten and camp last hits. One CS plus that gold. The paint cue
	-- uses the same credit and does not grant extra gold. Bounties do not enter here.
	local function creditLastHit(userId: number, gold: number, position: Vector3): boolean
		if not current then
			return false
		end
		local matchPlayer = current.players[tostring(userId)]
		if not matchPlayer then
			return false
		end
		local credit = FarmCredit.lastHit(gold)
		FarmCredit.apply(matchPlayer, credit)
		if LastHitJuice.wantsFloat(credit.cs, credit.gold) then
			FxRelay.lastHit(position, userId, credit.gold)
		end
		return true
	end

	-- Kill, assist, tower, and nexus gold. No CS. The paint cue uses the same
	-- credit and does not grant extra gold. Last hits do not enter here.
	local function creditBounty(matchPlayer: Types.MatchPlayer, gold: number, position: Vector3?)
		local credit = FarmCredit.bounty(gold)
		FarmCredit.apply(matchPlayer, credit)
		if position and BountyJuice.wantsFloat(credit.cs, credit.gold) then
			FxRelay.bounty(position, matchPlayer.userId, credit.gold)
		end
	end

	local function addGold(userId: number, amount: number, position: Vector3?)
		if not current then
			return
		end
		local matchPlayer = current.players[tostring(userId)]
		if matchPlayer then
			creditBounty(matchPlayer, amount, position)
			broadcast()
		end
	end

	local function addDamageDealt(userId: number, amount: number)
		if not current or amount <= 0 then
			return
		end
		local matchPlayer = current.players[tostring(userId)]
		if matchPlayer then
			matchPlayer.damageDealt = (matchPlayer.damageDealt or 0) + amount
		end
	end

	-- Same XP tables as before. The paint cue uses the delta just added and
	-- does not grant extra XP. Level-up juice stays on the client level edge.
	local function grantXp(userId: number, amount: number, position: Vector3?)
		if not current or amount <= 0 then
			return
		end
		local matchPlayer = current.players[tostring(userId)]
		if not matchPlayer then
			return
		end
		matchPlayer.xp += amount
		local after = Progression.levelFromXp(matchPlayer.xp)
		if after > matchPlayer.level then
			matchPlayer.level = after
			matchPlayer.ranks = Progression.autoRanks(after)
			CombatService.applyLevelFor(userId, after)
			feed("level", `{matchPlayer.displayName} grew another life — level {after}`)
		end
		local at = position
		if not at then
			local root = CombatService.rootOf(userId)
			at = if root then root.Position else nil
		end
		if at and XpJuice.wantsFloat(amount) then
			FxRelay.xp(at, userId, amount)
		end
	end

	CombatService.init({
		getSnapshot = MatchService.snapshot,
		addGold = addGold,
		addDamageDealt = addDamageDealt,
		setRespawnAt = function(userId: number, at: number?)
			if not current then
				return
			end
			local matchPlayer = current.players[tostring(userId)]
			if matchPlayer then
				matchPlayer.respawnAt = at
				broadcast()
				-- After the death handler finishes, so a passing vote does not
				-- clear combat mid-takedown.
				local team = matchPlayer.team
				task.defer(function()
					recheckSurrender(team)
					recheckRemake(team)
				end)
			end
		end,
		onPlayerKilled = function(killerUserId: number?, victimUserId: number, assists: { number })
			if not current then
				return
			end
			local v = current.players[tostring(victimUserId)]
			local k = if killerUserId then current.players[tostring(killerUserId)] else nil
			if v then
				v.deaths += 1
			end
			if killerUserId then
				local victimRoot = CombatService.rootOf(victimUserId)
				local bountyAt = if victimRoot then victimRoot.Position else nil
				if k then
					k.kills += 1
					creditBounty(k, Config.Match.KillGold, bountyAt)
					grantXp(killerUserId, Config.Match.KillXp, bountyAt)
					local killer = riftHuman(killerUserId)
					if killer then
						CosmeticService.noteRiftKill(killer)
					end
				end
				local assistNames = {}
				for _, helperId in assists do
					local helperMatch = current.players[tostring(helperId)]
					if helperMatch then
						helperMatch.assists += 1
						creditBounty(helperMatch, Config.Match.AssistGold, bountyAt)
						grantXp(helperId, Config.Match.AssistXp, bountyAt)
						table.insert(assistNames, helperMatch.displayName)
					end
				end
				local extra = if #assistNames > 0 then ` · {table.concat(assistNames, ", ")} lent a paw` else ""
				local killerName = if k then k.displayName else "Someone"
				local victimName = if v then v.displayName else "a cat"
				feed("kill", `{killerName} scratched {victimName} into next week{extra}`)
			else
				local victimName = if v then v.displayName else "A cat"
				feed("kill", `{victimName} got batted by a tower (or a kitten)`)
			end
			-- Champion stocks only. Lane kittens and camps never reach this callback.
			local tapeEvents = {}
			if k and k.championId then
				table.insert(tapeEvents, { id = k.championId, kind = "kill" })
			end
			if v and v.championId then
				table.insert(tapeEvents, { id = v.championId, kind = "death" })
			end
			if #tapeEvents > 0 then
				MemeStockService.reactMany(tapeEvents)
			end
			if v then
				local living, teamSize = rosterLiving(v.team)
				local killerLabel = if k then catLabel(k) else nil
				AnnouncerService.onChampionDown({
					killerUserId = killerUserId,
					killerName = killerLabel,
					victimName = catLabel(v),
					victimTeam = v.team,
					cause = AnnouncerLines.causeFrom(killingKind(victimUserId), killerUserId ~= nil),
					living = living,
					teamSize = teamSize,
				})
			end
			broadcast()
		end,
		onObjectiveDestroyed = function(attackerUserId: number?, objective: Types.ObjectiveState)
			if not current then
				return
			end
			if not current.structureFalls then
				current.structureFalls = {}
			end
			table.insert(current.structureFalls, {
				team = objective.team,
				lane = objective.lane,
				tier = objective.tier,
				kind = objective.kind,
				at = Workspace:GetServerTimeNow(),
			})
			local attacker = if attackerUserId then current.players[tostring(attackerUserId)] else nil
			local who = if attacker then attacker.displayName else "Lane kittens"
			local def = StructureLogic.get(objective.id)
			local line = if def
				then StructureLogic.deathLine(who, def)
				else `{who} knocked over the {objective.team} scratching post`
			if objective.kind == "Tower" then
				local attackerPlayer = if attackerUserId then riftHuman(attackerUserId) else nil
				if attackerPlayer then
					CosmeticService.noteRiftStructure(attackerPlayer)
				end
			end
			local allies = {}
			if not (attacker and attacker.championId) then
				local attacking: Types.TeamId = if objective.team == "Blue" then "Red" else "Blue"
				for _, matchPlayer in current.players do
					if matchPlayer.team == attacking and matchPlayer.championId then
						table.insert(allies, matchPlayer.championId)
					end
				end
			end
			MemeStockService.reactStructure(if attacker then attacker.championId else nil, objective.tier, allies)
			if objective.kind == "Nexus" then
				feed("nexus", line)
			elseif objective.tier == "Inner" then
				feed("stall", line)
			else
				feed("tower", line)
			end
			local coreOpened = objective.kind ~= "Nexus" and MapBuilder.isNexusVulnerable(objective.team)
			AnnouncerService.onStructure({
				kind = objective.kind,
				tier = objective.tier,
				team = objective.team,
				lane = objective.lane,
				who = if attacker then catLabel(attacker) else "Lane kittens",
				coreOpened = coreOpened,
			})
			if objective.kind == "Nexus" then
				local winner: Types.TeamId = if objective.team == "Blue" then "Red" else "Blue"
				MatchService.endMatch(winner, `{objective.team} nexus is a scratch post.`)
			else
				broadcast()
			end
		end,
	})

	MinionService.init({
		getPhase = function()
			return if current then current.phase else nil
		end,
		damagePlayerNear = CombatService.damagePlayersNear,
		damageObjectiveNear = CombatService.damageObjectiveNear,
		-- Lane kitten last hits pay CS and gold only. They do not move meme tickers.
		onLastHit = function(userId: number, gold: number, position: Vector3)
			local credited = creditLastHit(userId, gold, position)
			grantXp(userId, Config.Match.MinionXp, position)
			if credited then
				broadcast()
			end
		end,
		-- Nearby allies get XP only. The last hitter already took CS and gold.
		onMinionDied = function(position: Vector3, minionTeam: Types.TeamId, lastHitterUserId: number?)
			if not current then
				return
			end
			local leveled = false
			for _, matchPlayer in current.players do
				if lastHitterUserId and matchPlayer.userId == lastHitterUserId then
					continue
				end
				local root = CombatService.rootOf(matchPlayer.userId)
				local combat = CombatService.get(matchPlayer.userId)
				if root and combat and combat.alive and matchPlayer.team ~= minionTeam then
					if (root.Position - position).Magnitude <= Config.Match.NearbyXpRadius then
						local before = matchPlayer.level
						grantXp(matchPlayer.userId, Config.Match.NearbyMinionXp, position)
						if matchPlayer.level > before then
							leveled = true
						end
					end
				end
			end
			if leveled then
				broadcast()
			end
		end,
	})

	JungleService.init({
		getPhase = function()
			return if current then current.phase else nil
		end,
		matchElapsed = function()
			if not current or not current.startedAt then
				return 0
			end
			return math.max(0, Workspace:GetServerTimeNow() - current.startedAt)
		end,
		damageUser = CombatService.applyDamageToUser,
		rootOf = CombatService.rootOf,
		-- Camp last hits stay off the meme tape. Canal Levi uses the same CS rule.
		onClear = function(userId: number, gold: number, xp: number, position: Vector3)
			local credited = creditLastHit(userId, gold, position)
			grantXp(userId, xp, position)
			if credited then
				broadcast()
			end
		end,
		onDied = function(position: Vector3, lastHitterUserId: number?)
			if not current then
				return
			end
			for _, matchPlayer in current.players do
				if lastHitterUserId and matchPlayer.userId == lastHitterUserId then
					continue
				end
				local root = CombatService.rootOf(matchPlayer.userId)
				local combat = CombatService.get(matchPlayer.userId)
				if root and combat and combat.alive then
					if (root.Position - position).Magnitude <= Config.Match.NearbyXpRadius then
						grantXp(matchPlayer.userId, Config.Jungle.NearbyXp, position)
					end
				end
			end
		end,
		onEpicPhase = function(phase: string, respawnAt: number?)
			if not current or not current.riverEpic then
				return
			end
			local nextPhase: Types.RiverEpicPhase? = nil
			if phase == "waiting" or phase == "alive" or phase == "returning" or phase == "spent" then
				nextPhase = phase
			end
			if not nextPhase then
				return
			end
			local nextAt = RiverEpic.dueAt(current.startedAt, nextPhase, respawnAt)
			if current.riverEpic.phase == nextPhase and current.riverEpic.nextAt == nextAt then
				return
			end
			current.riverEpic.phase = nextPhase
			current.riverEpic.nextAt = nextAt
			broadcast()
		end,
		onEpicTaken = function(userId: number, phase: string, respawnElapsed: number?)
			if not current or not current.riverEpic then
				return
			end
			local matchPlayer = current.players[tostring(userId)]
			if matchPlayer then
				local blue, red = RiverEpic.grant(current.riverEpic.blueBuff, current.riverEpic.redBuff, matchPlayer.team)
				current.riverEpic.blueBuff = blue
				current.riverEpic.redBuff = red
				AnnouncerService.onEpic(matchPlayer.team, catLabel(matchPlayer))
			end
			-- Same broadcast as the grant. +8% still comes only from RiverEpic.grant.
			local nextPhase: Types.RiverEpicPhase? = nil
			if phase == "waiting" or phase == "alive" or phase == "returning" or phase == "spent" then
				nextPhase = phase
			end
			if nextPhase then
				current.riverEpic.phase = nextPhase
				current.riverEpic.nextAt = RiverEpic.dueAt(current.startedAt, nextPhase, respawnElapsed)
			end
			broadcast()
		end,
	})

	TowerService.init({
		getSnapshot = MatchService.snapshot,
		damageUser = CombatService.applyDamageToUser,
		rootOf = CombatService.rootOf,
	})

	VisionService.init({
		getSnapshot = MatchService.snapshot,
		rootOf = CombatService.rootOf,
	})

	ShopService.init({
		getSnapshot = MatchService.snapshot,
		goldOf = function(userId: number)
			local matchPlayer = if current then current.players[tostring(userId)] else nil
			return if matchPlayer then matchPlayer.gold else 0
		end,
		spendGold = function(userId: number, amount: number)
			if not current then
				return false
			end
			local matchPlayer = current.players[tostring(userId)]
			if not matchPlayer or matchPlayer.gold < amount then
				return false
			end
			matchPlayer.gold -= amount
			broadcast()
			return true
		end,
		onLoadoutChanged = function(userId: number)
			if current then
				local matchPlayer = current.players[tostring(userId)]
				if matchPlayer then
					matchPlayer.items = ShopService.owned(userId)
				end
			end
			CombatService.reapplyItemsFor(userId)
			broadcast()
		end,
	})

	local SNAP_CHAMPION = 16
	local SNAP_STRUCTURE = 18
	local SNAP_WARD = 8
	local SNAP_CAMP = 10

	local function flatNear(a: Vector3, b: Vector3, limit: number): boolean
		local dx = a.X - b.X
		local dz = a.Z - b.Z
		return dx * dx + dz * dz <= limit * limit
	end

	-- Confirm the client's ray hit against the live map, then name it.
	-- A bare world position (ground or minimap) stays a generic line.
	local function resolveTarget(
		player: Player,
		matchPlayer: Types.MatchPlayer,
		kind: string,
		point: Vector3,
		body: any
	): (PingLogic.Decision, string?, Vector3, Types.TeamId?)
		local hit: PingLogic.HitKind = "ground"
		local visible = false
		local tier: string? = nil
		local alive: boolean? = nil
		local name: string? = nil
		local snap: Vector3? = nil
		local markerTeam: Types.TeamId? = nil

		local objectiveId = body.objectiveId
		local targetUserId = body.targetUserId
		local jungleId = body.jungleId
		local wardId = body.wardId
		local hinted = typeof(objectiveId) == "string"
			or typeof(targetUserId) == "number"
			or typeof(jungleId) == "string"
			or typeof(wardId) == "string"
		-- A minimap click has no body. An entity id is a world ray, even if source was spoofed.
		local source = if body.source == "minimap" and not hinted then "minimap" else "world"

		if current and typeof(objectiveId) == "string" then
			local objective = current.objectives[objectiveId]
			local def = StructureLogic.get(objectiveId)
			local part = MapBuilder.getObjectivePart(objectiveId)
			if objective and def and part and flatNear(point, part.Position, SNAP_STRUCTURE) then
				hit = "structure"
				tier = def.tier
				alive = objective.alive
				markerTeam = objective.team
				if objective.alive then
					name = StructureLogic.pingName(def)
					snap = part.Position
					visible = true
				end
			end
		elseif current and typeof(targetUserId) == "number" then
			local other = current.players[tostring(targetUserId)]
			local root = CombatService.rootOf(targetUserId)
			if other and other.respawnAt == nil and root and flatNear(point, root.Position, SNAP_CHAMPION) then
				local enemy = other.team ~= matchPlayer.team
				local seen = (not enemy) or VisionService.canSeeChampion(player.UserId, other.userId)
				hit = if enemy then "enemy" else "ally"
				visible = seen
				if seen then
					local champ = if other.championId then ChampionCatalog.get(other.championId) else nil
					name = if champ then champ.name else other.displayName
					snap = root.Position
				end
			end
		elseif typeof(jungleId) == "string" then
			local monster = JungleService.get(jungleId)
			if monster and monster.health > 0 and monster.part.Parent and flatNear(point, monster.part.Position, SNAP_CAMP) then
				hit = "camp"
				alive = true
				visible = VisionService.canSeeJungle(player.UserId, monster.id)
				if visible then
					name = monster.name
					snap = monster.part.Position
				end
			end
		elseif typeof(wardId) == "string" then
			local ward = WardService.get(wardId)
			local viewer = CombatService.rootOf(player.UserId)
			if ward and ward.part.Parent and flatNear(point, ward.part.Position, SNAP_WARD) then
				hit = "ward"
				alive = true
				visible = WardService.canSee(matchPlayer.team, ward.id, if viewer then viewer.Position else nil)
				if visible then
					name = if ward.kind == "control" then "pink" else "ward"
					snap = ward.part.Position
				end
			end
		end

		local decision = PingLogic.resolve({
			kind = kind,
			source = source,
			hit = hit,
			visible = visible,
			tier = tier,
			alive = alive,
		})
		local named = if decision.named then name else nil
		local at = if decision.named and snap then snap else point
		local teamMark = if decision.named then markerTeam else nil
		return decision, named, at, teamMark
	end

	function MatchService.ping(player: Player, request: unknown): Types.TradeResult
		if not current or current.phase ~= "InProgress" then
			return { ok = false, error = "Ping during a match." }
		end
		local matchPlayer = current.players[tostring(player.UserId)]
		if not matchPlayer then
			return { ok = false, error = "You are not in this match." }
		end

		local now = os.clock()
		local previous = lastPingAt[player.UserId]
		if previous and PingLogic.cooling(now - previous) then
			return { ok = false, error = "Ping cooling down." }
		end

		local kind = "Attention"
		local dest: Vector3? = nil
		local body: any = {}
		if typeof(request) == "Vector3" then
			dest = request :: Vector3
			body = { source = "minimap" }
		elseif typeof(request) == "table" then
			body = request :: any
			if PingCatalog.get(body.kind) then
				kind = body.kind
			end
			if typeof(body.position) == "Vector3" then
				dest = body.position
			end
		else
			return { ok = false, error = "Need a map point." }
		end

		if typeof(dest) ~= "Vector3" then
			return { ok = false, error = "Need a map point." }
		end

		local decision, targetName, resolved, markerTeam = resolveTarget(player, matchPlayer, kind, dest :: Vector3, body)
		if not decision.ok then
			return { ok = false, error = decision.error or "No vision." }
		end

		local bounds = Constants.MapBounds
		local point = Vector3.new(
			math.clamp(resolved.X, bounds.MinX, bounds.MaxX),
			4,
			math.clamp(resolved.Z, bounds.MinZ, bounds.MaxZ)
		)

		local def = PingCatalog.get(kind)
		local emoji = if def then def.emoji else "📍"
		local label = if def then def.label else "Attention"
		local line = if def then def.line else "Attention"
		local text = PingLogic.ticker(matchPlayer.displayName, emoji, label, line, targetName)

		lastPingAt[player.UserId] = now
		local payload: Types.PingPayload = {
			userId = player.UserId,
			team = matchPlayer.team,
			kind = (if def then def.id else "Attention") :: Types.PingKind,
			position = point,
			at = Workspace:GetServerTimeNow(),
			text = text,
			targetName = targetName,
			marker = decision.marker,
			markerTeam = markerTeam,
		}
		for _, other in Players:GetPlayers() do
			local otherMatch = current.players[tostring(other.UserId)]
			if otherMatch and otherMatch.team == matchPlayer.team then
				Remotes.event("PingReceived"):FireClient(other, payload)
			end
		end
		return { ok = true }
	end

	Players.PlayerRemoving:Connect(function(player)
		lastPingAt[player.UserId] = nil
		if not current then
			return
		end
		local matchPlayer = current.players[tostring(player.UserId)]
		if matchPlayer then
			matchPlayer.connected = false
			broadcast()
			recheckSurrender(matchPlayer.team)
			recheckRemake(matchPlayer.team)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				if not current or current.phase ~= "InProgress" then
					teleport(player, nil)
					return
				end
				local matchPlayer = current.players[tostring(player.UserId)]
				if matchPlayer then
					teleport(player, matchPlayer.team)
				end
			end)
		end)
	end)
end

return MatchService
