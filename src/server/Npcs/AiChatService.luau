--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Config = require(script.Parent.Parent.Config)
local HttpAiProvider = require(script.Parent.HttpAiProvider)
local MockAiProvider = require(script.Parent.MockAiProvider)
local NpcCatalog = require(script.Parent.NpcCatalog)
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

type SnapshotFn = () -> Types.MatchSnapshot?

local AiChatService = {}

local lastChatAt: { [number]: number } = {}
local getSnapshot: SnapshotFn = function()
	return nil
end

local function providerComplete(message: string, context: MockAiProvider.ChatContext): string
	if Config.Ai.Provider == "http" then
		return HttpAiProvider.complete(message, context)
	end
	return MockAiProvider.complete(message, context)
end

local function scoreline(snapshot: Types.MatchSnapshot?): string
	if not snapshot then
		return "lobby hush"
	end
	local blue, red = 0, 0
	for _, player in snapshot.players do
		if player.team == "Blue" then
			blue += player.kills
		else
			red += player.kills
		end
	end
	return `Blue {blue} – {red} Red`
end

function AiChatService.init(snapshotFn: SnapshotFn)
	getSnapshot = snapshotFn
end

function AiChatService.chat(player: Player, npcId: unknown, message: unknown): Types.ChatResult
	if typeof(npcId) ~= "string" or typeof(message) ~= "string" then
		return { ok = false, error = "Invalid chat payload." }
	end

	local npc = NpcCatalog.get(npcId)
	if not npc then
		return { ok = false, error = "Unknown cat NPC." }
	end

	local trimmed = string.gsub(message, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	if trimmed == "" then
		return { ok = false, error = "Say something, kitten." }
	end
	if string.len(trimmed) > Config.Ai.MaxMessageLength then
		trimmed = string.sub(trimmed, 1, Config.Ai.MaxMessageLength)
	end

	local now = os.clock()
	local last = lastChatAt[player.UserId]
	if last and now - last < Config.Ai.RateLimitSeconds then
		return { ok = false, error = "The cats are thinking. Try again in a second." }
	end
	lastChatAt[player.UserId] = now

	local snapshot = getSnapshot()
	local matchPlayer = if snapshot then snapshot.players[tostring(player.UserId)] else nil
	local ChampionCatalog = require(Shared:WaitForChild("ChampionCatalog"))
	local champ = if matchPlayer and matchPlayer.championId then ChampionCatalog.get(matchPlayer.championId) else nil

	local reply = providerComplete(trimmed, {
		npc = npc,
		playerName = player.DisplayName,
		championName = if champ then champ.name else nil,
		phase = if snapshot then snapshot.phase else "Lobby",
		scoreline = scoreline(snapshot),
	})

	return {
		ok = true,
		reply = reply,
		speaker = npc.name,
	}
end

function AiChatService.announce(text: string)
	Remotes.event("AnnouncerMessage"):FireAllClients({
		speaker = "Kitty Caster",
		text = text,
	})
end

function AiChatService.list(): { Types.NpcDef }
	return NpcCatalog.all()
end

return AiChatService
