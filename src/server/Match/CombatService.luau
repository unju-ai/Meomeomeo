--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Progression = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Progression"))
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Targeting = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Targeting"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)
local ChampionAppearance = require(script.Parent.Parent.World.ChampionAppearance)
local FxRelay = require(script.Parent.Parent.World.FxRelay)
local JungleService = require(script.Parent.JungleService)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local MinionService = require(script.Parent.MinionService)
local ShopService = require(script.Parent.ShopService)
local TowerService = require(script.Parent.TowerService)
local VisionService = require(script.Parent.VisionService)
local WardService = require(script.Parent.WardService)

type MatchApi = {
	getSnapshot: () -> Types.MatchSnapshot?,
	onPlayerKilled: (killerUserId: number?, victimUserId: number, assists: { number }) -> (),
	onObjectiveDestroyed: (attackerUserId: number?, objective: Types.ObjectiveState) -> (),
	addGold: (userId: number, amount: number) -> (),
	addDamageDealt: (userId: number, amount: number) -> (),
	setRespawnAt: (userId: number, at: number?) -> (),
}

type AttackLock = {
	kind: "player" | "minion" | "objective" | "jungle" | "ward",
	userId: number?,
	minionId: string?,
	objectiveId: string?,
	jungleId: string?,
	wardId: string?,
	moveTo: Vector3?,
	windupEnds: number?,
}

local CombatService = {}

local combat: { [number]: Types.CombatState } = {}
local locks: { [number]: AttackLock } = {}
local nextAA: { [number]: number } = {}
local recentHits: { [number]: { [number]: number } } = {}
local deathToken: { [number]: number } = {}
local recallToken: { [number]: number } = {}
local recallOrigin: { [number]: Vector3 } = {}
local matchApi: MatchApi? = nil
local boundModels: { [number]: Model } = {}
local tickAutoAttack: (userId: number) -> ()
local interruptRecall: (player: Player) -> ()

export type AbilityCast = {
	userId: number,
	team: Types.TeamId,
	mode: Types.AbilityTargeting,
	kind: Types.AbilityKind,
	origin: Vector3,
	dest: Vector3,
	radius: number,
}

local abilityCastListener: ((AbilityCast) -> ())? = nil

function CombatService.onAbilityCast(fn: (AbilityCast) -> ())
	abilityCastListener = fn
end

