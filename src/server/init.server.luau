--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Config = require(script.Config)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local AiChatService = require(script.Npcs.AiChatService)
local CombatService = require(script.Match.CombatService)
local MapBuilder = require(script.World.MapBuilder)
local MatchService = require(script.Match.MatchService)
local MatchmakingService = require(script.Match.MatchmakingService)
local MemeStockService = require(script.Economy.MemeStockService)
local MintService = require(script.Mint.MintService)
local EmoteService = require(script.Social.EmoteService)
local ShopService = require(script.Match.ShopService)
local TutorialStore = require(script.Tutorial.TutorialStore)
local VoiceService = require(script.Voice.VoiceService)

local function ensureTeam(name: string, color: BrickColor)
	local existing = Teams:FindFirstChild(name)
	if existing and existing:IsA("Team") then
		existing.AutoAssignable = false
		return
	end
	local team = Instance.new("Team")
	team.Name = name
	team.AutoAssignable = false
	team.TeamColor = color
	team.Parent = Teams
end

ensureTeam("BlueWhiskers", BrickColor.new("Bright blue"))
ensureTeam("RedPaws", BrickColor.new("Bright red"))
Players.CharacterAutoLoads = true
Players.RespawnTime = Config.Combat.RespawnSeconds

Remotes.initServer()
MapBuilder.build()
MemeStockService.init()
MintService.init()
MatchmakingService.init()
AiChatService.init(MatchService.snapshot)
VoiceService.init()
EmoteService.init()

local function withQueue(snapshot: Types.MatchSnapshot?, player: Player?): Types.MatchSnapshot?
	local queue = MatchmakingService.statusFor(player)
	if snapshot then
		snapshot.queueCount = queue.count
		snapshot.queue = queue
		return snapshot
	end
	return {
		id = "lobby",
		phase = "Lobby",
		practice = false,
		phaseEndsAt = nil,
		startedAt = nil,
		endedAt = nil,
		winner = nil,
		mvpUserId = nil,
		botDifficulty = nil,
		players = {},
		objectives = MapBuilder.objectiveStates(),
		queueCount = queue.count,
		queue = queue,
	}
end

Remotes.function_("QueueMatch").OnServerInvoke = function(player: Player)
	local result = MatchmakingService.queue(player)
	Remotes.event("MatchStateChanged"):FireClient(player, withQueue(MatchService.snapshot(), player))
	return result
end

Remotes.function_("LeaveQueue").OnServerInvoke = function(player: Player)
	return MatchmakingService.leave(player)
end

Remotes.function_("GetQueueStatus").OnServerInvoke = function(player: Player)
	return MatchmakingService.statusFor(player)
end

Remotes.function_("InviteParty").OnServerInvoke = function(player: Player, targetUserId: unknown)
	return MatchmakingService.invite(player, targetUserId)
end

Remotes.function_("StartPractice").OnServerInvoke = function(player: Player, difficulty: unknown)
	return MatchmakingService.practice(player, difficulty)
end

Remotes.function_("SelectChampion").OnServerInvoke = function(player: Player, championId: unknown)
	return MatchService.selectChampion(player, championId)
end

Remotes.function_("GetMatchSnapshot").OnServerInvoke = function(player: Player)
	return withQueue(MatchService.snapshot(), player)
end

Remotes.function_("UseAbility").OnServerInvoke = function(player: Player, request: unknown)
	return CombatService.useAbility(player, request)
end

Remotes.function_("GetVoiceStatus").OnServerInvoke = function(player: Player)
	return VoiceService.getStatus(player)
end

Remotes.function_("ChatWithNpc").OnServerInvoke = function(player: Player, npcId: unknown, message: unknown)
	return AiChatService.chat(player, npcId, message)
end

Remotes.function_("GetNpcs").OnServerInvoke = function(_player: Player)
	return AiChatService.list()
end

Remotes.function_("GetMemeMarket").OnServerInvoke = function(player: Player)
	return MemeStockService.get(player)
end

Remotes.function_("CheerTicker").OnServerInvoke = function(player: Player, championId: unknown)
	return MemeStockService.cheer(player, championId)
end

