--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local MinionService = require(script.Parent.MinionService)
local ShopService = require(script.Parent.ShopService)
local TowerService = require(script.Parent.TowerService)
local VisionService = require(script.Parent.VisionService)

type MatchApi = {
	getSnapshot: () -> Types.MatchSnapshot?,
	onPlayerKilled: (killer: Player, victim: Player, assists: { Player }) -> (),
	onObjectiveDestroyed: (attacker: Player?, objective: Types.ObjectiveState) -> (),
	addGold: (player: Player, amount: number) -> (),
}

type AttackLock = {
	kind: "player" | "minion" | "objective",
	userId: number?,
	minionId: string?,
	objectiveId: string?,
	moveTo: Vector3?,
	windupEnds: number?,
}

local CombatService = {}

local combat: { [number]: Types.CombatState } = {}
local locks: { [number]: AttackLock } = {}
local nextAA: { [number]: number } = {}
local recentHits: { [number]: { [number]: number } } = {}
local matchApi: MatchApi? = nil
local tickAutoAttack: (player: Player) -> ()

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function emptyCooldowns(): { [Types.AbilitySlot]: number }
	return { Q = 0, W = 0, E = 0, R = 0 }
end

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function applyHumanoid(player: Player, state: Types.CombatState)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = state.maxHealth
		humanoid.Health = math.max(1, state.health)
	end
end

function CombatService.characterRoot(player: Player): BasePart?
	return characterRoot(player)
end

function CombatService.get(userId: number): Types.CombatState?
	return combat[userId]
end

function CombatService.reset(player: Player, championId: string)
	local champ = ChampionCatalog.get(championId) or ChampionCatalog.get(ChampionCatalog.defaultId())
	if not champ then
		return
	end
	local bonuses = ShopService.bonuses(player.UserId)
	local state: Types.CombatState = {
		health = champ.maxHealth + bonuses.maxHealth,
		maxHealth = champ.maxHealth + bonuses.maxHealth,
		mana = champ.maxMana + bonuses.maxMana,
		maxMana = champ.maxMana + bonuses.maxMana,
		shield = 0,
		bonusDamage = bonuses.bonusDamage,
		armor = bonuses.armor,
		cooldowns = emptyCooldowns(),
		alive = true,
		nextAutoAttack = 0,
		attackTarget = nil,
	}
	combat[player.UserId] = state
	locks[player.UserId] = nil
	nextAA[player.UserId] = 0
	player:SetAttribute(Constants.Attributes.ChampionId, champ.id)
	applyHumanoid(player, state)
	ShopService.applyMovement(player)
	Remotes.event("CombatUpdated"):FireClient(player, state)
end

function CombatService.reapplyItems(player: Player)
	local state = combat[player.UserId]
	local champId = player:GetAttribute(Constants.Attributes.ChampionId)
	if not state or typeof(champId) ~= "string" then
		return
	end
	local champ = ChampionCatalog.get(champId)
	if not champ then
		return
	end
	local bonuses = ShopService.bonuses(player.UserId)
	local healthRatio = if state.maxHealth > 0 then state.health / state.maxHealth else 1
	local manaRatio = if state.maxMana > 0 then state.mana / state.maxMana else 1
	state.maxHealth = champ.maxHealth + bonuses.maxHealth
	state.maxMana = champ.maxMana + bonuses.maxMana
	state.health = math.clamp(state.maxHealth * healthRatio, 1, state.maxHealth)
	state.mana = math.clamp(state.maxMana * manaRatio, 0, state.maxMana)
	state.bonusDamage = bonuses.bonusDamage
	state.armor = bonuses.armor
	applyHumanoid(player, state)
	ShopService.applyMovement(player)
	Remotes.event("CombatUpdated"):FireClient(player, state)
end

function CombatService.clear(userId: number)
	combat[userId] = nil
	locks[userId] = nil
	nextAA[userId] = nil
	recentHits[userId] = nil
end

function CombatService.clearAll()
	table.clear(combat)
	table.clear(locks)
	table.clear(nextAA)
	table.clear(recentHits)
end