local function playerOf(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

local function modelOf(userId: number): Model?
	local bound = boundModels[userId]
	if bound and bound.Parent then
		return bound
	end
	local player = playerOf(userId)
	return if player then player.Character else nil
end

local function rootOf(userId: number): BasePart?
	local model = modelOf(userId)
	if not model then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function fireCombat(userId: number)
	local state = combat[userId]
	local player = playerOf(userId)
	if state and player then
		Remotes.event("CombatUpdated"):FireClient(player, state)
	end
end

local function currentLevel(userId: number): number
	if matchApi then
		local snapshot = matchApi.getSnapshot()
		local matchPlayer = if snapshot then snapshot.players[tostring(userId)] else nil
		if matchPlayer then
			return matchPlayer.level
		end
	end
	return 1
end

local function fillVitals(state: Types.CombatState, userId: number, champ: Types.ChampionDef, level: number, full: boolean)
	local shop = ShopService.bonuses(userId)
	local growth = Progression.statGrowth(level)
	local healthRatio = if state.maxHealth > 0 then state.health / state.maxHealth else 1
	local manaRatio = if state.maxMana > 0 then state.mana / state.maxMana else 1
	state.maxHealth = champ.maxHealth + shop.maxHealth + growth.maxHealth
	state.maxMana = champ.maxMana + shop.maxMana + growth.maxMana
	if full then
		state.health = state.maxHealth
		state.mana = state.maxMana
	else
		state.health = math.clamp(state.maxHealth * healthRatio, 1, state.maxHealth)
		state.mana = math.clamp(state.maxMana * manaRatio, 0, state.maxMana)
	end
	state.bonusDamage = shop.bonusDamage + growth.bonusDamage
	state.abilityPower = growth.abilityPower
	state.armor = shop.armor
	state.level = level
	state.ranks = Progression.autoRanks(level)
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function emptyCooldowns(): { [Types.AbilitySlot]: number }
	return { Q = 0, W = 0, E = 0, R = 0 }
end

local function applyHumanoid(userId: number, state: Types.CombatState)
	local character = modelOf(userId)
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = state.maxHealth
		-- Soft-death keeps the Roblox character alive so we own the timer.
		humanoid.Health = if state.alive then math.max(1, state.health) else 1
		if not state.alive then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
		end
	end
end

local function setRecallingFlag(player: Player, on: boolean)
	if on then
		player:SetAttribute(Constants.Attributes.Recalling, true)
	else
		player:SetAttribute(Constants.Attributes.Recalling, nil)
	end
end

interruptRecall = function(player: Player)
	local state = combat[player.UserId]
	if not state or not state.recalling then
		return
	end
	state.recalling = false
	state.recallEndsAt = nil
	state.recallStartedAt = nil
	recallOrigin[player.UserId] = nil
	recallToken[player.UserId] = (recallToken[player.UserId] or 0) + 1
	setRecallingFlag(player, false)
	if state.alive then
		ShopService.applyMovement(player)
	end
	Remotes.event("CombatUpdated"):FireClient(player, state)
	FxRelay.emit({
		kind = "recall",
		origin = Vector3.zero,
		userId = player.UserId,
		duration = 0,
	})
end

local function completeRecall(player: Player)
	local state = combat[player.UserId]
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not state or not state.recalling or not snapshot or snapshot.phase ~= "InProgress" then
		return
	end
	if not state.alive then
		return
	end
	local matchPlayer = snapshot.players[tostring(player.UserId)]
	if not matchPlayer then
		return
	end
	state.recalling = false
	state.recallEndsAt = nil
	state.recallStartedAt = nil
	recallOrigin[player.UserId] = nil
	setRecallingFlag(player, false)
	local spawn = MapBuilder.getSpawn(matchPlayer.team)
	player.RespawnLocation = spawn
	local character = player.Character
	if character then
		pcall(function()
			character:PivotTo(spawn.CFrame + Vector3.new(0, 5, 0))
		end)
	end
	applyHumanoid(player.UserId, state)
	ShopService.applyMovement(player)
	fireCombat(player.UserId)
	FxRelay.emit({
		kind = "recall",
		origin = spawn.Position,
		userId = player.UserId,
		duration = 0,
	})
end

function CombatService.startRecall(player: Player): Types.AbilityResult
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot or snapshot.phase ~= "InProgress" then
		return { ok = false, error = "Match is not in progress." }
	end
	local matchPlayer = snapshot.players[tostring(player.UserId)]
	local state = combat[player.UserId]
	if not matchPlayer or not state or not state.alive then
		return { ok = false, error = "You are down. Wait for respawn." }
	end
	if state.recalling then
		interruptRecall(player)
		return { ok = true, combat = state }
	end
	local root = rootOf(player.UserId)
	if not root then
		return { ok = false, error = "No character." }
	end
	locks[player.UserId] = nil
	state.recalling = true
	state.recallStartedAt = now()
	state.recallEndsAt = state.recallStartedAt + Config.Combat.RecallSeconds
	recallOrigin[player.UserId] = root.Position
	setRecallingFlag(player, true)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
	local token = (recallToken[player.UserId] or 0) + 1
	recallToken[player.UserId] = token
	state.nextAutoAttack = nextAA[player.UserId] or 0
	state.attackTarget = nil
	Remotes.event("CombatUpdated"):FireClient(player, state)
	FxRelay.emit({
		kind = "recall",
		origin = root.Position,
		userId = player.UserId,
		team = matchPlayer.team,
		duration = Config.Combat.RecallSeconds,
	})
	task.delay(Config.Combat.RecallSeconds, function()
		if recallToken[player.UserId] ~= token then
			return
		end
		completeRecall(player)
	end)
	return { ok = true, combat = state }
end

function CombatService.bindCharacter(userId: number, model: Model)
	boundModels[userId] = model
end

function CombatService.unbindCharacter(userId: number)
	boundModels[userId] = nil
end

function CombatService.rootOf(userId: number): BasePart?
	return rootOf(userId)
end

function CombatService.modelOf(userId: number): Model?
	return modelOf(userId)
end

function CombatService.characterRoot(player: Player): BasePart?
	return rootOf(player.UserId)
end

function CombatService.get(userId: number): Types.CombatState?
	return combat[userId]
end

local function resetFor(userId: number, championId: string)
	local champ = ChampionCatalog.get(championId) or ChampionCatalog.get(ChampionCatalog.defaultId())
	if not champ then
		return
	end
	local level = currentLevel(userId)
	local state: Types.CombatState = {
		health = 1,
		maxHealth = 1,
		mana = 0,
		maxMana = 0,
		shield = 0,
		bonusDamage = 0,
		abilityPower = 0,
		armor = 0,
		cooldowns = emptyCooldowns(),
		alive = true,
		nextAutoAttack = 0,
		attackTarget = nil,
		level = level,
		ranks = Progression.autoRanks(level),
		respawnAt = nil,
		recalling = false,
		recallEndsAt = nil,
		recallStartedAt = nil,
		trinketReadyAt = 0,
		lensReadyAt = 0,
	}
	fillVitals(state, userId, champ, level, true)
	combat[userId] = state
	locks[userId] = nil
	nextAA[userId] = 0
	recallOrigin[userId] = nil
	recallToken[userId] = (recallToken[userId] or 0) + 1
	local player = playerOf(userId)
	if player then
		player:SetAttribute(Constants.Attributes.ChampionId, champ.id)
		player:SetAttribute(Constants.Attributes.Recalling, nil)
		ShopService.applyMovement(player)
	end
	local model = modelOf(userId)
	if model then
		model:SetAttribute(Constants.Attributes.ChampionId, champ.id)
		local snapshot = if matchApi then matchApi.getSnapshot() else nil
		local matchPlayer = if snapshot then snapshot.players[tostring(userId)] else nil
		ChampionAppearance.apply(model, {
			championId = champ.id,
			team = if matchPlayer then matchPlayer.team else "Blue",
			displayName = if matchPlayer then matchPlayer.displayName else champ.name,
			isBot = if matchPlayer then matchPlayer.isBot else userId < 0,
		})
	end
	state.trinketReadyAt = WardService.trinketReadyAt(userId)
	state.lensReadyAt = WardService.lensReadyAt(userId)
	applyHumanoid(userId, state)
	fireCombat(userId)
end

function CombatService.reset(player: Player, championId: string)
	resetFor(player.UserId, championId)
end

function CombatService.resetBot(userId: number, championId: string)
	resetFor(userId, championId)
end

local outgoingAmp: { [number]: number } = {}

function CombatService.setOutgoingAmp(userId: number, amp: number)
	outgoingAmp[userId] = amp
end

function CombatService.getOutgoingAmp(userId: number): number
	return outgoingAmp[userId] or 1
end

function CombatService.reapplyItemsFor(userId: number)
	local state = combat[userId]
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	local matchPlayer = if snapshot then snapshot.players[tostring(userId)] else nil
	local champId = if matchPlayer then matchPlayer.championId else nil
	if not state or typeof(champId) ~= "string" then
		return
	end
	local champ = ChampionCatalog.get(champId)
	if not champ then
		return
	end
	fillVitals(state, userId, champ, state.level, false)
	if state.alive then
		applyHumanoid(userId, state)
	end
	local player = playerOf(userId)
	if player then
		ShopService.applyMovement(player)
	else
		ShopService.applyMovementToModel(modelOf(userId), userId)
	end
	fireCombat(userId)
end

function CombatService.reapplyItems(player: Player)
	CombatService.reapplyItemsFor(player.UserId)
end

function CombatService.applyLevelFor(userId: number, level: number)
	local state = combat[userId]
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	local matchPlayer = if snapshot then snapshot.players[tostring(userId)] else nil
	local champId = if matchPlayer then matchPlayer.championId else nil
	if not state or typeof(champId) ~= "string" then
		return
	end
	local champ = ChampionCatalog.get(champId)
	if not champ then
		return
	end
	fillVitals(state, userId, champ, level, false)
	if state.alive then
		applyHumanoid(userId, state)
	end
	fireCombat(userId)
end

function CombatService.applyLevel(player: Player, level: number)
	CombatService.applyLevelFor(player.UserId, level)
end

function CombatService.clear(userId: number)
	combat[userId] = nil
	locks[userId] = nil
	nextAA[userId] = nil
	recentHits[userId] = nil
	recallOrigin[userId] = nil
	boundModels[userId] = nil
	outgoingAmp[userId] = nil
	deathToken[userId] = (deathToken[userId] or 0) + 1
	recallToken[userId] = (recallToken[userId] or 0) + 1
	local player = playerOf(userId)
	if player then
		player:SetAttribute(Constants.Attributes.Recalling, nil)
	end
end

function CombatService.clearAll()
	for _, player in Players:GetPlayers() do
		player:SetAttribute(Constants.Attributes.Recalling, nil)
	end
	table.clear(combat)
	table.clear(locks)
	table.clear(nextAA)
	table.clear(recentHits)
	table.clear(deathToken)
	table.clear(recallToken)
	table.clear(recallOrigin)
	table.clear(boundModels)
	table.clear(outgoingAmp)
end

function CombatService.init(api: MatchApi)
	matchApi = api

	Players.PlayerRemoving:Connect(function(player)
		CombatService.clear(player.UserId)
	end)

	local function hookCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.defer(function()
				local snapshot = if matchApi then matchApi.getSnapshot() else nil
				if not snapshot or snapshot.phase ~= "InProgress" then
					return
				end
				local matchPlayer = snapshot.players[tostring(player.UserId)]
				if matchPlayer and matchPlayer.championId then
					ChampionAppearance.applyMatchPlayer(character, matchPlayer)
					local existing = combat[player.UserId]
					if existing and not existing.alive then
						applyHumanoid(player.UserId, existing)
						return
					end
					CombatService.reset(player, matchPlayer.championId)
				end
			end)
		end)
	end
	for _, player in Players:GetPlayers() do
		hookCharacter(player)
	end
	Players.PlayerAdded:Connect(hookCharacter)

	task.spawn(function()
		while true do
			task.wait(1)
			local snapshot = if matchApi then matchApi.getSnapshot() else nil
			if not snapshot or snapshot.phase ~= "InProgress" then
				continue
			end
			for userId, state in combat do
				if state.alive then
					local root = rootOf(userId)
					local atFountain = if root then ShopService.nearFountain(userId, root.Position) else false
					local hpRegen = if atFountain then Config.Combat.FountainHpRegen else Config.Combat.RegenPerSecond
					local mpRegen = if atFountain then Config.Combat.FountainManaRegen else Config.Combat.ManaRegenPerSecond
					state.health = math.min(state.maxHealth, state.health + hpRegen)
					state.mana = math.min(state.maxMana, state.mana + mpRegen)
					applyHumanoid(userId, state)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.1)
			local snapshot = if matchApi then matchApi.getSnapshot() else nil
			if not snapshot or snapshot.phase ~= "InProgress" then
				continue
			end
			for userId, state in combat do
				local player = playerOf(userId)
				if player and state.recalling and state.alive then
					local root = rootOf(userId)
					local origin = recallOrigin[userId]
					if root and origin and (root.Position - origin).Magnitude > Config.Combat.RecallMoveCancel then
						interruptRecall(player)
					end
				end
				if locks[userId] then
					tickAutoAttack(userId)
				end
			end
		end
	end)
