--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Progression = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Progression"))
local VisionLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("VisionLogic"))
local RecallLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RecallLogic"))
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Targeting = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Targeting"))
local ProjectileLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ProjectileLogic"))
local ChampionKits = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionKits"))
local ItemKits = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ItemKits"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)
local ChampionAppearance = require(script.Parent.Parent.World.ChampionAppearance)
local CosmeticService = require(script.Parent.Parent.Cosmetics.CosmeticService)
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
	kind: "player" | "minion" | "objective" | "jungle" | "ward" | "move",
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
local tickShots: () -> ()
local interruptRecall: (player: Player) -> ()
local breakRecall: (player: Player?, order: string) -> ()

export type AbilityCast = {
	userId: number,
	team: Types.TeamId,
	mode: Types.AbilityTargeting,
	kind: Types.AbilityKind,
	origin: Vector3,
	dest: Vector3,
	radius: number,
	travel: number?,
}

type Shot = {
	id: number,
	caster: number,
	team: Types.TeamId,
	origin: Vector3,
	dest: Vector3,
	speed: number,
	radius: number,
	power: number,
	healAmount: number,
	shieldAmount: number,
	stunSeconds: number,
	kind: Types.AbilityKind,
	championId: string,
	slot: Types.AbilitySlot,
	born: number,
	duration: number,
	lastPos: Vector3,
	hit: { [string]: boolean },
	fromBrush: boolean,
}

local abilityCastListener: ((AbilityCast) -> ())? = nil
local shots: { Shot } = {}
local nextShotId = 0

type Channel = {
	token: number,
	userId: number,
	team: Types.TeamId,
	championId: string,
	slot: Types.AbilitySlot,
	origin: Vector3,
	dest: Vector3,
	radius: number,
	power: number,
	healAmount: number,
	shieldAmount: number,
	stunSeconds: number,
	kind: Types.AbilityKind,
	interruptCooldown: number,
	interruptMana: number,
}

type Zone = {
	id: number,
	caster: number,
	team: Types.TeamId,
	championId: string,
	slot: Types.AbilitySlot,
	pos: Vector3,
	radius: number,
	power: number,
	healAmount: number,
	shieldAmount: number,
	stunSeconds: number,
	kind: Types.AbilityKind,
	pulsesLeft: number,
	nextAt: number,
	tick: number,
	expires: number,
}

local channels: { [number]: Channel } = {}
local channelToken: { [number]: number } = {}
local channelOrigin: { [number]: Vector3 } = {}
local zones: { Zone } = {}
local nextZoneId = 0
local interruptChannel: (userId: number, reason: string) -> ()
local completeChannel: (userId: number, token: number) -> ()

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

-- Orders that break the channel. F-again, death, and the shove check call interruptRecall directly.
breakRecall = function(player: Player?, order: string)
	if player and RecallLogic.breaksChannel(order) then
		interruptRecall(player)
	end
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
	if channels[player.UserId] then
		interruptChannel(player.UserId, "recall")
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
		channelSlot = nil,
		channelEndsAt = nil,
		channelStartedAt = nil,
		guardUntil = nil,
		guardReduction = nil,
		wickStacks = nil,
		wickUntil = nil,
		dataStacks = nil,
		dataUntil = nil,
		bleedStacks = nil,
		bleedUntil = nil,
		bleedFrom = nil,
		bleedEchoStacks = nil,
		bleedEchoUntil = nil,
		bleedEchoTarget = nil,
		markUntil = nil,
		markFrom = nil,
		markTarget = nil,
		vanishUntil = nil,
		plateStacks = nil,
		plateUntil = nil,
		platePer = nil,
		omenUntil = nil,
		omenCut = nil,
		chargeStacks = nil,
		chargeUntil = nil,
		curseStacks = nil,
		curseUntil = nil,
		curseFrom = nil,
		cursePer = nil,
		curseTick = nil,
		curseNext = nil,
		curseEchoStacks = nil,
		curseEchoUntil = nil,
		curseEchoTarget = nil,
		psiUntil = nil,
		psiFrom = nil,
		psiTarget = nil,
		trinketReadyAt = 0,
		lensReadyAt = 0,
		cleaveReadyAt = 0,
		charmUntil = nil,
		charmReadyAt = nil,
	}
	fillVitals(state, userId, champ, level, true)
	combat[userId] = state
	locks[userId] = nil
	nextAA[userId] = 0
	recallOrigin[userId] = nil
	recallToken[userId] = (recallToken[userId] or 0) + 1
	channels[userId] = nil
	channelOrigin[userId] = nil
	channelToken[userId] = (channelToken[userId] or 0) + 1
	local player = playerOf(userId)
	if player then
		player:SetAttribute(Constants.Attributes.ChampionId, champ.id)
		player:SetAttribute(Constants.Attributes.Recalling, nil)
		player:SetAttribute(Constants.Attributes.Channeling, nil)
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
		if player and not (matchPlayer and matchPlayer.isBot) then
			CosmeticService.dress(player)
		end
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
	channels[userId] = nil
	channelOrigin[userId] = nil
	channelToken[userId] = (channelToken[userId] or 0) + 1
	local kept: { Zone } = {}
	for _, zone in zones do
		if zone.caster ~= userId then
			table.insert(kept, zone)
		end
	end
	zones = kept
	local player = playerOf(userId)
	if player then
		player:SetAttribute(Constants.Attributes.Recalling, nil)
		player:SetAttribute(Constants.Attributes.Channeling, nil)
	end
end

function CombatService.clearAll()
	for _, player in Players:GetPlayers() do
		player:SetAttribute(Constants.Attributes.Recalling, nil)
		player:SetAttribute(Constants.Attributes.Channeling, nil)
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
	table.clear(shots)
	table.clear(channels)
	table.clear(channelOrigin)
	table.clear(channelToken)
	table.clear(zones)
	nextShotId = 0
	nextZoneId = 0
end