function CombatService.init(api: MatchApi)
	matchApi = api

	Players.PlayerRemoving:Connect(function(player)
		CombatService.clear(player.UserId)
	end)

	local function hookCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				local snapshot = if matchApi then matchApi.getSnapshot() else nil
				if not snapshot or snapshot.phase ~= "InProgress" then
					return
				end
				local matchPlayer = snapshot.players[tostring(player.UserId)]
				if matchPlayer and matchPlayer.championId then
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
			for _, player in Players:GetPlayers() do
				local state = combat[player.UserId]
				if state and state.alive then
					state.health = math.min(state.maxHealth, state.health + Config.Combat.RegenPerSecond)
					state.mana = math.min(state.maxMana, state.mana + Config.Combat.ManaRegenPerSecond)
					applyHumanoid(player, state)
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
			for _, player in Players:GetPlayers() do
				if locks[player.UserId] then
					tickAutoAttack(player)
				end
			end
		end
	end)
end

local function killPlayer(victim: Player, killer: Player?)
	local state = combat[victim.UserId]
	if not state or not state.alive then
		return
	end
	state.alive = false
	state.health = 0
	Remotes.event("CombatUpdated"):FireClient(victim, state)

	local character = victim.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end

	if killer and matchApi then
		local assists: { Player } = {}
		local snapshot = matchApi.getSnapshot()
		local bag = recentHits[victim.UserId]
		recentHits[victim.UserId] = nil
		if snapshot and bag then
			local killerMatch = snapshot.players[tostring(killer.UserId)]
			local t = now()
			for userId, at in bag do
				if userId ~= killer.UserId and t - at <= Config.Match.AssistWindow then
					local other = Players:GetPlayerByUserId(userId)
					local otherMatch = snapshot.players[tostring(userId)]
					if other and killerMatch and otherMatch and otherMatch.team == killerMatch.team then
						table.insert(assists, other)
					end
				end
			end
		end
		matchApi.onPlayerKilled(killer, victim, assists)
	end
end

local function noteAssist(attacker: Player, victim: Player)
	local bag = recentHits[victim.UserId]
	if not bag then
		bag = {}
		recentHits[victim.UserId] = bag
	end
	bag[attacker.UserId] = now()
end

local function damagePlayer(attacker: Player?, target: Player, amount: number)
	if attacker and attacker == target then
		return
	end
	local state = combat[target.UserId]
	if not state or not state.alive then
		return
	end
	local reduced = amount * (1 - (state.armor or 0))
	local remaining = reduced
	if (state.shield or 0) > 0 then
		local absorbed = math.min(state.shield, remaining)
		state.shield -= absorbed
		remaining -= absorbed
	end
	if remaining > 0 then
		state.health = math.max(0, state.health - remaining)
	end
	applyHumanoid(target, state)
	Remotes.event("CombatUpdated"):FireClient(target, state)
	if attacker and matchApi then
		noteAssist(attacker, target)
		local snapshot = matchApi.getSnapshot()
		local victim = if snapshot then snapshot.players[tostring(target.UserId)] else nil
		if victim then
			TowerService.noteThreat(attacker, victim.team)
		end
	end
	if state.health <= 0 then
		killPlayer(target, attacker)
	end
end

function CombatService.applyDamageToPlayer(target: Player, amount: number)
	damagePlayer(nil, target, amount)
end

function CombatService.damagePlayersNear(attackerTeam: Types.TeamId, position: Vector3, range: number, amount: number)
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot then
		return
	end
	for _, other in Players:GetPlayers() do
		local otherMatch = snapshot.players[tostring(other.UserId)]
		local otherRoot = characterRoot(other)
		if otherMatch and otherMatch.team ~= attackerTeam and otherRoot then
			if (otherRoot.Position - position).Magnitude <= range then
				damagePlayer(nil, other, amount)
			end
		end
	end
end

local function shieldPlayer(target: Player, amount: number)
	local state = combat[target.UserId]
	if not state or not state.alive or amount <= 0 then
		return
	end
	state.shield = math.min(state.maxHealth, state.shield + amount)
	Remotes.event("CombatUpdated"):FireClient(target, state)
end

local function stunPlayer(target: Player, seconds: number)
	if seconds <= 0 then
		return
	end
	local character = target.Character
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
	task.delay(seconds, function()
		if humanoid.Parent and humanoid:GetAttribute("MeoStunToken") == token then
			humanoid.WalkSpeed = walk
			humanoid.JumpPower = jump
		end
	end)
end