end

function CombatService.respawnUser(userId: number)
	local state = combat[userId]
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not state or not snapshot or snapshot.phase ~= "InProgress" then
		return
	end
	local matchPlayer = snapshot.players[tostring(userId)]
	if not matchPlayer or not matchPlayer.championId then
		return
	end
	state.alive = true
	state.respawnAt = nil
	state.shield = 0
	locks[userId] = nil
	local champ = ChampionCatalog.get(matchPlayer.championId)
	if champ then
		fillVitals(state, userId, champ, matchPlayer.level, true)
	end
	local spawn = MapBuilder.getSpawn(matchPlayer.team)
	local player = playerOf(userId)
	if player then
		player.RespawnLocation = spawn
	end
	local character = modelOf(userId)
	if character then
		pcall(function()
			character:PivotTo(spawn.CFrame + Vector3.new(0, 5, 0))
		end)
	end
	applyHumanoid(userId, state)
	if player then
		ShopService.applyMovement(player)
	else
		ShopService.applyMovementToModel(character, userId)
	end
	if matchApi then
		matchApi.setRespawnAt(userId, nil)
	end
	fireCombat(userId)
end

function CombatService.respawn(player: Player)
	CombatService.respawnUser(player.UserId)
end

local function killUser(victimUserId: number, killerUserId: number?)
	local state = combat[victimUserId]
	if not state or not state.alive then
		return
	end
	state.alive = false
	state.health = 0
	locks[victimUserId] = nil
	local victimPlayer = playerOf(victimUserId)
	if victimPlayer then
		interruptRecall(victimPlayer)
	end
	local wait = Progression.respawnSeconds(state.level)
	state.respawnAt = now() + wait
	applyHumanoid(victimUserId, state)
	fireCombat(victimUserId)
	if matchApi then
		matchApi.setRespawnAt(victimUserId, state.respawnAt)
	end

	local token = (deathToken[victimUserId] or 0) + 1
	deathToken[victimUserId] = token
	task.delay(wait, function()
		if deathToken[victimUserId] ~= token then
			return
		end
		CombatService.respawnUser(victimUserId)
	end)

	if matchApi then
		local assists: { number } = {}
		local snapshot = matchApi.getSnapshot()
		local bag = recentHits[victimUserId]
		recentHits[victimUserId] = nil
		if killerUserId and snapshot and bag then
			local killerMatch = snapshot.players[tostring(killerUserId)]
			local t = now()
			for userId, at in bag do
				if userId ~= killerUserId and t - at <= Config.Match.AssistWindow then
					local otherMatch = snapshot.players[tostring(userId)]
					if killerMatch and otherMatch and otherMatch.team == killerMatch.team then
						table.insert(assists, userId)
					end
				end
			end
		end
		matchApi.onPlayerKilled(killerUserId, victimUserId, assists)
	end