function CombatService.isChanneling(userId: number): boolean
	return channels[userId] ~= nil
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
					if not matchPlayer.isBot then
						CosmeticService.dress(player)
					end
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
					-- Orders cancel immediately. This only catches a shove while rooted.
					if root and origin and RecallLogic.movedTooFar((root.Position - origin).Magnitude, Config.Combat.RecallMoveCancel) then
						interruptRecall(player)
					end
				end
				if state.alive and not state.recalling and not channels[userId] then
					local root = rootOf(userId)
					local matchPlayer = snapshot.players[tostring(userId)]
					local model = modelOf(userId)
					local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
					if root and matchPlayer and humanoid and humanoid.JumpPower > 0 then
						local base = 16 + ShopService.bonuses(userId).walkSpeed
						local slow = WardService.slowMul(matchPlayer.team, root.Position)
						local step = ItemKits.charmStep(
							slow,
							ShopService.has(userId, ItemKits.CharmId),
							now(),
							state.charmUntil,
							state.charmReadyAt
						)
						state.charmUntil = step.untilAt
						state.charmReadyAt = step.readyAt
						humanoid.WalkSpeed = base * step.mul
						if step.procced then
							fireCombat(userId)
						end
					end
				end
				if channels[userId] and state.alive then
					local root = rootOf(userId)
					local origin = channelOrigin[userId]
					if root and origin and RecallLogic.movedTooFar((root.Position - origin).Magnitude, Config.Combat.RecallMoveCancel) then
						interruptChannel(userId, "shove")
					end
				end
				if locks[userId] then
					tickAutoAttack(userId)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.05)
			tickShots()
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
	state.guardUntil = nil
	state.guardReduction = nil
	state.wickStacks = nil
	state.wickUntil = nil
	state.dataStacks = nil
	state.dataUntil = nil
	state.bleedStacks = nil
	state.bleedUntil = nil
	state.bleedFrom = nil
	state.bleedEchoStacks = nil
	state.bleedEchoUntil = nil
	state.bleedEchoTarget = nil
	state.markUntil = nil
	state.markFrom = nil
	state.vanishUntil = nil
	state.plateStacks = nil
	state.plateUntil = nil
	state.platePer = nil
	state.omenUntil = nil
	state.omenCut = nil
	state.chargeStacks = nil
	state.chargeUntil = nil
	state.curseStacks = nil
	state.curseUntil = nil
	state.curseFrom = nil
	state.cursePer = nil
	state.curseTick = nil
	state.curseNext = nil
	state.curseEchoStacks = nil
	state.curseEchoUntil = nil
	state.curseEchoTarget = nil
	state.psiUntil = nil
	state.psiFrom = nil
	state.charmUntil = nil
	local ownedPsi = state.psiTarget
	state.psiTarget = nil
	local ownedMark = state.markTarget
	state.markTarget = nil
	if ownedMark then
		local marked = combat[ownedMark]
		if marked and marked.markFrom == victimUserId then
			marked.markFrom = nil
			marked.markUntil = nil
			fireCombat(ownedMark)
		end
	end
	if ownedPsi then
		local marked = combat[ownedPsi]
		if marked and marked.psiFrom == victimUserId then
			marked.psiFrom = nil
			marked.psiUntil = nil
			fireCombat(ownedPsi)
		end
	end
	for otherId, other in combat do
		if otherId ~= victimUserId then
			if other.bleedFrom == victimUserId then
				other.bleedStacks = nil
				other.bleedUntil = nil
				other.bleedFrom = nil
				fireCombat(otherId)
			end
			if other.curseFrom == victimUserId then
				other.curseStacks = nil
				other.curseUntil = nil
				other.curseFrom = nil
				other.cursePer = nil
				other.curseTick = nil
				other.curseNext = nil
				fireCombat(otherId)
			end
			if other.curseEchoTarget == victimUserId then
				other.curseEchoStacks = nil
				other.curseEchoUntil = nil
				other.curseEchoTarget = nil
				fireCombat(otherId)
			end
			if other.psiFrom == victimUserId then
				other.psiFrom = nil
				other.psiUntil = nil
				fireCombat(otherId)
			end
			if other.psiTarget == victimUserId then
				other.psiTarget = nil
				other.psiUntil = nil
				fireCombat(otherId)
			end
			if other.bleedEchoTarget == victimUserId then
				other.bleedEchoStacks = nil
				other.bleedEchoUntil = nil
				other.bleedEchoTarget = nil
				fireCombat(otherId)
			end
			if other.markTarget == victimUserId then
				other.markTarget = nil
				other.markUntil = nil
				fireCombat(otherId)
			end
		end
	end
	locks[victimUserId] = nil
	interruptChannel(victimUserId, "death")
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
		if killerUserId and snapshot then
			local killerMatch = snapshot.players[tostring(killerUserId)]
			local killerState = combat[killerUserId]
			if killerMatch and killerMatch.championId and killerState and killerState.alive then
				local resetSlots = ChampionKits.onTakedown(killerMatch.championId)
				if resetSlots then
					local readyAt = now()
					for _, resetSlot in resetSlots do
						killerState.cooldowns[resetSlot] = readyAt
					end
					fireCombat(killerUserId)
				end
			end
		end
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
	local raw = amount
	if attackerUserId and amount > 0 and matchApi then
		local snapshot = matchApi.getSnapshot()
		local attacker = if snapshot then snapshot.players[tostring(attackerUserId)] else nil
		local victimMatch = if snapshot then snapshot.players[tostring(targetUserId)] else nil
		if attacker and victimMatch and attacker.team ~= victimMatch.team then
			raw += ItemKits.fangBonus(state.health, state.maxHealth, ShopService.has(attackerUserId, ItemKits.FangId))
		end
	end
	local guarded = state.guardUntil ~= nil and now() < state.guardUntil
	local plates = if state.plateUntil ~= nil and now() < state.plateUntil then state.plateStacks or 0 else 0
	local omenLive = state.omenUntil ~= nil and now() < state.omenUntil and (state.omenCut or 0) > 0
	local reduced = raw
		* (1 - (state.armor or 0))
		* ChampionKits.guardMultiplier(state.guardReduction or 0, guarded)
		* ChampionKits.plateMultiplier(plates, state.platePer or 0)
		* (if omenLive then ChampionKits.omenMultiplier(state.omenCut or 0) else 1)
	if omenLive and amount > 0 then
		state.omenUntil = nil
		state.omenCut = nil
	end
	if reduced > 0 then
		breakRecall(playerOf(targetUserId), "damage")
		interruptChannel(targetUserId, "damage")
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
	local team = part:GetAttribute(Constants.Attributes.Team)
	if not MapBuilder.isObjectiveVulnerable(id) then
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
					tier = objective.tier,
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
		elseif lock.kind == "move" then
			state.attackTarget = nil
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
				if objTeam ~= team and typeof(hp) == "number" and hp > 0 and child:GetAttribute("Vulnerable") ~= false then
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
	-- Pure move orders walk. They do not auto-acquire (that is attack-move).
	if lock and lock.kind ~= "move" and not lock.userId and not lock.minionId and not lock.objectiveId and not lock.jungleId and not lock.wardId then
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
			if not MapBuilder.isObjectiveVulnerable(lock.objectiveId) then
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
		breakRecall(player, "stop")
		interruptChannel(userId, "stop")
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
		if not MapBuilder.isObjectiveVulnerable(objectiveId) then
			return { ok = false, error = "That structure is still gated." }
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

	breakRecall(player, "attack")
	interruptChannel(userId, "attack")
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
	local mine = snapshot.players[tostring(player.UserId)]
	if mine then
		local snap = Config.Vision.LastKnownSnap
		local best: Vector3? = nil
		local bestD = snap
		for _, otherMatch in snapshot.players do
			if otherMatch.team ~= mine.team and not VisionService.canSeeChampion(player.UserId, otherMatch.userId) then
				local known = VisionService.lastKnownOf(mine.team, otherMatch.userId)
				local otherRoot = rootOf(otherMatch.userId)
				-- Clicking a live hidden body would leak their current tile — remap.
				if otherRoot and (otherRoot.Position - dest).Magnitude <= snap then
					if known then
						dest = Vector3.new(known.X, 2, known.Z)
						best = nil
						break
					end
				end
				if known and VisionLogic.brushAt(known.X, known.Z) ~= nil then
					local d = (Vector3.new(known.X, dest.Y, known.Z) - dest).Magnitude
					if d < bestD then
						best = Vector3.new(known.X, 2, known.Z)
						bestD = d
					end
				end
			end
		end
		if best then
			dest = best
		end
	end
	breakRecall(player, "attackMove")
	interruptChannel(player.UserId, "attackMove")
	locks[player.UserId] = { kind = "player", moveTo = dest }
	pushCombat(player.UserId)
	tickAutoAttack(player.UserId)
	return { ok = true, combat = state }
end

-- WASD / stick passes nil (engine locomotion resumes). A ground click passes a point
-- and walks there without acquiring a target. Ignored once the channel is already down.
function CombatService.issueMove(player: Player, position: unknown): Types.AbilityResult
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot or snapshot.phase ~= "InProgress" then
		return { ok = false, error = "Match is not in progress." }
	end
	local state = combat[player.UserId]
	if not state or not state.alive then
		return { ok = false, error = "You are down. Wait for respawn." }
	end
	if not state.recalling and channels[player.UserId] == nil then
		return { ok = true, combat = state }
	end
	if state.recalling then
		breakRecall(player, "move")
	end
	if channels[player.UserId] then
		interruptChannel(player.UserId, "move")
	end
	if typeof(position) == "Vector3" then
		local dest = position :: Vector3
		local bounds = Constants.MapBounds
		dest = Vector3.new(
			math.clamp(dest.X, bounds.MinX, bounds.MaxX),
			2,
			math.clamp(dest.Z, bounds.MinZ, bounds.MaxZ)
		)
		locks[player.UserId] = { kind = "move", moveTo = dest }
		pushCombat(player.UserId)
		tickAutoAttack(player.UserId)
	end
	return { ok = true, combat = state }