local function healPlayer(target: Player, amount: number)
	local state = combat[target.UserId]
	if not state or not state.alive then
		return
	end
	state.health = math.min(state.maxHealth, state.health + amount)
	applyHumanoid(target, state)
	Remotes.event("CombatUpdated"):FireClient(target, state)
end

local function damageObjective(attacker: Player?, part: BasePart, amount: number)
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
				if attacker then
					matchApi.addGold(attacker, Config.Match.TowerGold)
				end
				-- Minions can melt a tower/nexus; the match still has to resolve.
				matchApi.onObjectiveDestroyed(attacker, objective)
				MapBuilder.refreshNexusGate()
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

local function aaDamage(player: Player): number
	local state = combat[player.UserId]
	return Config.AutoAttack.BaseDamage + if state then (state.bonusDamage or 0) else 0
end

local function pushCombat(player: Player)
	local state = combat[player.UserId]
	if not state then
		return
	end
	state.nextAutoAttack = nextAA[player.UserId] or 0
	local lock = locks[player.UserId]
	if lock then
		if lock.kind == "player" and lock.userId then
			local other = Players:GetPlayerByUserId(lock.userId)
			state.attackTarget = if other then other.DisplayName else "champion"
		elseif lock.kind == "minion" then
			state.attackTarget = "kitten"
		elseif lock.kind == "objective" then
			state.attackTarget = lock.objectiveId or "structure"
		end
	else
		state.attackTarget = nil
	end
	Remotes.event("CombatUpdated"):FireClient(player, state)
end

local function walkToward(player: Player, dest: Vector3)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:MoveTo(Vector3.new(dest.X, dest.Y, dest.Z))
	end
end

local function resolveTarget(lock: AttackLock): (Vector3?, string?)
	if lock.kind == "player" and lock.userId then
		local other = Players:GetPlayerByUserId(lock.userId)
		if not other then
			return nil, "gone"
		end
		local otherState = combat[other.UserId]
		if not otherState or not otherState.alive then
			return nil, "dead"
		end
		local root = characterRoot(other)
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
	end
	return nil, "gone"
end

local function visibleTo(player: Player, lock: AttackLock): boolean
	if lock.kind == "objective" then
		return true
	end
	if lock.kind == "player" and lock.userId then
		local other = Players:GetPlayerByUserId(lock.userId)
		return other ~= nil and VisionService.canSeePlayer(player, other)
	end
	if lock.kind == "minion" and lock.minionId then
		return VisionService.canSeeMinion(player, lock.minionId)
	end
	return false
end

local function strike(player: Player, lock: AttackLock)
	local power = aaDamage(player)
	if lock.kind == "player" and lock.userId then
		local other = Players:GetPlayerByUserId(lock.userId)
		if other then
			damagePlayer(player, other, power)
		end
	elseif lock.kind == "minion" and lock.minionId then
		local minion = MinionService.get(lock.minionId)
		if minion then
			TowerService.noteThreat(player, minion.team)
			MinionService.applyDamage(player, minion.id, power)
		end
	elseif lock.kind == "objective" and lock.objectiveId then
		local part = MapBuilder.getObjectivePart(lock.objectiveId)
		if part then
			local team = part:GetAttribute(Constants.Attributes.Team)
			if team == "Blue" or team == "Red" then
				TowerService.noteThreat(player, team)
			end
			damageObjective(player, part, power)
		end
	end
end

local function acquireNear(player: Player, team: Types.TeamId, origin: Vector3): AttackLock?
	local best: AttackLock? = nil
	local bestDist = Config.AutoAttack.AcquireRange
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot then
		return nil
	end
	for _, other in Players:GetPlayers() do
		local otherMatch = snapshot.players[tostring(other.UserId)]
		local otherRoot = characterRoot(other)
		local otherState = combat[other.UserId]
		if otherMatch and otherMatch.team ~= team and otherRoot and otherState and otherState.alive then
			local d = (otherRoot.Position - origin).Magnitude
			if d <= bestDist and VisionService.canSeePlayer(player, other) then
				best = { kind = "player", userId = other.UserId }
				bestDist = d
			end
		end
	end
	for _, minion in MinionService.list() do
		if minion.team ~= team then
			local d = (minion.part.Position - origin).Magnitude
			if d <= bestDist and VisionService.canSeeMinion(player, minion.id) then
				best = { kind = "minion", minionId = minion.id }
				bestDist = d
			end
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
	return best