end

local function noteAssist(attackerUserId: number, victimUserId: number)
	local bag = recentHits[victimUserId]
	if not bag then
		bag = {}
		recentHits[victimUserId] = bag
	end
	bag[attackerUserId] = now()
end

local function damageUser(attackerUserId: number?, targetUserId: number, amount: number)
	if attackerUserId and attackerUserId == targetUserId then
		return
	end
	local state = combat[targetUserId]
	if not state or not state.alive then
		return
	end
	local reduced = amount * (1 - (state.armor or 0))
	if reduced > 0 then
		local targetPlayer = playerOf(targetUserId)
		if targetPlayer then
			interruptRecall(targetPlayer)
		end
	end
	local remaining = reduced
	if (state.shield or 0) > 0 then
		local absorbed = math.min(state.shield, remaining)
		state.shield -= absorbed
		remaining -= absorbed
	end
	if remaining > 0 then
		state.health = math.max(0, state.health - remaining)
	end
	applyHumanoid(targetUserId, state)
	fireCombat(targetUserId)
	if attackerUserId and matchApi then
		if reduced > 0 then
			matchApi.addDamageDealt(attackerUserId, reduced)
		end
		noteAssist(attackerUserId, targetUserId)
		local snapshot = matchApi.getSnapshot()
		local victim = if snapshot then snapshot.players[tostring(targetUserId)] else nil
		if victim then
			TowerService.noteThreat(attackerUserId, victim.team)
		end
	end
	if state.health <= 0 then
		killUser(targetUserId, attackerUserId)
	end
end

function CombatService.applyDamageToUser(targetUserId: number, amount: number)
	damageUser(nil, targetUserId, amount)
end

function CombatService.applyDamageToPlayer(target: Player, amount: number)
	damageUser(nil, target.UserId, amount)
end

function CombatService.damagePlayersNear(attackerTeam: Types.TeamId, position: Vector3, range: number, amount: number)
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot then
		return
	end
	for _, otherMatch in snapshot.players do
		local otherRoot = rootOf(otherMatch.userId)
		if otherMatch.team ~= attackerTeam and otherRoot then
			if (otherRoot.Position - position).Magnitude <= range then
				damageUser(nil, otherMatch.userId, amount)
			end
		end
	end
end

local function shieldUser(targetUserId: number, amount: number)
	local state = combat[targetUserId]
	if not state or not state.alive or amount <= 0 then
		return
	end
	state.shield = math.min(state.maxHealth, state.shield + amount)
	fireCombat(targetUserId)
	local root = rootOf(targetUserId)
	if root then
		FxRelay.emit({
			kind = "shield",
			origin = root.Position,
			userId = targetUserId,
			duration = 1.15,
		})
	end
end

local function stunUser(targetUserId: number, seconds: number)
	if seconds <= 0 then
		return
	end
	local character = modelOf(targetUserId)
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local token = (humanoid:GetAttribute("MeoStunToken") :: number? or 0) + 1
	humanoid:SetAttribute("MeoStunToken", token)
	local walk = humanoid.WalkSpeed
	local jump = humanoid.JumpPower
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	local root = character:FindFirstChild("HumanoidRootPart")
	FxRelay.emit({
		kind = "stun",
		origin = if root and root:IsA("BasePart") then root.Position else character:GetPivot().Position,
		userId = targetUserId,
		duration = seconds,
	})
	task.delay(seconds, function()
		if humanoid.Parent and humanoid:GetAttribute("MeoStunToken") == token then
			humanoid.WalkSpeed = walk
			humanoid.JumpPower = jump
		end
	end)
end

local function healUser(targetUserId: number, amount: number)
	local state = combat[targetUserId]
	if not state or not state.alive then
		return
	end
	state.health = math.min(state.maxHealth, state.health + amount)
	applyHumanoid(targetUserId, state)
	fireCombat(targetUserId)
	local root = rootOf(targetUserId)
	if root then
		FxRelay.emit({
			kind = "heal",
			origin = root.Position,
			userId = targetUserId,
		})
	end
end

local function damageObjective(attackerUserId: number?, part: BasePart, amount: number)
	local id = part:GetAttribute(Constants.Attributes.ObjectiveId)
	if typeof(id) ~= "string" then
		return
	end
	local healthAttr = part:GetAttribute("Health")
	local health = if typeof(healthAttr) == "number" then healthAttr else 0
	if health <= 0 then
		return
	end
	local kind = part:GetAttribute("Kind")
	local team = part:GetAttribute(Constants.Attributes.Team)
	if kind == "Nexus" and (team == "Blue" or team == "Red") and not MapBuilder.isNexusVulnerable(team) then
		return
	end
	health = math.max(0, health - amount)
	part:SetAttribute("Health", health)
	if health <= 0 then
		part.Transparency = 0.85
		part.CanCollide = false
		part.Color = Color3.fromRGB(40, 40, 40)
		if matchApi then
			local states = MapBuilder.objectiveStates()
			local objective = states[id]
			if objective then
				objective.alive = false
				objective.health = 0
				if attackerUserId then
					matchApi.addGold(attackerUserId, Config.Match.TowerGold)
				end
				-- Minions can melt a tower/nexus; the match still has to resolve.
				matchApi.onObjectiveDestroyed(attackerUserId, objective)
				MapBuilder.refreshNexusGate()
				local structureKind: "Tower" | "Nexus" = if objective.kind == "Nexus" then "Nexus" else "Tower"
				FxRelay.emit({
					kind = "structureDeath",
					origin = part.Position,
					team = if team == "Blue" or team == "Red" then team else nil,
					structureKind = structureKind,
				})
			end
		end
	end