end

type StrikeCtx = {
	caster: number,
	team: Types.TeamId,
	mode: Types.AbilityTargeting,
	origin: Vector3,
	dest: Vector3,
	lastPos: Vector3?,
	pos: Vector3?,
	radius: number,
	power: number,
	healAmount: number,
	shieldAmount: number,
	stunSeconds: number,
	hit: { [string]: boolean }?,
	championId: string?,
	slot: Types.AbilitySlot?,
	fromBrush: boolean?,
	fromZone: boolean?,
}

local function consumeHit(hit: { [string]: boolean }?, key: string): boolean
	if not hit then
		return true
	end
	if hit[key] then
		return false
	end
	hit[key] = true
	return true
end

local function pointHits(ctx: StrikeCtx, position: Vector3, extra: number): boolean
	local radius = ctx.radius + extra
	if ctx.lastPos and ctx.pos then
		return ProjectileLogic.sweepHits(ctx.lastPos, ctx.pos, position, radius)
	end
	return Targeting.hits(ctx.mode, ctx.origin, ctx.dest, position, radius)
end

local function liveWick(casterUserId: number): number
	local state = combat[casterUserId]
	if not state or state.wickUntil == nil or now() >= state.wickUntil then
		return 0
	end
	return state.wickStacks or 0
end

local function gainWick(casterUserId: number, cap: number, seconds: number)
	if cap <= 0 or seconds <= 0 then
		return
	end
	local state = combat[casterUserId]
	if not state or not state.alive then
		return
	end
	local current = if state.wickUntil ~= nil and now() < state.wickUntil then state.wickStacks or 0 else 0
	state.wickStacks = ChampionKits.addWick(current, cap)
	state.wickUntil = now() + seconds
	fireCombat(casterUserId)
end

local function clearWick(casterUserId: number)
	local state = combat[casterUserId]
	if not state or ((state.wickStacks or 0) <= 0 and state.wickUntil == nil) then
		return
	end
	state.wickStacks = nil
	state.wickUntil = nil
	fireCombat(casterUserId)
end

local function liveData(casterUserId: number): number
	local state = combat[casterUserId]
	if not state or state.dataUntil == nil or now() >= state.dataUntil then
		return 0
	end
	return state.dataStacks or 0
end

local function gainData(casterUserId: number, cap: number, seconds: number)
	if cap <= 0 or seconds <= 0 then
		return
	end
	local state = combat[casterUserId]
	if not state or not state.alive then
		return
	end
	local current = if state.dataUntil ~= nil and now() < state.dataUntil then state.dataStacks or 0 else 0
	state.dataStacks = ChampionKits.addData(current, cap)
	state.dataUntil = now() + seconds
	fireCombat(casterUserId)
end

local function clearData(casterUserId: number)
	local state = combat[casterUserId]
	if not state or ((state.dataStacks or 0) <= 0 and state.dataUntil == nil) then
		return
	end
	state.dataStacks = nil
	state.dataUntil = nil
	fireCombat(casterUserId)
end

local function liveBleed(targetUserId: number, casterUserId: number): number
	local state = combat[targetUserId]
	if not state or state.bleedFrom ~= casterUserId or state.bleedUntil == nil or now() >= state.bleedUntil then
		return 0
	end
	return state.bleedStacks or 0
end

local function gainBleed(targetUserId: number, casterUserId: number, cap: number, seconds: number)
	if cap <= 0 or seconds <= 0 then
		return
	end
	local state = combat[targetUserId]
	if not state or not state.alive then
		return
	end
	local current = if state.bleedFrom == casterUserId and state.bleedUntil ~= nil and now() < state.bleedUntil
		then state.bleedStacks or 0
		else 0
	state.bleedStacks = ChampionKits.addBleed(current, cap)
	state.bleedUntil = now() + seconds
	state.bleedFrom = casterUserId
	fireCombat(targetUserId)
	local caster = combat[casterUserId]
	if caster and caster.alive then
		caster.bleedEchoStacks = state.bleedStacks
		caster.bleedEchoUntil = state.bleedUntil
		caster.bleedEchoTarget = targetUserId
		fireCombat(casterUserId)
	end
end

local function clearBleed(targetUserId: number, casterUserId: number)
	local state = combat[targetUserId]
	if state and state.bleedFrom == casterUserId then
		state.bleedStacks = nil
		state.bleedUntil = nil
		state.bleedFrom = nil
		fireCombat(targetUserId)
	end
	local caster = combat[casterUserId]
	if caster and caster.bleedEchoTarget == targetUserId then
		caster.bleedEchoStacks = nil
		caster.bleedEchoUntil = nil
		caster.bleedEchoTarget = nil
		fireCombat(casterUserId)
	end
end

local function liveMark(targetUserId: number, casterUserId: number): boolean
	local state = combat[targetUserId]
	return state ~= nil and state.markFrom == casterUserId and state.markUntil ~= nil and now() < state.markUntil
end

local function clearMark(targetUserId: number, casterUserId: number)
	local state = combat[targetUserId]
	if state and state.markFrom == casterUserId then
		state.markFrom = nil
		state.markUntil = nil
		fireCombat(targetUserId)
	end
	local caster = combat[casterUserId]
	if caster and caster.markTarget == targetUserId then
		caster.markTarget = nil
		caster.markUntil = nil
		fireCombat(casterUserId)
	end
end

local function gainMark(targetUserId: number, casterUserId: number, seconds: number)
	if seconds <= 0 then
		return
	end
	local state = combat[targetUserId]
	if not state or not state.alive then
		return
	end
	local caster = combat[casterUserId]
	local previousId = if caster then caster.markTarget else nil
	if previousId and previousId ~= targetUserId then
		local previous = combat[previousId]
		if previous and previous.markFrom == casterUserId then
			previous.markFrom = nil
			previous.markUntil = nil
			fireCombat(previousId)
		end
	end
	state.markFrom = casterUserId
	state.markUntil = now() + seconds
	fireCombat(targetUserId)
	if caster and caster.alive then
		caster.markTarget = targetUserId
		caster.markUntil = state.markUntil
		fireCombat(casterUserId)
	end
end

local function liveVanish(casterUserId: number): boolean
	local state = combat[casterUserId]
	return state ~= nil and state.vanishUntil ~= nil and now() < state.vanishUntil
end

local function clearVanish(casterUserId: number)
	local state = combat[casterUserId]
	if not state or state.vanishUntil == nil then
		return
	end
	state.vanishUntil = nil
	fireCombat(casterUserId)
end

local function applyFortify(
	userId: number,
	seconds: number,
	reduction: number,
	championId: string,
	slot: Types.AbilitySlot
)
	if seconds <= 0 or reduction <= 0 then
		return
	end
	local state = combat[userId]
	if not state or not state.alive then
		return
	end
	local active = state.guardUntil ~= nil and now() < state.guardUntil
	if not ChampionKits.preferGuard(state.guardReduction or 0, active, reduction) then
		return
	end
	state.guardUntil = now() + seconds
	state.guardReduction = reduction
	local root = rootOf(userId)
	if root then
		FxRelay.emit({
			kind = "shield",
			origin = root.Position,
			userId = userId,
			duration = seconds,
			championId = championId,
			slot = slot,
		})
	end
	fireCombat(userId)
end

local function livePlate(casterUserId: number): number
	local state = combat[casterUserId]
	if not state or state.plateUntil == nil or now() >= state.plateUntil then
		return 0
	end
	return state.plateStacks or 0
end

