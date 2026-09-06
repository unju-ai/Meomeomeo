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
local BotService = require(script.Parent.BotService)
local CombatService = require(script.Parent.CombatService)
local MatchTeleport = require(script.Parent.MatchTeleport)
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
local nextBotId = -1001

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

local function addBot(players: { [string]: Types.MatchPlayer }, team: Types.TeamId)
	local championId = pickBotChampion(players, team)
	local champ = ChampionCatalog.get(championId)
	local userId = nextBotId
	nextBotId -= 1
	players[tostring(userId)] = blankPlayer(userId, `{(if champ then champ.name else championId)} (Bot)`, team, true, championId)
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
		for _ = 1, Config.Bots.PracticeAllies do
			addBot(players, "Blue")
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
	local humans = Players:GetPlayers()
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
	for _, player in Players:GetPlayers() do
		assignRobloxTeam(player, nil)
		teleport(player, nil)
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
	BotService.start()
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
	BotService.stop()
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
		queueCount = 0,
		lobbyPlaceId = if options then options.lobbyPlaceId else nil,
		reserved = if options then options.reserved else false,
	}

	VoiceService.onTeamsChanged()
	AiChatService.announce(
		if practice
			then `Practice draft is open. Red is 3 bots ({current.botDifficulty or "Normal"}). Pick your cat.`
			else "Champion select — lock a cat."
	)
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

	local function addGold(userId: number, amount: number)
		if not current then
			return
		end
		local matchPlayer = current.players[tostring(userId)]
		if matchPlayer then
			matchPlayer.gold += amount
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

	local function grantXp(userId: number, amount: number)
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
			AiChatService.announce(`{matchPlayer.displayName} hit level {after}. Sharper claws.`)
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
			end
		end,
		onPlayerKilled = function(killerUserId: number?, victimUserId: number, assists: { number })
			if not current then
				return
			end
			local v = current.players[tostring(victimUserId)]
			if v then
				v.deaths += 1
			end
			if killerUserId then
				local k = current.players[tostring(killerUserId)]
				if k then
					k.kills += 1
					k.gold += Config.Match.KillGold
					grantXp(killerUserId, Config.Match.KillXp)
					if k.championId then
						MemeStockService.bumpChampion(k.championId, 0.12)
					end
				end
				local assistNames = {}
				for _, helperId in assists do
					local helperMatch = current.players[tostring(helperId)]
					if helperMatch then
						helperMatch.assists += 1
						helperMatch.gold += Config.Match.AssistGold
						grantXp(helperId, Config.Match.AssistXp)
						table.insert(assistNames, helperMatch.displayName)
					end
				end
				local extra = if #assistNames > 0 then ` · {table.concat(assistNames, ", ")} lent a paw` else ""
				local killerName = if k then k.displayName else "Someone"
				local victimName = if v then v.displayName else "a cat"
				feed("kill", `{killerName} scratched {victimName} into next week{extra}`)
				AiChatService.announce(`{killerName} deleted {victimName}.{extra}. Brutal.`)
			else
				local victimName = if v then v.displayName else "A cat"
				feed("kill", `{victimName} got batted by a tower (or a kitten)`)
				AiChatService.announce(`{victimName} face-planted. Fountain time.`)
			end
			broadcast()
		end,
		onObjectiveDestroyed = function(attackerUserId: number?, objective: Types.ObjectiveState)
			if not current then
				return
			end
			local attacker = if attackerUserId then current.players[tostring(attackerUserId)] else nil
			local who = if attacker then attacker.displayName else "Lane kittens"
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
		onLastHit = function(userId: number, gold: number)
			if current then
				local matchPlayer = current.players[tostring(userId)]
				if matchPlayer then
					matchPlayer.cs += 1
				end
			end
			grantXp(userId, Config.Match.MinionXp)
			addGold(userId, gold)
		end,
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
						grantXp(matchPlayer.userId, Config.Match.NearbyMinionXp)
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
		damageUser = CombatService.applyDamageToUser,
		rootOf = CombatService.rootOf,
		onClear = function(userId: number, gold: number, xp: number)
			if current then
				local matchPlayer = current.players[tostring(userId)]
				if matchPlayer then
					matchPlayer.cs += 1
				end
			end
			grantXp(userId, xp)
			addGold(userId, gold)
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
						grantXp(matchPlayer.userId, Config.Jungle.NearbyXp)
					end
				end
			end
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