end

function CombatService.damageObjectiveNear(attackerTeam: Types.TeamId, position: Vector3, range: number, amount: number)
	local map = MapBuilder.get()
	local objectives = map:FindFirstChild("Objectives")
	if not objectives then
		return
	end
	for _, child in objectives:GetChildren() do
		if child:IsA("BasePart") then
			local team = child:GetAttribute(Constants.Attributes.Team)
			if team ~= attackerTeam and (child.Position - position).Magnitude <= range then
				damageObjective(nil, child, amount)
			end
		end
	end
end

local function aaDamage(userId: number): number
	local state = combat[userId]
	local base = Config.AutoAttack.BaseDamage + if state then (state.bonusDamage or 0) else 0
	return base * (outgoingAmp[userId] or 1)
end

local function pushCombat(userId: number)
	local state = combat[userId]
	if not state then
		return
	end
	state.nextAutoAttack = nextAA[userId] or 0
	local lock = locks[userId]
	if lock then
		if lock.kind == "player" and lock.userId then
			local snapshot = if matchApi then matchApi.getSnapshot() else nil
			local other = if snapshot then snapshot.players[tostring(lock.userId)] else nil
			state.attackTarget = if other then other.displayName else "champion"
		elseif lock.kind == "minion" then
			state.attackTarget = "kitten"
		elseif lock.kind == "jungle" then
			state.attackTarget = "camp"
		elseif lock.kind == "objective" then
			state.attackTarget = lock.objectiveId or "structure"
		elseif lock.kind == "ward" then
			state.attackTarget = "ward"
		end
	else
		state.attackTarget = nil
	end
	state.trinketReadyAt = WardService.trinketReadyAt(userId)
	state.lensReadyAt = WardService.lensReadyAt(userId)
	fireCombat(userId)
end

local function walkToward(userId: number, dest: Vector3)
	local character = modelOf(userId)
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(userId)
	if humanoid and root and not root.Anchored then
		humanoid:MoveTo(Vector3.new(dest.X, dest.Y, dest.Z))
	end
end

local function resolveTarget(lock: AttackLock): (Vector3?, string?)
	if lock.kind == "player" and lock.userId then
		local otherState = combat[lock.userId]
		if not otherState or not otherState.alive then
			return nil, "dead"
		end
		local root = rootOf(lock.userId)
		if not root then
			return nil, "gone"
		end
		return root.Position, nil
	elseif lock.kind == "minion" and lock.minionId then
		local minion = MinionService.get(lock.minionId)
		if not minion or minion.health <= 0 or not minion.part.Parent then
			return nil, "dead"
		end
		return minion.part.Position, nil
	elseif lock.kind == "jungle" and lock.jungleId then
		local monster = JungleService.get(lock.jungleId)
		if not monster or monster.health <= 0 or not monster.part.Parent then
			return nil, "dead"
		end
		return monster.part.Position, nil
	elseif lock.kind == "objective" and lock.objectiveId then
		local part = MapBuilder.getObjectivePart(lock.objectiveId)
		if not part then
			return nil, "gone"
		end
		local hp = part:GetAttribute("Health")
		if typeof(hp) == "number" and hp <= 0 then
			return nil, "dead"
		end
		return part.Position, nil
	elseif lock.kind == "ward" and lock.wardId then
		local ward = WardService.get(lock.wardId)
		if not ward or ward.health <= 0 or not ward.part.Parent then
			return nil, "dead"
		end
		return ward.part.Position, nil
	end
	return nil, "gone"
end

local function visibleTo(viewerUserId: number, lock: AttackLock): boolean
	if lock.kind == "objective" then
		return true
	end
	if lock.kind == "player" and lock.userId then
		return VisionService.canSeeChampion(viewerUserId, lock.userId)
	end
	if lock.kind == "minion" and lock.minionId then
		return VisionService.canSeeMinion(viewerUserId, lock.minionId)
	end
	if lock.kind == "jungle" and lock.jungleId then
		return VisionService.canSeeJungle(viewerUserId, lock.jungleId)
	end
	if lock.kind == "ward" and lock.wardId then
		return VisionService.canSeeWard(viewerUserId, lock.wardId)
	end
	return false
end

local function strike(attackerUserId: number, lock: AttackLock)
	local power = aaDamage(attackerUserId)
	if lock.kind == "player" and lock.userId then
		damageUser(attackerUserId, lock.userId, power)
	elseif lock.kind == "minion" and lock.minionId then
		local minion = MinionService.get(lock.minionId)
		if minion then
			TowerService.noteThreat(attackerUserId, minion.team)
			MinionService.applyDamage(attackerUserId, minion.id, power)
		end
	elseif lock.kind == "jungle" and lock.jungleId then
		JungleService.applyDamage(attackerUserId, lock.jungleId, power)
	elseif lock.kind == "objective" and lock.objectiveId then
		local part = MapBuilder.getObjectivePart(lock.objectiveId)
		if part then
			local team = part:GetAttribute(Constants.Attributes.Team)
			if team == "Blue" or team == "Red" then
				TowerService.noteThreat(attackerUserId, team)
			end
			damageObjective(attackerUserId, part, power)
		end
	elseif lock.kind == "ward" and lock.wardId then
		WardService.applyDamage(playerOf(attackerUserId), lock.wardId, power)
	end
end

