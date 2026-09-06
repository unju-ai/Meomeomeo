--!strict

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Progression = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Progression"))
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local AiChatService = require(script.Parent.Parent.Npcs.AiChatService)
local CombatService = require(script.Parent.CombatService)
local Config = require(script.Parent.Parent.Config)
local JungleService = require(script.Parent.JungleService)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local MemeStockService = require(script.Parent.Parent.Economy.MemeStockService)
local MinionService = require(script.Parent.MinionService)
local ShopService = require(script.Parent.ShopService)
local TowerService = require(script.Parent.TowerService)
local VisionService = require(script.Parent.VisionService)
local VoiceService = require(script.Parent.Parent.Voice.VoiceService)
local WardService = require(script.Parent.WardService)

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
	phaseToken += 1
	MinionService.stop()
	JungleService.stop()
	TowerService.stop()
	VisionService.stop()
	WardService.stop()
	CombatService.clearAll()
	for _, player in Players:GetPlayers() do
		assignRobloxTeam(player, nil)
		ShopService.clear(player.UserId)
		teleport(player, nil)
	end
	VoiceService.onTeamsChanged()
	current = nil
	if formQueue and onMatchCleared then
		onMatchCleared()
	end
	Remotes.event("MatchStateChanged"):FireAllClients(nil)
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
	JungleService.stop()
	TowerService.stop()
	VisionService.stop()
	WardService.stop()
	current.mvpUserId = pickMvp()
	CombatService.clearAll()
	for _, player in Players:GetPlayers() do
		local matchPlayer = current.players[tostring(player.UserId)]
		if matchPlayer then
			if matchPlayer.team == winner then
				AiChatService.announceTo(player, "Victory! Enemy nexus destroyed!")
			else
				AiChatService.announceTo(player, "Defeat! Your nexus has fallen!")
			end
		end
	end
	feed("announce", `{winner} destroyed the enemy nexus!`)
	AiChatService.announce(`{winner} wins! {reason}`)
	broadcast()

	local token = phaseToken
	task.delay(Config.Match.PostMatchSeconds, function()
		if token ~= phaseToken then
			return
		end
		MatchService.returnToLobby(true)
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
			xp = 0,
			level = 1,
			ranks = Progression.autoRanks(1),
			respawnAt = nil,
			cs = 0,
			connected = true,
			items = {},
			damageDealt = 0,
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
		mvpUserId = nil,
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

	local function addDamageDealt(player: Player, amount: number)
		if not current or amount <= 0 then
			return
		end
		local matchPlayer = current.players[tostring(player.UserId)]
		if matchPlayer then
			matchPlayer.damageDealt = (matchPlayer.damageDealt or 0) + amount
		end
	end

	local function grantXp(player: Player, amount: number)
		if not current or amount <= 0 then
			return
		end
		local matchPlayer = current.players[tostring(player.UserId)]
		if not matchPlayer then
			return
		end
		matchPlayer.xp += amount
		local after = Progression.levelFromXp(matchPlayer.xp)
		if after > matchPlayer.level then
			matchPlayer.level = after
			matchPlayer.ranks = Progression.autoRanks(after)
			CombatService.applyLevel(player, after)
			feed("level", `{player.DisplayName} grew another life — level {after}`)
			AiChatService.announce(`{player.DisplayName} hit level {after}. Sharper claws.`)
		end
	end

	CombatService.init({
		getSnapshot = MatchService.snapshot,
		addGold = addGold,
		addDamageDealt = addDamageDealt,
		setRespawnAt = function(player: Player, at: number?)
			if not current then
				return
			end
			local matchPlayer = current.players[tostring(player.UserId)]
			if matchPlayer then
				matchPlayer.respawnAt = at
				broadcast()
			end
		end,
		onPlayerKilled = function(killer: Player?, victim: Player, assists: { Player })
			if not current then
				return
			end
			local v = current.players[tostring(victim.UserId)]
			if v then
				v.deaths += 1
			end
			if killer then
				local k = current.players[tostring(killer.UserId)]
				if k then
					k.kills += 1
					k.gold += Config.Match.KillGold
					grantXp(killer, Config.Match.KillXp)
					if k.championId then
						MemeStockService.bumpChampion(k.championId, 0.12)
					end
				end
				local assistNames = {}
				for _, helper in assists do
					local helperMatch = current.players[tostring(helper.UserId)]
					if helperMatch then
						helperMatch.assists += 1
						helperMatch.gold += Config.Match.AssistGold
						grantXp(helper, Config.Match.AssistXp)
						table.insert(assistNames, helper.DisplayName)
					end
				end
				local extra = if #assistNames > 0 then ` · {table.concat(assistNames, ", ")} lent a paw` else ""
				feed("kill", `{killer.DisplayName} scratched {victim.DisplayName} into next week{extra}`)
				AiChatService.announce(`{killer.DisplayName} deleted {victim.DisplayName}.{extra}. Brutal.`)
			else
				feed("kill", `{victim.DisplayName} got batted by a tower (or a kitten)`)
				AiChatService.announce(`{victim.DisplayName} face-planted. Fountain time.`)
			end
			broadcast()
		end,
		onObjectiveDestroyed = function(attacker: Player?, objective: Types.ObjectiveState)
			if not current then
				return
			end
			local who = if attacker then attacker.DisplayName else "Lane kittens"
			if objective.kind == "Nexus" then
				feed("nexus", `{who} unplugged the {objective.team} yarn core`)
			else
				feed("tower", `{who} knocked over the {objective.team} scratching post`)
			end
			AiChatService.announce(`{who} melted the {objective.team} {objective.kind}!`)
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
			if current then
				local matchPlayer = current.players[tostring(player.UserId)]
				if matchPlayer then
					matchPlayer.cs += 1
				end
			end
			grantXp(player, Config.Match.MinionXp)
			addGold(player, gold)
		end,
		onMinionDied = function(position: Vector3, minionTeam: Types.TeamId, lastHitter: Player?)
			if not current then
				return
			end
			local leveled = false
			for _, player in Players:GetPlayers() do
				if lastHitter and player == lastHitter then
					continue
				end
				local matchPlayer = current.players[tostring(player.UserId)]
				local root = CombatService.characterRoot(player)
				local combat = CombatService.get(player.UserId)
				if matchPlayer and root and combat and combat.alive and matchPlayer.team ~= minionTeam then
					if (root.Position - position).Magnitude <= Config.Match.NearbyXpRadius then
						local before = matchPlayer.level
						grantXp(player, Config.Match.NearbyMinionXp)
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
		damagePlayer = CombatService.applyDamageToPlayer,
		characterRoot = CombatService.characterRoot,
		onClear = function(player: Player, gold: number, xp: number)
			if current then
				local matchPlayer = current.players[tostring(player.UserId)]
				if matchPlayer then
					matchPlayer.cs += 1
				end
			end
			grantXp(player, xp)
			addGold(player, gold)
		end,
		onDied = function(position: Vector3, lastHitter: Player?)
			if not current then
				return
			end
			for _, player in Players:GetPlayers() do
				if lastHitter and player == lastHitter then
					continue
				end
				local matchPlayer = current.players[tostring(player.UserId)]
				local root = CombatService.characterRoot(player)
				local combat = CombatService.get(player.UserId)
				if matchPlayer and root and combat and combat.alive then
					if (root.Position - position).Magnitude <= Config.Match.NearbyXpRadius then
						grantXp(player, Config.Jungle.NearbyXp)
					end
				end
			end
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

	function MatchService.ping(player: Player, position: unknown): Types.TradeResult
		if not current or current.phase ~= "InProgress" then
			return { ok = false, error = "Ping during a match." }
		end
		local matchPlayer = current.players[tostring(player.UserId)]
		if not matchPlayer then
			return { ok = false, error = "You are not in this match." }
		end
		if typeof(position) ~= "Vector3" then
			return { ok = false, error = "Need a map point." }
		end
		local dest = position :: Vector3
		local bounds = Constants.MapBounds
		dest = Vector3.new(
			math.clamp(dest.X, bounds.MinX, bounds.MaxX),
			4,
			math.clamp(dest.Z, bounds.MinZ, bounds.MaxZ)
		)
		local payload: Types.PingPayload = {
			userId = player.UserId,
			team = matchPlayer.team,
			position = dest,
			at = Workspace:GetServerTimeNow(),
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