local function gainPlate(casterUserId: number, cap: number, seconds: number, per: number)
	if cap <= 0 or seconds <= 0 or per <= 0 then
		return
	end
	local state = combat[casterUserId]
	if not state or not state.alive then
		return
	end
	local current = if state.plateUntil ~= nil and now() < state.plateUntil then state.plateStacks or 0 else 0
	state.plateStacks = ChampionKits.addPlate(current, cap)
	state.plateUntil = now() + seconds
	state.platePer = per
	fireCombat(casterUserId)
end

local function clearPlate(casterUserId: number)
	local state = combat[casterUserId]
	if not state or ((state.plateStacks or 0) <= 0 and state.plateUntil == nil) then
		return
	end
	state.plateStacks = nil
	state.plateUntil = nil
	state.platePer = nil
	fireCombat(casterUserId)
end

local function shortenCooldown(userId: number, slot: Types.AbilitySlot, seconds: number)
	if seconds <= 0 then
		return
	end
	local state = combat[userId]
	if not state then
		return
	end
	state.cooldowns[slot] = ChampionKits.shortenReady(state.cooldowns[slot], now(), seconds)
	fireCombat(userId)
end

local function allyWardDistance(team: Types.TeamId, origin: Vector3): number
	local best = math.huge
	for _, ward in WardService.list() do
		if ward.team == team and ward.part then
			local flat = Vector3.new(ward.part.Position.X - origin.X, 0, ward.part.Position.Z - origin.Z)
			if flat.Magnitude < best then
				best = flat.Magnitude
			end
		end
	end
	return best
end

local function applyOmen(targetUserId: number, seconds: number, cut: number)
	if seconds <= 0 or cut <= 0 then
		return
	end
	local state = combat[targetUserId]
	if not state or not state.alive then
		return
	end
	state.omenUntil = now() + seconds
	state.omenCut = cut
	fireCombat(targetUserId)
end

local function liveCharge(casterUserId: number): number
	local state = combat[casterUserId]
	if not state or state.chargeUntil == nil or now() >= state.chargeUntil then
		return 0
	end
	return state.chargeStacks or 0
end

local function gainCharge(casterUserId: number, cap: number, seconds: number)
	if cap <= 0 or seconds <= 0 then
		return
	end
	local state = combat[casterUserId]
	if not state or not state.alive then
		return
	end
	local current = if state.chargeUntil ~= nil and now() < state.chargeUntil then state.chargeStacks or 0 else 0
	state.chargeStacks = ChampionKits.addCharge(current, cap)
	state.chargeUntil = now() + seconds
	fireCombat(casterUserId)
end

local function clearCharge(casterUserId: number)
	local state = combat[casterUserId]
	if not state or ((state.chargeStacks or 0) <= 0 and state.chargeUntil == nil) then
		return
	end
	state.chargeStacks = nil
	state.chargeUntil = nil
	fireCombat(casterUserId)
end

local function liveCurse(targetUserId: number, casterUserId: number): number
	local state = combat[targetUserId]
	if not state or state.curseFrom ~= casterUserId or state.curseUntil == nil or now() >= state.curseUntil then
		return 0
	end
	return state.curseStacks or 0
end

local function clearCurse(targetUserId: number, casterUserId: number)
	local state = combat[targetUserId]
	local owner = if state then state.curseFrom else nil
	if state and (casterUserId == 0 or owner == casterUserId) then
		state.curseStacks = nil
		state.curseUntil = nil
		state.curseFrom = nil
		state.cursePer = nil
		state.curseTick = nil
		state.curseNext = nil
		fireCombat(targetUserId)
	end
	local echoId = if casterUserId ~= 0 then casterUserId else owner
	if echoId then
		local caster = combat[echoId]
		if caster and caster.curseEchoTarget == targetUserId then
			caster.curseEchoStacks = nil
			caster.curseEchoUntil = nil
			caster.curseEchoTarget = nil
			fireCombat(echoId)
		end
	end
end

local function gainCurse(targetUserId: number, casterUserId: number, cap: number, seconds: number, tickEvery: number, per: number)
	if cap <= 0 or seconds <= 0 or tickEvery <= 0 or per <= 0 then
		return
	end
	local state = combat[targetUserId]
	if not state or not state.alive then
		return
	end
	local current = if state.curseFrom == casterUserId and state.curseUntil ~= nil and now() < state.curseUntil
		then state.curseStacks or 0
		else 0
	state.curseStacks = ChampionKits.addCurse(current, cap)
	state.curseUntil = now() + seconds
	state.curseFrom = casterUserId
	state.cursePer = per
	state.curseTick = tickEvery
	if state.curseNext == nil or now() >= state.curseNext then
		state.curseNext = now() + tickEvery
	end
	fireCombat(targetUserId)
	local caster = combat[casterUserId]
	if caster and caster.alive then
		caster.curseEchoStacks = state.curseStacks
		caster.curseEchoUntil = state.curseUntil
		caster.curseEchoTarget = targetUserId
		fireCombat(casterUserId)
	end
end

local function livePsi(targetUserId: number, casterUserId: number): boolean
	local state = combat[targetUserId]
	return state ~= nil and state.psiFrom == casterUserId and state.psiUntil ~= nil and now() < state.psiUntil
end

local function clearPsi(targetUserId: number, casterUserId: number)
	local state = combat[targetUserId]
	if state and state.psiFrom == casterUserId then
		state.psiFrom = nil
		state.psiUntil = nil
		fireCombat(targetUserId)
	end
	local caster = combat[casterUserId]
	if caster and caster.psiTarget == targetUserId then
		caster.psiTarget = nil
		caster.psiUntil = nil
		fireCombat(casterUserId)
	end
end

local function gainPsi(targetUserId: number, casterUserId: number, seconds: number)
	if seconds <= 0 then
		return
	end
	local state = combat[targetUserId]
	if not state or not state.alive then
		return
	end
	local caster = combat[casterUserId]
	local previousId = if caster then caster.psiTarget else nil
	if previousId and previousId ~= targetUserId then
		local previous = combat[previousId]
		if previous and previous.psiFrom == casterUserId then
			previous.psiFrom = nil
			previous.psiUntil = nil
			fireCombat(previousId)
		end
	end
	state.psiFrom = casterUserId
	state.psiUntil = now() + seconds
	fireCombat(targetUserId)
	if caster and caster.alive then
		caster.psiTarget = targetUserId
		caster.psiUntil = state.psiUntil
		fireCombat(casterUserId)
	end
end

local function applyAuraGuard(
	targetUserId: number,
	seconds: number,
	reduction: number,
	championId: string,
	slot: Types.AbilitySlot
)
	if seconds <= 0 or reduction <= 0 then
		return
	end
	local state = combat[targetUserId]
	if not state or not state.alive then
		return
	end
	local active = state.guardUntil ~= nil and now() < state.guardUntil
	if not ChampionKits.preferGuard(state.guardReduction or 0, active, reduction) then
		return
	end
	state.guardUntil = now() + seconds
	state.guardReduction = reduction
	local root = rootOf(targetUserId)
	if root then
		FxRelay.emit({
			kind = "shield",
			origin = root.Position,
			userId = targetUserId,
			duration = seconds,
			championId = championId,
			slot = slot,
		})
	end
end