local function acquireNear(viewerUserId: number, team: Types.TeamId, origin: Vector3): AttackLock?
	local best: AttackLock? = nil
	local bestDist = Config.AutoAttack.AcquireRange
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot then
		return nil
	end
	for _, otherMatch in snapshot.players do
		local otherRoot = rootOf(otherMatch.userId)
		local otherState = combat[otherMatch.userId]
		if otherMatch.team ~= team and otherRoot and otherState and otherState.alive then
			local d = (otherRoot.Position - origin).Magnitude
			if d <= bestDist and VisionService.canSeeChampion(viewerUserId, otherMatch.userId) then
				best = { kind = "player", userId = otherMatch.userId }
				bestDist = d
			end
		end
	end
	for _, minion in MinionService.list() do
		if minion.team ~= team then
			local d = (minion.part.Position - origin).Magnitude
			if d <= bestDist and VisionService.canSeeMinion(viewerUserId, minion.id) then
				best = { kind = "minion", minionId = minion.id }
				bestDist = d
			end
		end
	end
	for _, monster in JungleService.list() do
		local d = (monster.part.Position - origin).Magnitude
		if d <= bestDist and VisionService.canSeeJungle(viewerUserId, monster.id) then
			best = { kind = "jungle", jungleId = monster.id }
			bestDist = d
		end
	end
	local map = MapBuilder.get()
	local objectives = map:FindFirstChild("Objectives")
	if objectives then
		for _, child in objectives:GetChildren() do
			if child:IsA("BasePart") then
				local objTeam = child:GetAttribute(Constants.Attributes.Team)
				local hp = child:GetAttribute("Health")
				if objTeam ~= team and typeof(hp) == "number" and hp > 0 then
					local d = (child.Position - origin).Magnitude
					if d <= bestDist then
						local id = child:GetAttribute(Constants.Attributes.ObjectiveId)
						if typeof(id) == "string" then
							best = { kind = "objective", objectiveId = id }
							bestDist = d
						end
					end
				end
			end
		end
	end
	for _, ward in WardService.list() do
		if ward.team ~= team then
			local d = (ward.part.Position - origin).Magnitude
			if d <= bestDist and VisionService.canSeeWard(viewerUserId, ward.id) then
				best = { kind = "ward", wardId = ward.id }
				bestDist = d
			end
		end
	end
	return best
end

tickAutoAttack = function(userId: number)
	local state = combat[userId]
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not state or not state.alive or not snapshot or snapshot.phase ~= "InProgress" then
		return
	end
	local matchPlayer = snapshot.players[tostring(userId)]
	local root = rootOf(userId)
	if not matchPlayer or not root then
		return
	end

	local lock = locks[userId]
	if lock and not lock.userId and not lock.minionId and not lock.objectiveId and not lock.jungleId and not lock.wardId then
		local acquired = acquireNear(userId, matchPlayer.team, root.Position)
		if acquired then
			acquired.moveTo = lock.moveTo
			lock = acquired
			locks[userId] = lock
		end
	end
	if not lock then
		return
	end

	if lock.userId or lock.minionId or lock.objectiveId or lock.jungleId or lock.wardId then
		if not visibleTo(userId, lock) then
			if lock.moveTo then
				locks[userId] = { kind = "player", moveTo = lock.moveTo }
			else
				locks[userId] = nil
				pushCombat(userId)
			end
			return
		end
		local pos = resolveTarget(lock)
		if not pos then
			if lock.moveTo then
				locks[userId] = { kind = "player", moveTo = lock.moveTo }
			else
				locks[userId] = nil
				pushCombat(userId)
			end
			return
		end
		local dist = (pos - root.Position).Magnitude
		if dist > Config.AutoAttack.Range then
			lock.windupEnds = nil
			walkToward(userId, pos)
			return
		end
		if lock.kind == "objective" and lock.objectiveId then
			local part = MapBuilder.getObjectivePart(lock.objectiveId)
			local kind = if part then part:GetAttribute("Kind") else nil
			local team = if part then part:GetAttribute(Constants.Attributes.Team) else nil
			if kind == "Nexus" and (team == "Blue" or team == "Red") and not MapBuilder.isNexusVulnerable(team) then
				lock.windupEnds = nil
				return
			end
		end
		local readyAt = nextAA[userId] or 0
		local t = now()
		if t < readyAt then
			return
		end
		if not lock.windupEnds then
			lock.windupEnds = t + Config.AutoAttack.Windup
			return
		end
		if t < lock.windupEnds then
			return
		end
		if not visibleTo(userId, lock) then
			lock.windupEnds = nil
			return
		end
		strike(userId, lock)
		lock.windupEnds = nil
		nextAA[userId] = t + Config.AutoAttack.Interval
		pushCombat(userId)
		FxRelay.emit({
			kind = "aa",
			origin = root.Position,
			dest = pos,
			userId = userId,
			team = matchPlayer.team,
		})
		return
	end

	if lock.moveTo then
		local remaining = lock.moveTo - root.Position
		if remaining.Magnitude <= 3 then
			locks[userId] = nil
			pushCombat(userId)
			return
		end
		walkToward(userId, lock.moveTo)
	end
end