Remotes.function_("GetMintStatus").OnServerInvoke = function(player: Player)
	return MintService.getStatus(player)
end

Remotes.function_("LinkWallet").OnServerInvoke = function(player: Player, address: unknown)
	return MintService.linkWallet(player, address)
end

Remotes.function_("RequestSiweChallenge").OnServerInvoke = function(player: Player)
	return MintService.requestSiweChallenge(player)
end

Remotes.function_("VerifySiwe").OnServerInvoke = function(player: Player, signature: unknown)
	return MintService.verifySiwe(player, signature)
end

Remotes.function_("SimulateStudioPurchase").OnServerInvoke = function(player: Player)
	return MintService.simulateStudioPurchase(player)
end

Remotes.function_("GrantProduct").OnServerInvoke = function(player: Player, purchaseId: unknown)
	return MintService.grantProduct(player, purchaseId)
end

Remotes.function_("ReplayReceipt").OnServerInvoke = function(player: Player, purchaseId: unknown)
	return MintService.replayReceipt(player, purchaseId)
end

Remotes.function_("ClaimMeo404").OnServerInvoke = function(player: Player, purchaseId: unknown)
	return MintService.claim(player, purchaseId)
end

Remotes.function_("GetShopStatus").OnServerInvoke = function(player: Player)
	return ShopService.status(player)
end

Remotes.function_("BuyItem").OnServerInvoke = function(player: Player, itemId: unknown)
	return ShopService.buy(player, itemId)
end

Remotes.function_("IssueAttack").OnServerInvoke = function(player: Player, request: unknown)
	return CombatService.issueAttack(player, request)
end

Remotes.function_("AttackMove").OnServerInvoke = function(player: Player, position: unknown)
	return CombatService.attackMove(player, position)
end

Remotes.function_("MinimapPing").OnServerInvoke = function(player: Player, position: unknown)
	return MatchService.ping(player, position)
end

Remotes.function_("StartRecall").OnServerInvoke = function(player: Player)
	return CombatService.startRecall(player)
end

Remotes.function_("LeaveMatch").OnServerInvoke = function(player: Player)
	return MatchmakingService.leaveMatch(player)
end

Remotes.function_("PlayAgain").OnServerInvoke = function(player: Player)
	return MatchmakingService.playAgain(player)
end

Remotes.function_("PlaceWard").OnServerInvoke = function(player: Player, position: unknown)
	return CombatService.placeWard(player, position)
end

Remotes.function_("UseLens").OnServerInvoke = function(player: Player)
	return CombatService.useLens(player)
end

Remotes.function_("GetTutorialStatus").OnServerInvoke = function(player: Player)
	local done = TutorialStore.isDone(player.UserId)
	player:SetAttribute(Constants.Attributes.TutorialDone, done)
	return {
		done = done,
		persistMode = TutorialStore.persistMode(),
	}
end

Remotes.function_("PlayEmote").OnServerInvoke = function(player: Player, emoteId: unknown)
	return EmoteService.play(player, emoteId)
end

Remotes.function_("SetTutorialDone").OnServerInvoke = function(player: Player)
	TutorialStore.markDone(player.UserId)
	player:SetAttribute(Constants.Attributes.TutorialDone, true)
	return {
		done = true,
		persistMode = TutorialStore.persistMode(),
	}
end

local function sendLobby(player: Player)
	task.defer(function()
		local done = TutorialStore.isDone(player.UserId)
		player:SetAttribute(Constants.Attributes.TutorialDone, done)
		Remotes.event("MatchStateChanged"):FireClient(player, withQueue(MatchService.snapshot(), player))
		Remotes.event("VoiceStatusChanged"):FireClient(player, VoiceService.getStatus(player))
		Remotes.event("MintStatusChanged"):FireClient(player, MintService.getStatus(player))
	end)
end

Players.PlayerAdded:Connect(sendLobby)
for _, player in Players:GetPlayers() do
	sendLobby(player)
end

print(
	`[Meo Meo Meo] Cat MOBA scaffold online. Queue mode={if Config.Match.MatchPlaceId > 0 then "reserved" else "in-place"} min={Config.Match.MinPlayersToStart}.`
)