local function applyStrikes(ctx: StrikeCtx)
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot then
		return
	end
	local player = playerOf(ctx.caster)
	local kit = if ctx.championId and ctx.slot then ChampionKits.plan(ctx.championId, ctx.slot, ctx.stunSeconds) else nil
	local healAmount = ctx.healAmount
	if healAmount > 0 and ctx.championId then
		healAmount *= ChampionKits.healMultiplier(ctx.championId)
	end
	local shieldAmount = ctx.shieldAmount
	if kit and kit.wardAmp > 0 and ChampionKits.wardNear(allyWardDistance(ctx.team, ctx.origin), kit.wardRange) then
		local woven = ChampionKits.wardPower(kit.wardAmp)
		if healAmount > 0 then
			healAmount *= woven
		end
		if shieldAmount > 0 then
			shieldAmount *= woven
		end
	end
	if healAmount > 0 then
		local healed = false
		for _, otherMatch in snapshot.players do
			local otherRoot = rootOf(otherMatch.userId)
			if otherMatch.team == ctx.team and otherRoot then
				local selfCast = otherMatch.userId == ctx.caster and ctx.lastPos == nil
				if (pointHits(ctx, otherRoot.Position, 0) or selfCast) and consumeHit(ctx.hit, `h:{otherMatch.userId}`) then
					if kit and kit.auraGuardSeconds > 0 and ctx.championId and ctx.slot then
						applyAuraGuard(otherMatch.userId, kit.auraGuardSeconds, kit.auraGuardReduction, ctx.championId, ctx.slot)
					end
					healUser(otherMatch.userId, healAmount)
					healed = true
				end
			end
		end
		if healed and kit and kit.overclockPer > 0 then
			local stacks = liveData(ctx.caster)
			local plating = ChampionKits.overclockShield(stacks, kit.overclockPer)
			if plating > 0 then
				if not ctx.hit then
					ctx.hit = {}
				end
				if not ctx.hit["kit:overclock"] then
					ctx.hit["kit:overclock"] = true
					clearData(ctx.caster)
					shieldUser(ctx.caster, plating)
				end
			end
		end
	end
	if shieldAmount > 0 then
		for _, otherMatch in snapshot.players do
			local otherRoot = rootOf(otherMatch.userId)
			if otherMatch.team == ctx.team and otherRoot then
				local selfCast = otherMatch.userId == ctx.caster and ctx.lastPos == nil
				if (pointHits(ctx, otherRoot.Position, 0) or selfCast) and consumeHit(ctx.hit, `s:{otherMatch.userId}`) then
					shieldUser(otherMatch.userId, shieldAmount)
					if kit and kit.omenSeconds > 0 and kit.omenCut > 0 then
						applyOmen(otherMatch.userId, kit.omenSeconds, kit.omenCut)
					end
				end
			end
		end
	end
	local pullStuds = if kit and ctx.stunSeconds > 0 then kit.pullStuds else 0
	if ctx.stunSeconds > 0 then
		for _, otherMatch in snapshot.players do
			local otherRoot = rootOf(otherMatch.userId)
			if otherMatch.team ~= ctx.team and otherRoot then
				if pointHits(ctx, otherRoot.Position, 0) and consumeHit(ctx.hit, `t:{otherMatch.userId}`) then
					if pullStuds > 0 then
						local pulled = ChampionKits.pullPosition(otherRoot.Position, ctx.dest, pullStuds)
						otherRoot.CFrame = CFrame.new(pulled.X, otherRoot.Position.Y, pulled.Z)
					end
					stunUser(otherMatch.userId, ctx.stunSeconds)
				end
			end
		end
	end
	local refund = if ctx.championId and ctx.slot then ChampionKits.refundMana(ctx.championId, ctx.slot) else 0
	if ctx.power <= 0 then
		return
	end
	local hit = ctx.hit
	if not hit then
		hit = {}
		ctx.hit = hit
	end
	local wickStacks = if kit and kit.wickBonus > 0 then liveWick(ctx.caster) else 0
	local spentWick = false
	local vanishLive = kit ~= nil and kit.ambushSpend > 0 and liveVanish(ctx.caster)
	local spentAmbush = false
	local spentMark = false
	local plateStacks = if kit and kit.plateSpend > 0 then livePlate(ctx.caster) else 0
	local spentPlate = false
	local chargeStacks = if kit and kit.chargeSpend > 0 then liveCharge(ctx.caster) else 0
	local spentCharge = false
	local fromZone = ctx.fromZone == true
	for _, otherMatch in snapshot.players do
		local otherRoot = rootOf(otherMatch.userId)
		if otherMatch.team ~= ctx.team and otherRoot then
			if pointHits(ctx, otherRoot.Position, 0) and consumeHit(hit, `p:{otherMatch.userId}`) then
				if kit and kit.knockStuds > 0 then
					local knocked = ChampionKits.knockPosition(otherRoot.Position, ctx.origin, ctx.dest, kit.knockStuds)
					otherRoot.CFrame = CFrame.new(knocked.X, otherRoot.Position.Y, knocked.Z)
				end
				if kit and kit.knockStun > 0 then
					stunUser(otherMatch.userId, kit.knockStun)
				end
				local dealt = ctx.power
				if wickStacks > 0 and kit and kit.wickBonus > 0 then
					dealt = ctx.power * ChampionKits.wickPower(wickStacks, kit.wickBonus)
					spentWick = true
				end
				if kit and kit.bleedSpend > 0 then
					local stacks = liveBleed(otherMatch.userId, ctx.caster)
					if stacks > 0 then
						dealt *= ChampionKits.bleedPower(stacks, kit.bleedBonus)
						clearBleed(otherMatch.userId, ctx.caster)
					end
				elseif kit and kit.bleedBonus > 0 then
					local stacks = liveBleed(otherMatch.userId, ctx.caster)
					if stacks > 0 then
						dealt *= ChampionKits.bleedPower(stacks, kit.bleedBonus)
					end
				end
				if vanishLive and kit and kit.ambushSpend > 0 then
					local marked = liveMark(otherMatch.userId, ctx.caster)
					local markPart = if marked then kit.markBonus else 0
					dealt *= ChampionKits.ambushPower(kit.vanishBonus, markPart)
					spentAmbush = true
					if marked then
						clearMark(otherMatch.userId, ctx.caster)
						spentMark = true
					end
				end
				if plateStacks > 0 and kit and kit.plateSpend > 0 then
					dealt *= ChampionKits.platePower(plateStacks, kit.plateBonus)
					spentPlate = true
				end
				if chargeStacks > 0 and kit and kit.chargeSpend > 0 then
					dealt *= ChampionKits.chargePower(chargeStacks, kit.chargeBonus)
					spentCharge = true
				end
				if fromZone and kit and kit.hexBonus > 0 then
					local cursed = liveCurse(otherMatch.userId, ctx.caster)
					if cursed > 0 then
						dealt *= ChampionKits.hexPower(cursed, kit.hexBonus)
					end
				end
				local psiLive = kit ~= nil and (kit.psiBonus > 0 or kit.nudgeStuds > 0) and livePsi(otherMatch.userId, ctx.caster)
				if psiLive and kit and kit.psiBonus > 0 then
					local seen = VisionService.canSeeChampion(ctx.caster, otherMatch.userId)
					dealt *= ChampionKits.psiPower(kit.psiBonus, seen)
				end
				if psiLive and kit and kit.nudgeStuds > 0 then
					local nudged = ChampionKits.pullPosition(otherRoot.Position, ctx.origin, kit.nudgeStuds)
					otherRoot.CFrame = CFrame.new(nudged.X, otherRoot.Position.Y, nudged.Z)
				end
				damageUser(ctx.caster, otherMatch.userId, dealt)
				if psiLive and kit and kit.nudgeStuds > 0 then
					clearPsi(otherMatch.userId, ctx.caster)
				end
				if kit and kit.wickGain > 0 and not hit["kit:wick"] then
					hit["kit:wick"] = true
					gainWick(ctx.caster, kit.wickCap, kit.wickSeconds)
				end
				if kit and kit.dataGain > 0 and not hit["kit:data"] then
					hit["kit:data"] = true
					gainData(ctx.caster, kit.dataCap, kit.dataSeconds)
				end
				if kit and kit.bleedGain > 0 then
					gainBleed(otherMatch.userId, ctx.caster, kit.bleedCap, kit.bleedSeconds)
				end
				if kit and kit.plateGain > 0 and not hit["kit:plate"] then
					hit["kit:plate"] = true
					gainPlate(ctx.caster, kit.plateCap, kit.plateSeconds, kit.platePer)
				end
				if kit and kit.chargeGain > 0 and not hit["kit:charge"] then
					hit["kit:charge"] = true
					gainCharge(ctx.caster, kit.chargeCap, kit.chargeSeconds)
				end
				if kit and kit.curseGain > 0 then
					gainCurse(otherMatch.userId, ctx.caster, kit.curseCap, kit.curseSeconds, kit.curseTick, kit.cursePer)
				end
				if kit and kit.psiGain > 0 and not hit["kit:psi"] then
					hit["kit:psi"] = true
					gainPsi(otherMatch.userId, ctx.caster, kit.psiSeconds)
				end
				if kit and kit.fortifySeconds > 0 and ctx.championId and ctx.slot and not hit["kit:fortify"] then
					hit["kit:fortify"] = true
					applyFortify(ctx.caster, kit.fortifySeconds, kit.fortifyReduction, ctx.championId, ctx.slot)
				end
				if
					kit
					and ChampionKits.marksFromBrush(kit.markGain, ctx.fromBrush == true)
					and not spentMark
					and not hit["kit:mark"]
				then
					hit["kit:mark"] = true
					gainMark(otherMatch.userId, ctx.caster, kit.markSeconds)
				end
				if refund > 0 and not hit["kit:refund"] then
					hit["kit:refund"] = true
					local casterState = combat[ctx.caster]
					if casterState and casterState.alive then
						casterState.mana = math.min(casterState.maxMana, casterState.mana + refund)
						fireCombat(ctx.caster)
					end
				end
			end
		end
	end
	if spentWick then
		clearWick(ctx.caster)
	end
	if spentAmbush then
		clearVanish(ctx.caster)
	end
	if spentPlate and kit and ctx.slot then
		local refundSeconds = ChampionKits.plateRefund(plateStacks, kit.plateReload)
		clearPlate(ctx.caster)
		shortenCooldown(ctx.caster, ctx.slot, refundSeconds)
	end
	if spentCharge then
		clearCharge(ctx.caster)
	end
	local minionHit = false
	for _, minion in MinionService.list() do
		if minion.team ~= ctx.team then
			if pointHits(ctx, minion.part.Position, Config.Minions.HitRadius) and consumeHit(ctx.hit, `m:{minion.id}`) then
				minionHit = true
				MinionService.applyDamage(ctx.caster, minion.id, ctx.power)
			end
		end
	end
	if minionHit then
		local foeTeam: Types.TeamId = if ctx.team == "Blue" then "Red" else "Blue"
		TowerService.noteThreat(ctx.caster, foeTeam)
	end
	for _, monster in JungleService.list() do
		if pointHits(ctx, monster.part.Position, Config.Minions.HitRadius) and consumeHit(ctx.hit, `j:{monster.id}`) then
			JungleService.applyDamage(ctx.caster, monster.id, ctx.power)
		end
	end
	for _, ward in WardService.list() do
		if ward.team ~= ctx.team then
			if pointHits(ctx, ward.part.Position, 2) and consumeHit(ctx.hit, `w:{ward.id}`) then
				WardService.applyDamage(player, ward.id, ctx.power)
			end
		end
	end
	local map = MapBuilder.get()
	local objectives = map:FindFirstChild("Objectives")
	if objectives then
		for _, child in objectives:GetChildren() do
			if child:IsA("BasePart") then
				local team = child:GetAttribute(Constants.Attributes.Team)
				local objId = child:GetAttribute(Constants.Attributes.ObjectiveId)
				local key = if typeof(objId) == "string" then `o:{objId}` else `o:{child.Name}`
				if team ~= ctx.team and pointHits(ctx, child.Position, Config.Combat.StructureTouchRadius) and consumeHit(ctx.hit, key) then
					damageObjective(ctx.caster, child, ctx.power)
					if team == "Blue" or team == "Red" then
						TowerService.noteThreat(ctx.caster, team)
					end
				end
			end
		end
	end