function CombatService.issueAttackFor(userId: number, request: unknown): Types.AbilityResult
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot or snapshot.phase ~= "InProgress" then
		return { ok = false, error = "Match is not in progress." }
	end
	local matchPlayer = snapshot.players[tostring(userId)]
	local state = combat[userId]
	if not matchPlayer or not state or not state.alive then
		return { ok = false, error = "You are down. Wait for respawn." }
	end
	if typeof(request) ~= "table" then
		return { ok = false, error = "Invalid attack." }
	end
	local kind = (request :: any).kind
	local player = playerOf(userId)
	if kind == "stop" then
		if player then
			interruptRecall(player)
		end
		locks[userId] = nil
		pushCombat(userId)
		return { ok = true, combat = state }
	end

	local lock: AttackLock
	if kind == "player" then
		local targetId = (request :: any).userId
		if typeof(targetId) ~= "number" then
			return { ok = false, error = "No champion targeted." }
		end
		local otherMatch = snapshot.players[tostring(targetId)]
		if not otherMatch or otherMatch.team == matchPlayer.team then
			return { ok = false, error = "Not an enemy champion." }
		end
		if not VisionService.canSeeChampion(userId, targetId) then
			return { ok = false, error = "No vision." }
		end
		lock = { kind = "player", userId = targetId }
	elseif kind == "minion" then
		local minionId = (request :: any).minionId
		if typeof(minionId) ~= "string" then
			return { ok = false, error = "No kitten targeted." }
		end
		local minion = MinionService.get(minionId)
		if not minion or minion.team == matchPlayer.team then
			return { ok = false, error = "Not an enemy kitten." }
		end
		if not VisionService.canSeeMinion(userId, minionId) then
			return { ok = false, error = "No vision." }
		end
		lock = { kind = "minion", minionId = minionId }
	elseif kind == "jungle" then
		local jungleId = (request :: any).jungleId
		if typeof(jungleId) ~= "string" then
			return { ok = false, error = "No camp targeted." }
		end
		local monster = JungleService.get(jungleId)
		if not monster or monster.health <= 0 then
			return { ok = false, error = "That camp is gone." }
		end
		if not VisionService.canSeeJungle(userId, jungleId) then
			return { ok = false, error = "No vision." }
		end
		lock = { kind = "jungle", jungleId = jungleId }
	elseif kind == "objective" then
		local objectiveId = (request :: any).objectiveId
		if typeof(objectiveId) ~= "string" then
			return { ok = false, error = "No structure targeted." }
		end
		local part = MapBuilder.getObjectivePart(objectiveId)
		if not part then
			return { ok = false, error = "Unknown structure." }
		end
		local team = part:GetAttribute(Constants.Attributes.Team)
		if team == matchPlayer.team then
			return { ok = false, error = "That's your tower." }
		end
		lock = { kind = "objective", objectiveId = objectiveId }
	elseif kind == "ward" then
		local wardId = (request :: any).wardId
		if typeof(wardId) ~= "string" then
			return { ok = false, error = "No ward targeted." }
		end
		local ward = WardService.get(wardId)
		if not ward or ward.health <= 0 then
			return { ok = false, error = "That ward is gone." }
		end
		if ward.team == matchPlayer.team then
			return { ok = false, error = "That's your yarn eye." }
		end
		if not VisionService.canSeeWard(userId, wardId) then
			return { ok = false, error = "No vision on that ward." }
		end
		lock = { kind = "ward", wardId = wardId }
	else
		return { ok = false, error = "Unknown attack." }
	end

	if player then
		interruptRecall(player)
	end
	locks[userId] = lock
	pushCombat(userId)
	tickAutoAttack(userId)
	return { ok = true, combat = state }
end

function CombatService.issueAttack(player: Player, request: unknown): Types.AbilityResult
	return CombatService.issueAttackFor(player.UserId, request)
end

function CombatService.attackMove(player: Player, position: unknown): Types.AbilityResult
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot or snapshot.phase ~= "InProgress" then
		return { ok = false, error = "Match is not in progress." }
	end
	local state = combat[player.UserId]
	if not state or not state.alive then
		return { ok = false, error = "You are down. Wait for respawn." }
	end
	if typeof(position) ~= "Vector3" then
		return { ok = false, error = "Need a ground point." }
	end
	local dest = position :: Vector3
	local bounds = Constants.MapBounds
	dest = Vector3.new(
		math.clamp(dest.X, bounds.MinX, bounds.MaxX),
		2,
		math.clamp(dest.Z, bounds.MinZ, bounds.MaxZ)
	)
	interruptRecall(player)
	locks[player.UserId] = { kind = "player", moveTo = dest }
	pushCombat(player.UserId)
	tickAutoAttack(player.UserId)
	return { ok = true, combat = state }
end