end

tickAutoAttack = function(player: Player)
	local state = combat[player.UserId]
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not state or not state.alive or not snapshot or snapshot.phase ~= "InProgress" then
		return
	end
	local matchPlayer = snapshot.players[tostring(player.UserId)]
	local root = characterRoot(player)
	if not matchPlayer or not root then
		return
	end

	local lock = locks[player.UserId]
	if lock and not lock.userId and not lock.minionId and not lock.objectiveId then
		local acquired = acquireNear(player, matchPlayer.team, root.Position)
		if acquired then
			acquired.moveTo = lock.moveTo
			lock = acquired
			locks[player.UserId] = lock
		end
	end
	if not lock then
		return
	end

	if lock.userId or lock.minionId or lock.objectiveId then
		if not visibleTo(player, lock) then
			if lock.moveTo then
				locks[player.UserId] = { kind = "player", moveTo = lock.moveTo }
			else
				locks[player.UserId] = nil
				pushCombat(player)
			end
			return
		end
		local pos = resolveTarget(lock)
		if not pos then
			if lock.moveTo then
				locks[player.UserId] = { kind = "player", moveTo = lock.moveTo }
			else
				locks[player.UserId] = nil
				pushCombat(player)
			end
			return
		end
		local dist = (pos - root.Position).Magnitude
		if dist > Config.AutoAttack.Range then
			lock.windupEnds = nil
			walkToward(player, pos)
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
		local readyAt = nextAA[player.UserId] or 0
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
		if not visibleTo(player, lock) then
			lock.windupEnds = nil
			return
		end
		strike(player, lock)
		lock.windupEnds = nil
		nextAA[player.UserId] = t + Config.AutoAttack.Interval
		pushCombat(player)
		return
	end

	if lock.moveTo then
		local remaining = lock.moveTo - root.Position
		if remaining.Magnitude <= 3 then
			locks[player.UserId] = nil
			pushCombat(player)
			return
		end
		walkToward(player, lock.moveTo)
	end
end

function CombatService.issueAttack(player: Player, request: unknown): Types.AbilityResult
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot or snapshot.phase ~= "InProgress" then
		return { ok = false, error = "Match is not in progress." }
	end
	local matchPlayer = snapshot.players[tostring(player.UserId)]
	local state = combat[player.UserId]
	if not matchPlayer or not state or not state.alive then
		return { ok = false, error = "You are down. Wait for respawn." }
	end
	if typeof(request) ~= "table" then
		return { ok = false, error = "Invalid attack." }
	end
	local kind = (request :: any).kind
	if kind == "stop" then
		locks[player.UserId] = nil
		pushCombat(player)
		return { ok = true, combat = state }
	end

	local lock: AttackLock
	if kind == "player" then
		local userId = (request :: any).userId
		if typeof(userId) ~= "number" then
			return { ok = false, error = "No champion targeted." }
		end
		local other = Players:GetPlayerByUserId(userId)
		local otherMatch = snapshot.players[tostring(userId)]
		if not other or not otherMatch or otherMatch.team == matchPlayer.team then
			return { ok = false, error = "Not an enemy champion." }
		end
		if not VisionService.canSeePlayer(player, other) then
			return { ok = false, error = "No vision." }
		end
		lock = { kind = "player", userId = userId }
	elseif kind == "minion" then
		local minionId = (request :: any).minionId
		if typeof(minionId) ~= "string" then
			return { ok = false, error = "No kitten targeted." }
		end
		local minion = MinionService.get(minionId)
		if not minion or minion.team == matchPlayer.team then
			return { ok = false, error = "Not an enemy kitten." }
		end
		if not VisionService.canSeeMinion(player, minionId) then
			return { ok = false, error = "No vision." }
		end
		lock = { kind = "minion", minionId = minionId }
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
	else
		return { ok = false, error = "Unknown attack." }
	end

	locks[player.UserId] = lock
	pushCombat(player)
	tickAutoAttack(player)
	return { ok = true, combat = state }
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
	locks[player.UserId] = { kind = "player", moveTo = dest }
	pushCombat(player)
	tickAutoAttack(player)
	return { ok = true, combat = state }
end