end

local function launchShot(
	caster: number,
	team: Types.TeamId,
	origin: Vector3,
	dest: Vector3,
	radius: number,
	power: number,
	healAmount: number,
	shieldAmount: number,
	stunSeconds: number,
	kind: Types.AbilityKind,
	championId: string,
	slot: Types.AbilitySlot,
	fromBrush: boolean?
)
	while #shots >= ProjectileLogic.MaxLive do
		local old = table.remove(shots, 1)
		if old then
			applyStrikes({
				caster = old.caster,
				team = old.team,
				mode = "line",
				origin = old.origin,
				dest = old.dest,
				lastPos = old.lastPos,
				pos = old.dest,
				radius = old.radius,
				power = old.power,
				healAmount = old.healAmount,
				shieldAmount = old.shieldAmount,
				stunSeconds = old.stunSeconds,
				hit = old.hit,
				championId = old.championId,
				slot = old.slot,
				fromBrush = old.fromBrush,
			})
		end
	end
	nextShotId += 1
	local duration = ProjectileLogic.travelSeconds(origin, dest, Config.Combat.ProjectileSpeed)
	local shot: Shot = {
		id = nextShotId,
		caster = caster,
		team = team,
		origin = origin,
		dest = dest,
		speed = Config.Combat.ProjectileSpeed,
		radius = radius,
		power = power,
		healAmount = healAmount,
		shieldAmount = shieldAmount,
		stunSeconds = stunSeconds,
		kind = kind,
		championId = championId,
		slot = slot,
		born = now(),
		duration = duration,
		lastPos = origin,
		hit = {},
		fromBrush = fromBrush == true,
	}
	table.insert(shots, shot)
	FxRelay.emit({
		kind = "projectile",
		origin = origin,
		dest = dest,
		userId = caster,
		team = team,
		mode = "line",
		abilityKind = kind,
		radius = radius,
		duration = duration,
		speed = Config.Combat.ProjectileSpeed,
		id = shot.id,
		championId = championId,
		slot = slot,
	})
end

tickShots = function()
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot or snapshot.phase ~= "InProgress" then
		if #shots > 0 then
			table.clear(shots)
		end
		if #zones > 0 then
			table.clear(zones)
		end
		return
	end
	local t = now()
	local keep: { Shot } = {}
	for _, shot in shots do
		local elapsed = t - shot.born
		local pos = ProjectileLogic.positionAt(shot.origin, shot.dest, elapsed, shot.duration)
		applyStrikes({
			caster = shot.caster,
			team = shot.team,
			mode = "line",
			origin = shot.origin,
			dest = shot.dest,
			lastPos = shot.lastPos,
			pos = pos,
			radius = shot.radius,
			power = shot.power,
			healAmount = shot.healAmount,
			shieldAmount = shot.shieldAmount,
			stunSeconds = shot.stunSeconds,
			hit = shot.hit,
			championId = shot.championId,
			slot = shot.slot,
			fromBrush = shot.fromBrush,
		})
		shot.lastPos = pos
		if elapsed >= shot.duration then
			FxRelay.emit({
				kind = "projectileHit",
				origin = shot.dest,
				dest = shot.dest,
				userId = shot.caster,
				team = shot.team,
				abilityKind = shot.kind,
				radius = shot.radius,
				championId = shot.championId,
				slot = shot.slot,
			})
		else
			table.insert(keep, shot)
		end
	end
	shots = keep

	local zoneKeep: { Zone } = {}
	for _, zone in zones do
		if zone.pulsesLeft > 0 and t >= zone.nextAt and t <= zone.expires + 0.05 then
			applyStrikes({
				caster = zone.caster,
				team = zone.team,
				mode = "ground",
				origin = zone.pos,
				dest = zone.pos,
				radius = zone.radius,
				power = zone.power,
				healAmount = zone.healAmount,
				shieldAmount = zone.shieldAmount,
				stunSeconds = zone.stunSeconds,
				hit = {},
				championId = zone.championId,
				slot = zone.slot,
				fromZone = true,
			})
			zone.pulsesLeft -= 1
			zone.nextAt = t + zone.tick
		end
		if zone.pulsesLeft > 0 and t < zone.expires then
			table.insert(zoneKeep, zone)
		end
	end
	zones = zoneKeep

	local cursedIds: { number } = {}
	for userId, state in combat do
		if state.curseUntil ~= nil then
			table.insert(cursedIds, userId)
		end
	end
	for _, userId in cursedIds do
		local state = combat[userId]
		if state and state.curseUntil ~= nil and state.alive then
			local due = (state.curseStacks or 0) > 0
				and (state.curseNext == nil or t >= state.curseNext)
				and t <= state.curseUntil + 0.05
			if due then
				local tickEvery = if (state.curseTick or 0) > 0 then state.curseTick :: number else 1
				state.curseNext = t + tickEvery
				local dot = ChampionKits.curseDamage(state.curseStacks or 0, state.cursePer or 0)
				local owner = state.curseFrom
				if dot > 0 and owner then
					damageUser(owner, userId, dot)
				end
			end
		end
		local still = combat[userId]
		if still and still.curseUntil ~= nil and (not still.alive or t >= still.curseUntil) then
			clearCurse(userId, still.curseFrom or 0)
		end
	end