function CombatService.useAbilityFor(userId: number, request: unknown): Types.AbilityResult
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot or snapshot.phase ~= "InProgress" then
		return { ok = false, error = "Match is not in progress." }
	end

	local matchPlayer = snapshot.players[tostring(userId)]
	if not matchPlayer or not matchPlayer.championId then
		return { ok = false, error = "Pick a champion first." }
	end

	if typeof(request) ~= "table" then
		return { ok = false, error = "Invalid ability request." }
	end

	local slot = (request :: any).slot
	local aim = (request :: any).aimPosition
	if slot ~= "Q" and slot ~= "W" and slot ~= "E" and slot ~= "R" then
		return { ok = false, error = "Unknown ability slot." }
	end
	if typeof(aim) ~= "Vector3" then
		return { ok = false, error = "Aim position required." }
	end

	local champ = ChampionCatalog.get(matchPlayer.championId)
	if not champ then
		return { ok = false, error = "Unknown champion." }
	end
	local ability = champ.abilities[slot]
	local state = combat[userId]
	if not ability or not state then
		return { ok = false, error = "Combat state missing." }
	end
	if not state.alive then
		return { ok = false, error = "You are down. Wait for respawn." }
	end
	local rank = if state.ranks then state.ranks[slot] else 0
	if (rank or 0) <= 0 then
		if slot == "R" then
			return { ok = false, error = `Ultimate unlocks at level {Progression.RUnlockLevel}.` }
		end
		return { ok = false, error = "That ability is not learned yet." }
	end

	local t = now()
	if state.cooldowns[slot] > t then
		return { ok = false, error = "Ability on cooldown." }
	end
	if state.mana < ability.manaCost then
		return { ok = false, error = "Not enough mana." }
	end

	local root = rootOf(userId)
	if not root then
		return { ok = false, error = "No character." }
	end

	local mode = Targeting.of(ability)
	local origin = root.Position
	local dest = aim
	if mode == "instant" then
		dest = origin
	elseif mode == "line" or mode == "dash" then
		dest = Targeting.clampAim(origin, aim, ability.range)
	else
		local distance = Targeting.flat(origin, aim).Magnitude
		if distance > ability.range + 6 then
			return { ok = false, error = "Out of range." }
		end
	end

	local function hitsPoint(position: Vector3, extra: number): boolean
		return Targeting.hits(mode, origin, dest, position, ability.radius + extra)
	end

	local player = playerOf(userId)
	if player then
		interruptRecall(player)
	end
	state.mana -= ability.manaCost
	state.cooldowns[slot] = t + ability.cooldown
	-- Notify before hits resolve so bots can sidestep this cast.
	if abilityCastListener and (mode == "line" or mode == "ground") then
		abilityCastListener({
			userId = userId,
			team = matchPlayer.team,
			mode = mode,
			kind = ability.kind,
			origin = origin,
			dest = dest,
			radius = ability.radius,
		})
	end
	local scale = Progression.rankScale(rank)
	local ap = state.abilityPower or 0
	local power = 0
	if ability.damage > 0 then
		power = (ability.damage * scale + (state.bonusDamage or 0) + ap * 0.35) * (outgoingAmp[userId] or 1)
	end
	local healAmount = if ability.heal > 0 then ability.heal * scale + ap * 0.25 else 0
	local shieldAmount = if (ability.shield or 0) > 0 then (ability.shield or 0) * scale + ap * 0.2 else 0

	if mode == "dash" then
		local travel = Targeting.flat(origin, dest)
		if travel.Magnitude > 1 then
			root.CFrame = CFrame.new(dest.X, root.Position.Y, dest.Z)
		end
	end

	if healAmount > 0 then
		for _, otherMatch in snapshot.players do
			local otherRoot = rootOf(otherMatch.userId)
			if otherMatch.team == matchPlayer.team and otherRoot then
				if hitsPoint(otherRoot.Position, 0) or otherMatch.userId == userId then
					healUser(otherMatch.userId, healAmount)
				end
			end
		end
	end

	if shieldAmount > 0 then
		for _, otherMatch in snapshot.players do
			local otherRoot = rootOf(otherMatch.userId)
			if otherMatch.team == matchPlayer.team and otherRoot then
				if hitsPoint(otherRoot.Position, 0) or otherMatch.userId == userId then
					shieldUser(otherMatch.userId, shieldAmount)
				end
			end
		end
	end

	if (ability.stunSeconds or 0) > 0 then
		for _, otherMatch in snapshot.players do
			local otherRoot = rootOf(otherMatch.userId)
			if otherMatch.team ~= matchPlayer.team and otherRoot then
				if hitsPoint(otherRoot.Position, 0) then
					stunUser(otherMatch.userId, ability.stunSeconds or 0)
				end
			end
		end
	end

	if power > 0 then
		for _, otherMatch in snapshot.players do
			local otherRoot = rootOf(otherMatch.userId)
			if otherMatch.team ~= matchPlayer.team and otherRoot then
				if hitsPoint(otherRoot.Position, 0) then
					damageUser(userId, otherMatch.userId, power)
				end
			end
		end

		local minionHit = false
		for _, minion in MinionService.list() do
			if minion.team ~= matchPlayer.team then
				if hitsPoint(minion.part.Position, Config.Minions.HitRadius) then
					minionHit = true
					MinionService.applyDamage(userId, minion.id, power)
				end
			end
		end
		if minionHit then
			local foeTeam: Types.TeamId = if matchPlayer.team == "Blue" then "Red" else "Blue"
			TowerService.noteThreat(userId, foeTeam)
		end
		for _, monster in JungleService.list() do
			if hitsPoint(monster.part.Position, Config.Minions.HitRadius) then
				JungleService.applyDamage(userId, monster.id, power)
			end
		end
		WardService.damageWhere(player, matchPlayer.team, function(position: Vector3)
			return hitsPoint(position, 2)
		end, power)

		local map = MapBuilder.get()
		local objectives = map:FindFirstChild("Objectives")
		if objectives then
			for _, child in objectives:GetChildren() do
				if child:IsA("BasePart") then
					local team = child:GetAttribute(Constants.Attributes.Team)
					if team ~= matchPlayer.team and hitsPoint(child.Position, Config.Combat.StructureTouchRadius) then
						damageObjective(userId, child, power)
						if team == "Blue" or team == "Red" then
							TowerService.noteThreat(userId, team)
						end
					end
				end
			end
		end
	end

	state.trinketReadyAt = WardService.trinketReadyAt(userId)
	state.lensReadyAt = WardService.lensReadyAt(userId)
	fireCombat(userId)
	FxRelay.emit({
		kind = "ability",
		origin = origin,
		dest = dest,
		userId = userId,
		team = matchPlayer.team,
		mode = mode,
		abilityKind = ability.kind,
		radius = ability.radius,
	})
	return { ok = true, combat = state }
end

function CombatService.useAbility(player: Player, request: unknown): Types.AbilityResult
	return CombatService.useAbilityFor(player.UserId, request)
end

function CombatService.placeWard(player: Player, position: unknown): Types.AbilityResult
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot or snapshot.phase ~= "InProgress" then
		return { ok = false, error = "Match is not in progress." }
	end
	local matchPlayer = snapshot.players[tostring(player.UserId)]
	local state = combat[player.UserId]
	if not matchPlayer or not state or not state.alive then
		return { ok = false, error = "You are down. Wait for respawn." }
	end
	if typeof(position) ~= "Vector3" then
		return { ok = false, error = "Need a ground point." }
	end
	interruptRecall(player)
	local result = WardService.placeTrinket(player, matchPlayer.team, position :: Vector3)
	state.trinketReadyAt = WardService.trinketReadyAt(player.UserId)
	state.lensReadyAt = WardService.lensReadyAt(player.UserId)
	result.combat = state
	Remotes.event("CombatUpdated"):FireClient(player, state)
	return result
end

function CombatService.useLensFor(userId: number): Types.AbilityResult
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot or snapshot.phase ~= "InProgress" then
		return { ok = false, error = "Match is not in progress." }
	end
	local matchPlayer = snapshot.players[tostring(userId)]
	local state = combat[userId]
	if not matchPlayer or not state or not state.alive then
		return { ok = false, error = "You are down. Wait for respawn." }
	end
	local root = rootOf(userId)
	if not root then
		return { ok = false, error = "No character." }
	end
	local player = playerOf(userId)
	if player then
		interruptRecall(player)
	end
	local result = WardService.useLensFor(userId, matchPlayer.team, root)
	state.trinketReadyAt = WardService.trinketReadyAt(userId)
	state.lensReadyAt = WardService.lensReadyAt(userId)
	result.combat = state
	if player then
		Remotes.event("CombatUpdated"):FireClient(player, state)
	end
	return result
end

function CombatService.useLens(player: Player): Types.AbilityResult
	return CombatService.useLensFor(player.UserId)
end

return CombatService
