--!strict

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local AiChatService = require(script.Parent.Parent.Npcs.AiChatService)
local CombatService = require(script.Parent.CombatService)
local Config = require(script.Parent.Parent.Config)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local MemeStockService = require(script.Parent.Parent.Economy.MemeStockService)
local MinionService = require(script.Parent.MinionService)
local ShopService = require(script.Parent.ShopService)
local TowerService = require(script.Parent.TowerService)
local VisionService = require(script.Parent.VisionService)
local VoiceService = require(script.Parent.Parent.Voice.VoiceService)

local MatchService = {}

local current: Types.MatchSnapshot? = nil
local phaseToken = 0
local onMatchCleared: (() -> ())? = nil

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
	return current ~= nil and current.phase ~= "Ended"
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
end

local function beginFight()
	if not current then
		return
	end
	current.phase = "InProgress"
	current.startedAt = Workspace:GetServerTimeNow()
	current.phaseEndsAt = nil
	MapBuilder.build()
	current.objectives = MapBuilder.objectiveStates()

	for _, player in Players:GetPlayers() do
		local matchPlayer = current.players[tostring(player.UserId)]
		if matchPlayer and matchPlayer.championId then
			assignRobloxTeam(player, matchPlayer.team)
			CombatService.reset(player, matchPlayer.championId)
			teleport(player, matchPlayer.team)
		end
	end

	VoiceService.onTeamsChanged()
	ShopService.clearAll()
	MapBuilder.refreshNexusGate()
	MinionService.start()
	TowerService.start()
	VisionService.start()
	AiChatService.announce("Cats out of the bag — match is LIVE. Smash three towers, then the nexus. Meow.")
	broadcast()
end

function MatchService.endMatch(winner: Types.TeamId, reason: string)
	if not current or current.phase == "Ended" then
		return
	end
	current.phase = "Ended"
	current.winner = winner
	current.endedAt = Workspace:GetServerTimeNow()
	current.phaseEndsAt = Workspace:GetServerTimeNow() + Config.Match.PostMatchSeconds
	MinionService.stop()
	TowerService.stop()
	VisionService.stop()
	AiChatService.announce(`{winner} Whiskers win! {reason}`)
	broadcast()

	local token = phaseToken
	task.delay(Config.Match.PostMatchSeconds, function()
		if token ~= phaseToken then
			return
		end
		current = nil
		for _, player in Players:GetPlayers() do
			assignRobloxTeam(player, nil)
			CombatService.clear(player.UserId)
			ShopService.clear(player.UserId)
			teleport(player, nil)
		end
		VoiceService.onTeamsChanged()
		if onMatchCleared then
			onMatchCleared()
		end
		Remotes.event("MatchStateChanged"):FireAllClients(nil)
	end)
end

function MatchService.start(participants: { Player }, practice: boolean)
	if MatchService.isBusy() then
		return false, "A match is already running."
	end
	if #participants == 0 then
		return false, "Need at least one cat."
	end

	phaseToken += 1
	local token = phaseToken
	MapBuilder.build()

	local players: { [string]: Types.MatchPlayer } = {}
	for index, player in participants do
		local team: Types.TeamId = if index % 2 == 1 then "Blue" else "Red"
		if practice then
			team = "Blue"
		end
		players[tostring(player.UserId)] = {
			userId = player.UserId,
			displayName = player.DisplayName,
			team = team,
			championId = nil,
			ready = false,
			kills = 0,
			deaths = 0,
			assists = 0,
			gold = Config.Match.StartingGold,
			connected = true,
			items = {},
		}
		assignRobloxTeam(player, team)
		teleport(player, nil)
	end

	current = {
		id = `meo-{token}`,
		phase = "ChampionSelect",
		practice = practice,
		phaseEndsAt = Workspace:GetServerTimeNow() + Config.Match.ChampionSelectSeconds,
		startedAt = nil,
		endedAt = nil,
		winner = nil,
		players = players,
		objectives = MapBuilder.objectiveStates(),
		queueCount = 0,
	}

	VoiceService.onTeamsChanged()
	AiChatService.announce(if practice then "Practice draft is open. Pick your cat." else "Champion select — lock a cat.")
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

	local allReady = true
	for _, other in current.players do
		if not other.championId then
			allReady = false
			break
		end
	end
	if allReady then
		phaseToken += 1
		autoAssignChampions()
		beginFight()
	end
	return { ok = true }
end

function MatchService.setQueueCount(count: number)
	if current then
		current.queueCount = count
	end
end

function MatchService.init(cleared: () -> ())
	onMatchCleared = cleared

	local function addGold(player: Player, amount: number)
		if not current then
			return
		end
		local matchPlayer = current.players[tostring(player.UserId)]
		if matchPlayer then
			matchPlayer.gold += amount
			broadcast()
		end
	end

	CombatService.init({
		getSnapshot = MatchService.snapshot,
		addGold = addGold,
		onPlayerKilled = function(killer: Player, victim: Player)
			if not current then
				return
			end
			local k = current.players[tostring(killer.UserId)]
			local v = current.players[tostring(victim.UserId)]
			if k then
				k.kills += 1
				k.gold += Config.Match.KillGold
				if k.championId then
					MemeStockService.bumpChampion(k.championId, 0.12)
				end
			end
			if v then
				v.deaths += 1
			end
			AiChatService.announce(`{killer.DisplayName} deleted {victim.DisplayName}. Brutal.`)
			broadcast()
		end,
		onObjectiveDestroyed = function(attacker: Player, objective: Types.ObjectiveState)
			if not current then
				return
			end
			AiChatService.announce(`{attacker.DisplayName} melted the {objective.team} {objective.kind}!`)
			if objective.kind == "Nexus" then
				local winner: Types.TeamId = if objective.team == "Blue" then "Red" else "Blue"
				MatchService.endMatch(winner, `{objective.team} nexus is a scratch post.`)
			else
				if MapBuilder.isNexusVulnerable(objective.team) then
					AiChatService.announce(`{objective.team} nexus is exposed! All towers are down.`)
				end
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
		onLastHit = function(player: Player, gold: number)
			addGold(player, gold)
		end,
	})

	TowerService.init({
		getSnapshot = MatchService.snapshot,
		damagePlayer = CombatService.applyDamageToPlayer,
		characterRoot = CombatService.characterRoot,
	})

	VisionService.init({
		getSnapshot = MatchService.snapshot,
		characterRoot = CombatService.characterRoot,
	})

	ShopService.init({
		getSnapshot = MatchService.snapshot,
		goldOf = function(player: Player)
			local matchPlayer = if current then current.players[tostring(player.UserId)] else nil
			return if matchPlayer then matchPlayer.gold else 0
		end,
		spendGold = function(player: Player, amount: number)
			if not current then
				return false
			end
			local matchPlayer = current.players[tostring(player.UserId)]
			if not matchPlayer or matchPlayer.gold < amount then
				return false
			end
			matchPlayer.gold -= amount
			broadcast()
			return true
		end,
		onLoadoutChanged = function(player: Player)
			if current then
				local matchPlayer = current.players[tostring(player.UserId)]
				if matchPlayer then
					matchPlayer.items = ShopService.owned(player.UserId)
				end
			end
			CombatService.reapplyItems(player)
			broadcast()
		end,
	})

	Players.PlayerRemoving:Connect(function(player)
		if not current then
			return
		end
		local matchPlayer = current.players[tostring(player.UserId)]
		if matchPlayer then
			matchPlayer.connected = false
			broadcast()
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