function CombatService.useAbility(player: Player, request: unknown): Types.AbilityResult
	local snapshot = if matchApi then matchApi.getSnapshot() else nil
	if not snapshot or snapshot.phase ~= "InProgress" then
		return { ok = false, error = "Match is not in progress." }
	end

	local matchPlayer = snapshot.players[tostring(player.UserId)]
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
	local state = combat[player.UserId]
	if not ability or not state then
		return { ok = false, error = "Combat state missing." }
	end
	if not state.alive then
		return { ok = false, error = "You are down. Wait for respawn." }
	end

	local t = now()
	if state.cooldowns[slot] > t then
		return { ok = false, error = "Ability on cooldown." }
	end
	if state.mana < ability.manaCost then
		return { ok = false, error = "Not enough mana." }
	end

	local root = characterRoot(player)
	if not root then
		return { ok = false, error = "No character." }
	end

	local delta = aim - root.Position
	local distance = delta.Magnitude
	if distance > ability.range + 6 then
		return { ok = false, error = "Out of range." }
	end

	state.mana -= ability.manaCost
	state.cooldowns[slot] = t + ability.cooldown
	local power = ability.damage
	if ability.damage > 0 then
		power += state.bonusDamage or 0
	end

	if ability.kind == "dash" and distance > 1 then
		local travel = math.min(distance, ability.range)
		local goal = root.Position + delta.Unit * travel
		root.CFrame = CFrame.new(goal.X, root.Position.Y, goal.Z)
	end

	if ability.heal > 0 then
		for _, other in Players:GetPlayers() do
			local otherMatch = snapshot.players[tostring(other.UserId)]
			local otherRoot = characterRoot(other)
			if otherMatch and otherMatch.team == matchPlayer.team and otherRoot then
				if (otherRoot.Position - aim).Magnitude <= ability.radius or other == player then
					healPlayer(other, ability.heal)
				end
			end
		end
	end

	if (ability.shield or 0) > 0 then
		for _, other in Players:GetPlayers() do
			local otherMatch = snapshot.players[tostring(other.UserId)]
			local otherRoot = characterRoot(other)
			if otherMatch and otherMatch.team == matchPlayer.team and otherRoot then
				if (otherRoot.Position - aim).Magnitude <= ability.radius or other == player then
					shieldPlayer(other, ability.shield or 0)
				end
			end
		end
	end

	if (ability.stunSeconds or 0) > 0 then
		for _, other in Players:GetPlayers() do
			local otherMatch = snapshot.players[tostring(other.UserId)]
			local otherRoot = characterRoot(other)
			if otherMatch and otherMatch.team ~= matchPlayer.team and otherRoot then
				if (otherRoot.Position - aim).Magnitude <= ability.radius then
					stunPlayer(other, ability.stunSeconds or 0)
				end
			end
		end
	end

	if power > 0 then
		for _, other in Players:GetPlayers() do
			local otherMatch = snapshot.players[tostring(other.UserId)]
			local otherRoot = characterRoot(other)
			if otherMatch and otherMatch.team ~= matchPlayer.team and otherRoot then
				if (otherRoot.Position - aim).Magnitude <= ability.radius then
					damagePlayer(player, other, power)
				end
			end
		end

		local minionHit = false
		for _, minion in MinionService.list() do
			if minion.team ~= matchPlayer.team then
				if (minion.part.Position - aim).Magnitude <= ability.radius + Config.Minions.HitRadius then
					minionHit = true
					break
				end
			end
		end
		if minionHit then
			local foeTeam: Types.TeamId = if matchPlayer.team == "Blue" then "Red" else "Blue"
			TowerService.noteThreat(player, foeTeam)
		end
		MinionService.damageInRadius(player, matchPlayer.team, aim, ability.radius + Config.Minions.HitRadius, power)

		local map = MapBuilder.get()
		local objectives = map:FindFirstChild("Objectives")
		if objectives then
			for _, child in objectives:GetChildren() do
				if child:IsA("BasePart") then
					local team = child:GetAttribute(Constants.Attributes.Team)
					if team ~= matchPlayer.team and (child.Position - aim).Magnitude <= ability.radius + Config.Combat.StructureTouchRadius then
						damageObjective(player, child, power)
						if team == "Blue" or team == "Red" then
							TowerService.noteThreat(player, team)
						end
					end
				end
			end
		end
	end

	Remotes.event("CombatUpdated"):FireClient(player, state)
	return { ok = true, combat = state }
end

return CombatService