end

local function setChannelingFlag(userId: number, on: boolean)
	local player = playerOf(userId)
	if not player then
		return
	end
	if on then
		player:SetAttribute(Constants.Attributes.Channeling, true)
	else
		player:SetAttribute(Constants.Attributes.Channeling, nil)
	end
end

local function restoreMovement(userId: number)
	local state = combat[userId]
	if not state or not state.alive or state.recalling then
		return
	end
	local player = playerOf(userId)
	if player then
		ShopService.applyMovement(player)
	else
		ShopService.applyMovementToModel(modelOf(userId), userId)
	end
end

local function clearChannelState(userId: number)
	local state = combat[userId]
	if state then
		state.channelSlot = nil
		state.channelEndsAt = nil
		state.channelStartedAt = nil
	end
	channelOrigin[userId] = nil
	setChannelingFlag(userId, false)
end

interruptChannel = function(userId: number, reason: string)
	local pending = channels[userId]
	if not pending then
		return
	end
	channels[userId] = nil
	channelToken[userId] = (channelToken[userId] or 0) + 1
	local state = combat[userId]
	if state and reason ~= "death" and state.alive then
		state.cooldowns[pending.slot] = now() + pending.interruptCooldown
		if pending.interruptMana > 0 then
			state.mana = math.min(state.maxMana, state.mana + pending.interruptMana)
		end
	end
	clearChannelState(userId)
	if reason ~= "death" then
		restoreMovement(userId)
	end
	fireCombat(userId)
	FxRelay.emit({
		kind = "ability",
		origin = pending.origin,
		dest = pending.dest,
		userId = userId,
		team = pending.team,
		mode = "line",
		abilityKind = pending.kind,
		radius = pending.radius,
		duration = 0,
		championId = pending.championId,
		slot = pending.slot,
	})
end

completeChannel = function(userId: number, token: number)
	if channelToken[userId] ~= token then
		return
	end
	local pending = channels[userId]
	if not pending then
		return
	end
	channels[userId] = nil
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	local state = combat[userId]
	clearChannelState(userId)
	if not snapshot or snapshot.phase ~= "InProgress" or not state or not state.alive then
		fireCombat(userId)
		return
	end
	restoreMovement(userId)
	local travel = ProjectileLogic.travelSeconds(pending.origin, pending.dest, Config.Combat.ProjectileSpeed)
	if abilityCastListener then
		abilityCastListener({
			userId = userId,
			team = pending.team,
			mode = "line",
			kind = pending.kind,
			origin = pending.origin,
			dest = pending.dest,
			radius = pending.radius,
			travel = travel,
		})
	end
	launchShot(
		userId,
		pending.team,
		pending.origin,
		pending.dest,
		pending.radius,
		pending.power,
		pending.healAmount,
		pending.shieldAmount,
		pending.stunSeconds,
		pending.kind,
		pending.championId,
		pending.slot
	)
	fireCombat(userId)
end

local function beginChannel(
	userId: number,
	team: Types.TeamId,
	championId: string,
	slot: Types.AbilitySlot,
	origin: Vector3,
	dest: Vector3,
	radius: number,
	power: number,
	healAmount: number,
	shieldAmount: number,
	stunSeconds: number,
	kind: Types.AbilityKind,
	seconds: number,
	interruptCooldown: number,
	interruptMana: number
)
	local token = (channelToken[userId] or 0) + 1
	channelToken[userId] = token
	local started = now()
	channels[userId] = {
		token = token,
		userId = userId,
		team = team,
		championId = championId,
		slot = slot,
		origin = origin,
		dest = dest,
		radius = radius,
		power = power,
		healAmount = healAmount,
		shieldAmount = shieldAmount,
		stunSeconds = stunSeconds,
		kind = kind,
		interruptCooldown = interruptCooldown,
		interruptMana = interruptMana,
	}
	channelOrigin[userId] = origin
	locks[userId] = nil
	local state = combat[userId]
	if state then
		state.channelSlot = slot
		state.channelStartedAt = started
		state.channelEndsAt = started + seconds
		state.attackTarget = nil
	end
	setChannelingFlag(userId, true)
	local model = modelOf(userId)
	local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
	fireCombat(userId)
	FxRelay.emit({
		kind = "ability",
		origin = origin,
		dest = dest,
		userId = userId,
		team = team,
		mode = "line",
		abilityKind = kind,
		radius = radius,
		duration = seconds,
		championId = championId,
		slot = slot,
	})
	task.delay(seconds, function()
		completeChannel(userId, token)
	end)
end

