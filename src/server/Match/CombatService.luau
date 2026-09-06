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

type MatchApi = {
	getSnapshot: () -> Types.MatchSnapshot?,
	onPlayerKilled: (killer: Player, victim: Player) -> (),
	onObjectiveDestroyed: (attacker: Player, objective: Types.ObjectiveState) -> (),
	addGold: (player: Player, amount: number) -> (),
}

local CombatService = {}

local combat: { [number]: Types.CombatState } = {}
local matchApi: MatchApi? = nil

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
	}
	combat[player.UserId] = state
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
end

function CombatService.init(api: MatchApi)
	matchApi = api

	Players.PlayerRemoving:Connect(function(player)
		combat[player.UserId] = nil
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
		matchApi.onPlayerKilled(killer, victim)
	end
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
					matchApi.onObjectiveDestroyed(attacker, objective)
					matchApi.addGold(attacker, Config.Match.TowerGold)
				end
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