local function scheduleZone(
	caster: number,
	team: Types.TeamId,
	championId: string,
	slot: Types.AbilitySlot,
	pos: Vector3,
	radius: number,
	power: number,
	healAmount: number,
	shieldAmount: number,
	stunSeconds: number,
	kind: Types.AbilityKind,
	seconds: number,
	tickEvery: number,
	pulses: number
)
	local remain = pulses - 1
	if remain <= 0 then
		return 0
	end
	nextZoneId += 1
	local t = now()
	local zone: Zone = {
		id = nextZoneId,
		caster = caster,
		team = team,
		championId = championId,
		slot = slot,
		pos = pos,
		radius = radius,
		power = power,
		healAmount = healAmount,
		shieldAmount = shieldAmount,
		stunSeconds = stunSeconds,
		kind = kind,
		pulsesLeft = remain,
		nextAt = t + tickEvery,
		tick = tickEvery,
		expires = t + seconds,
	}
	table.insert(zones, zone)
	while #zones > 8 do
		table.remove(zones, 1)
	end
	return zone.id
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

	local pending = channels[userId]
	if pending then
		if pending.slot == slot then
			interruptChannel(userId, "ability")
			return { ok = true, combat = state }
		end
		interruptChannel(userId, "ability")
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

	breakRecall(playerOf(userId), "ability")
	state.mana -= ability.manaCost
	state.cooldowns[slot] = t + ability.cooldown
	local scale = Progression.rankScale(rank)
	local ap = state.abilityPower or 0
	local power = 0
	if ability.damage > 0 then
		power = (ability.damage * scale + (state.bonusDamage or 0) + ap * 0.35) * (outgoingAmp[userId] or 1)
	end
	local healAmount = if ability.heal > 0 then ability.heal * scale + ap * 0.25 else 0
	local shieldAmount = if (ability.shield or 0) > 0 then (ability.shield or 0) * scale + ap * 0.2 else 0
	local stunSeconds = ability.stunSeconds or 0
	local kit = ChampionKits.plan(champ.id, slot, stunSeconds)
	local fromBrush = VisionLogic.brushAt(origin.X, origin.Z) ~= nil
	local travel = if mode == "line" and kit.channelSeconds <= 0
		then ProjectileLogic.travelSeconds(origin, dest, Config.Combat.ProjectileSpeed)
		else nil
	-- Notify before hits resolve so bots can sidestep this cast (and lead using travel time).
	-- A channeled line notifies when the bolt actually leaves, so the windup can still be broken.
	if abilityCastListener and kit.channelSeconds <= 0 and (mode == "line" or mode == "ground") then
		abilityCastListener({
			userId = userId,
			team = matchPlayer.team,
			mode = mode,
			kind = ability.kind,
			origin = origin,
			dest = dest,
			radius = ability.radius,
			travel = travel,
		})
	end

	if kit.channelSeconds > 0 then
		beginChannel(
			userId,
			matchPlayer.team,
			champ.id,
			slot,
			origin,
			dest,
			ability.radius,
			power,
			healAmount,
			shieldAmount,
			stunSeconds,
			ability.kind,
			kit.channelSeconds,
			kit.interruptCooldown,
			kit.interruptMana
		)
		state.trinketReadyAt = WardService.trinketReadyAt(userId)
		state.lensReadyAt = WardService.lensReadyAt(userId)
		return { ok = true, combat = state }
	end

	if mode == "dash" then
		local dash = Targeting.flat(origin, dest)
		if dash.Magnitude > 1 then
			root.CFrame = CFrame.new(dest.X, root.Position.Y, dest.Z)
		end
	end

	local strikePower = power
	local zoneId = 0
	local zoneSeconds = 0
	if kit.zonePulses > 1 then
		strikePower = ChampionKits.pulsePower(power, kit.zonePulses)
		zoneSeconds = kit.zoneSeconds
		applyStrikes({
			caster = userId,
			team = matchPlayer.team,
			mode = mode,
			origin = origin,
			dest = dest,
			radius = ability.radius,
			power = strikePower,
			healAmount = healAmount,
			shieldAmount = shieldAmount,
			stunSeconds = stunSeconds,
			championId = champ.id,
			slot = slot,
			fromBrush = fromBrush,
		})
		zoneId = scheduleZone(
			userId,
			matchPlayer.team,
			champ.id,
			slot,
			dest,
			ability.radius,
			strikePower,
			0,
			0,
			stunSeconds,
			ability.kind,
			kit.zoneSeconds,
			kit.zoneTick,
			kit.zonePulses
		)
	elseif mode == "line" then
		launchShot(
			userId,
			matchPlayer.team,
			origin,
			dest,
			ability.radius,
			power,
			healAmount,
			shieldAmount,
			stunSeconds,
			ability.kind,
			champ.id,
			slot,
			fromBrush
		)
	else
		applyStrikes({
			caster = userId,
			team = matchPlayer.team,
			mode = mode,
			origin = origin,
			dest = dest,
			radius = ability.radius,
			power = power,
			healAmount = healAmount,
			shieldAmount = shieldAmount,
			stunSeconds = stunSeconds,
			hit = {},
			championId = champ.id,
			slot = slot,
			fromBrush = fromBrush,
		})
	end

	if kit.hexPulses > 1 and kit.hexShare > 0 and power > 0 then
		zoneSeconds = kit.hexSeconds
		zoneId = scheduleZone(
			userId,
			matchPlayer.team,
			champ.id,
			slot,
			dest,
			ability.radius,
			power * kit.hexShare,
			0,
			0,
			0,
			ability.kind,
			kit.hexSeconds,
			kit.hexTick,
			kit.hexPulses + 1
		)
	end

	if kit.vanishSeconds > 0 then
		state.vanishUntil = t + kit.vanishSeconds
	end

	if kit.guardSeconds > 0 then
		state.guardUntil = t + kit.guardSeconds
		state.guardReduction = kit.guardReduction
		FxRelay.emit({
			kind = "shield",
			origin = origin,
			userId = userId,
			team = matchPlayer.team,
			duration = kit.guardSeconds,
			championId = champ.id,
			slot = slot,
		})
	end

	state.trinketReadyAt = WardService.trinketReadyAt(userId)
	state.lensReadyAt = WardService.lensReadyAt(userId)
	fireCombat(userId)
	if mode ~= "line" then
		FxRelay.emit({
			kind = "ability",
			origin = origin,
			dest = dest,
			userId = userId,
			team = matchPlayer.team,
			mode = mode,
			abilityKind = ability.kind,
			radius = ability.radius,
			duration = if zoneSeconds > 0 then zoneSeconds else nil,
			id = if zoneId > 0 then zoneId else nil,
			championId = champ.id,
			slot = slot,
		})
	end
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
	breakRecall(player, "ward")
	interruptChannel(player.UserId, "ward")
	local result = WardService.placeTrinket(player, matchPlayer.team, position :: Vector3)
	state.trinketReadyAt = WardService.trinketReadyAt(player.UserId)
	state.lensReadyAt = WardService.lensReadyAt(player.UserId)
	result.combat = state
	Remotes.event("CombatUpdated"):FireClient(player, state)
	return result
end

function CombatService.placeControl(player: Player, position: unknown): Types.AbilityResult
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
	breakRecall(player, "control")
	interruptChannel(player.UserId, "control")
	local result = WardService.placeControl(player, matchPlayer.team, position :: Vector3)
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
	breakRecall(playerOf(userId), "lens")
	interruptChannel(userId, "lens")
	local player = playerOf(userId)
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

function CombatService.useCleaveFor(userId: number): Types.AbilityResult
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot or snapshot.phase ~= "InProgress" then
		return { ok = false, error = "Match is not in progress." }
	end
	local matchPlayer = snapshot.players[tostring(userId)]
	local state = combat[userId]
	if not matchPlayer or not state or not state.alive then
		return { ok = false, error = "You are down. Wait for respawn." }
	end
	if not ShopService.has(userId, ItemKits.CleaveId) then
		return { ok = false, error = "Buy Yarn Cleave at Pawmart." }
	end
	local t = now()
	if not ItemKits.cleaveReady(t, state.cleaveReadyAt) then
		return { ok = false, error = "Yarn Cleave is cooling down." }
	end
	local root = rootOf(userId)
	if not root then
		return { ok = false, error = "No character." }
	end
	local player = playerOf(userId)
	breakRecall(player, "cleave")
	interruptChannel(userId, "cleave")
	state.cleaveReadyAt = ItemKits.cleaveReadyAt(t)
	for _, otherMatch in snapshot.players do
		if otherMatch.team ~= matchPlayer.team and otherMatch.userId ~= userId then
			local otherRoot = rootOf(otherMatch.userId)
			local otherState = combat[otherMatch.userId]
			if otherRoot and otherState and otherState.alive and ItemKits.inCleave(root.Position, otherRoot.Position) then
				if VisionService.canSeeChampion(userId, otherMatch.userId) then
					damageUser(userId, otherMatch.userId, ItemKits.CLEAVE_DAMAGE)
				end
			end
		end
	end
	for _, minion in MinionService.list() do
		if minion.team ~= matchPlayer.team and minion.health > 0 and minion.part.Parent then
			if ItemKits.inCleave(root.Position, minion.part.Position) and VisionService.canSeeMinion(userId, minion.id) then
				MinionService.applyDamage(userId, minion.id, ItemKits.CLEAVE_DAMAGE)
			end
		end
	end
	FxRelay.emit({
		kind = "cleave",
		origin = root.Position,
		userId = userId,
		radius = ItemKits.CLEAVE_RADIUS,
	})
	state.trinketReadyAt = WardService.trinketReadyAt(userId)
	state.lensReadyAt = WardService.lensReadyAt(userId)
	fireCombat(userId)
	return { ok = true, combat = state }
end

function CombatService.useCleave(player: Player): Types.AbilityResult
	return CombatService.useCleaveFor(player.UserId)
end

return CombatService
