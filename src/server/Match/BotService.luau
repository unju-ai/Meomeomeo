--!strict

local Workspace = game:GetService("Workspace")

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local ItemCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local JungleBotLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("JungleBotLogic"))
local Targeting = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Targeting"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local VisionLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("VisionLogic"))

local CombatService = require(script.Parent.CombatService)
local Config = require(script.Parent.Parent.Config)
local JungleService = require(script.Parent.JungleService)
local ChampionAppearance = require(script.Parent.Parent.World.ChampionAppearance)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local MinionService = require(script.Parent.MinionService)
local ShopService = require(script.Parent.ShopService)
local TowerService = require(script.Parent.TowerService)
local VisionService = require(script.Parent.VisionService)
local WardService = require(script.Parent.WardService)

type Tune = {
	ThinkInterval: number,
	RetreatHp: number,
	AbilityChance: number,
	ExtraAaDelay: number,
	DamageAmp: number,
	LastHit: boolean,
	LastHitMul: number,
	LeadShots: boolean,
	SkillshotSpeed: number,
	Jungle: boolean,
	Ward: boolean,
	Dodge: boolean,
	AvoidAoe: boolean,
	DiveIq: boolean,
	UseLens: boolean,
	ShopItems: { string },
}

type BotBrain = {
	userId: number,
	lane: string,
	visitedLane: boolean,
	bought: number,
	nextThink: number,
	nextAbility: number,
	jungler: boolean,
	warded: boolean,
	dodgeUntil: number,
	dodgeDest: Vector3?,
	-- Sticky jungle goal. The walk loop between thinks follows nav, not the lane.
	campId: string?,
	routeIndex: number,
	navKind: string?,
	navX: number?,
	navZ: number?,
	closing: boolean,
}

local BotService = {}

local running = false
local generation = 0
local brains: { [number]: BotBrain } = {}
-- team:userId → server time the enemy was last inside team vision. Rotate hints expire.
local gankSeenAt: { [string]: number } = {}

local BRUSH_BOXES: { JungleBotLogic.BrushBox } = {}
for _, spec in VisionLogic.Brushes do
	table.insert(BRUSH_BOXES, {
		x = spec.x,
		z = spec.z,
		sx = spec.sx,
		sz = spec.sz,
	})
end

local function botsFolder(): Folder
	local map = MapBuilder.get()
	local existing = map:FindFirstChild("Bots")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = map
	return folder
end

local function weld(part: BasePart, root: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = part
	w.Parent = part
end

local function makeBotModel(matchPlayer: Types.MatchPlayer): Model
	local champ = if matchPlayer.championId then ChampionCatalog.get(matchPlayer.championId) else nil
	local color = if champ then champ.color elseif matchPlayer.team == "Blue" then Color3.fromRGB(70, 130, 255) else Color3.fromRGB(220, 70, 70)
	local model = Instance.new("Model")
	model.Name = matchPlayer.displayName

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Color = color
	root.Material = Enum.Material.SmoothPlastic
	root.Anchored = true
	root.CanCollide = true
	root.Parent = model

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.1, 2.2, 1.2)
	torso.Color = color
	torso.Material = Enum.Material.SmoothPlastic
	torso.Anchored = false
	torso.CanCollide = false
	torso.Massless = true
	torso.CFrame = root.CFrame * CFrame.new(0, 0.1, 0)
	torso.Parent = model
	weld(torso, root)

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.Color = color:Lerp(Color3.new(1, 1, 1), 0.15)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = false
	head.CanCollide = false
	head.Massless = true
	head.CFrame = root.CFrame * CFrame.new(0, 1.7, 0)
	head.Parent = model
	weld(head, root)

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = 16
	humanoid.Parent = model

	model.PrimaryPart = root
	model:SetAttribute(Constants.Attributes.UserId, matchPlayer.userId)
	model:SetAttribute(Constants.Attributes.Team, matchPlayer.team)
	if matchPlayer.championId then
		model:SetAttribute(Constants.Attributes.ChampionId, matchPlayer.championId)
	end

	model.Parent = botsFolder()
	ChampionAppearance.applyMatchPlayer(model, matchPlayer)
	return model
end

local function tunables(difficulty: Types.BotDifficulty): Tune
	if difficulty == "Easy" then
		return Config.Bots.Easy
	elseif difficulty == "Hard" then
		return Config.Bots.Hard
	end
	return Config.Bots.Normal
end

local currentDifficulty: Types.BotDifficulty = "Normal"
local MatchServiceRef: any = nil

local function matchSnapshot(): Types.MatchSnapshot?
	if not MatchServiceRef then
		MatchServiceRef = require(script.Parent.MatchService)
	end
	return MatchServiceRef.snapshot()
end

local function stepToward(userId: number, dest: Vector3, dt: number)
	if CombatService.isChanneling(userId) then
		return
	end
	local root = CombatService.rootOf(userId)
	if not root then
		return
	end
	local snapshot = matchSnapshot()
	local matchPlayer = if snapshot then snapshot.players[tostring(userId)] else nil
	local team: Types.TeamId = if matchPlayer then matchPlayer.team else "Red"
	local speed = (16 + ShopService.bonuses(userId).walkSpeed) * WardService.slowMul(team, root.Position)
	local delta = Vector3.new(dest.X - root.Position.X, 0, dest.Z - root.Position.Z)
	if delta.Magnitude <= 0.4 then
		return
	end
	local step = math.min(speed * dt, delta.Magnitude)
	root.CFrame = CFrame.new(root.Position + delta.Unit * step, root.Position + delta.Unit)
end

local function fountainPos(team: Types.TeamId): Vector3
	return MapBuilder.getSpawn(team).Position + Vector3.new(0, 3, 0)
end

local function lanePushX(team: Types.TeamId): number
	return if team == "Blue" then 150 else -150
end

local function assignedZ(lane: string): number
	if lane == "Top" then
		return Constants.LaneZ.Top
	elseif lane == "Bot" then
		return Constants.LaneZ.Bot
	end
	return Constants.LaneZ.Mid
end

local function waveFollow(team: Types.TeamId, lane: string): Vector3?
	local z = assignedZ(lane)
	local best: Vector3? = nil
	local bestScore = if team == "Blue" then -1e9 else 1e9
	for _, minion in MinionService.list() do
		if minion.team == team and math.abs(minion.part.Position.Z - z) <= 22 then
			local x = minion.part.Position.X
			if team == "Blue" then
				if x > bestScore then
					bestScore = x
					best = minion.part.Position
				end
			elseif x < bestScore then
				bestScore = x
				best = minion.part.Position
			end
		end
	end
	return best
end

type Hunt = {
	kind: "player" | "minion" | "objective" | "jungle",
	userId: number?,
	minionId: string?,
	objectiveId: string?,
	jungleId: string?,
	position: Vector3,
	isChampion: boolean,
	health: number?,
}

local lastSeen: { [number]: { pos: Vector3, t: number } } = {}

local function recordSeen(userId: number, position: Vector3)
	lastSeen[userId] = { pos = position, t = os.clock() }
end

local function leadAim(tune: Tune, targetUserId: number?, targetPos: Vector3, origin: Vector3): Vector3
	if not tune.LeadShots or not targetUserId then
		return targetPos
	end
	local sample = lastSeen[targetUserId]
	local now = os.clock()
	local vel = Vector3.zero
	if sample then
		local dt = now - sample.t
		if dt > 0.04 and dt < 0.9 then
			local raw = (targetPos - sample.pos) / dt
			vel = Vector3.new(raw.X, 0, raw.Z)
		end
	end
	recordSeen(targetUserId, targetPos)
	local dist = (targetPos - origin).Magnitude
	local speed = math.max(tune.SkillshotSpeed, Config.Combat.ProjectileSpeed)
	local travel = math.clamp(dist / math.max(speed, 20), 0, 0.7)
	return targetPos + vel * travel
end

local function aaGuess(userId: number): number
	local state = CombatService.get(userId)
	local base = Config.AutoAttack.BaseDamage + if state then (state.bonusDamage or 0) else 0
	return base * CombatService.getOutgoingAmp(userId)
end

local function nearestChampion(team: Types.TeamId, origin: Vector3, radius: number, viewerUserId: number?): Hunt?
	local snapshot = matchSnapshot()
	if not snapshot then
		return nil
	end
	local best: Hunt? = nil
	local bestDist = radius
	for _, other in snapshot.players do
		if other.team ~= team then
			local combat = CombatService.get(other.userId)
			local root = CombatService.rootOf(other.userId)
			if combat and combat.alive and root then
				local d = (root.Position - origin).Magnitude
				local seen = if viewerUserId then VisionService.canSeeChampion(viewerUserId, other.userId) else true
				if d <= bestDist and seen then
					bestDist = d
					best = { kind = "player", userId = other.userId, position = root.Position, isChampion = true }
					recordSeen(other.userId, root.Position)
				end
			end
		end
	end
	return best
end

local function lastHitMinion(team: Types.TeamId, origin: Vector3, userId: number, tune: Tune): Hunt?
	local threshold = aaGuess(userId) * tune.LastHitMul
	local best: Hunt? = nil
	local bestHp = 1e9
	for _, minion in MinionService.list() do
		if minion.team ~= team then
			local d = (minion.part.Position - origin).Magnitude
			if d <= 42 and minion.health <= threshold and minion.health < bestHp then
				if VisionService.canSeeMinion(userId, minion.id) then
					bestHp = minion.health
					best = {
						kind = "minion",
						minionId = minion.id,
						position = minion.part.Position,
						isChampion = false,
						health = minion.health,
					}
				end
			end
		end
	end
	return best
end

local function nearestHunt(team: Types.TeamId, origin: Vector3, userId: number, tune: Tune): Hunt?
	local champ = nearestChampion(team, origin, Config.AutoAttack.AcquireRange + 8, userId)
	if champ then
		return champ
	end
	if tune.LastHit then
		local ripe = lastHitMinion(team, origin, userId, tune)
		if ripe then
			return ripe
		end
	end
	local best: Hunt? = nil
	local bestDist = if tune.LastHit then 28 else 48
	if not tune.LastHit then
		for _, minion in MinionService.list() do
			if minion.team ~= team then
				local d = (minion.part.Position - origin).Magnitude
				if d <= bestDist and VisionService.canSeeMinion(userId, minion.id) then
					bestDist = d
					best = { kind = "minion", minionId = minion.id, position = minion.part.Position, isChampion = false }
				end
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
				if objTeam ~= team and typeof(hp) == "number" and hp > 0 and child:GetAttribute("Vulnerable") ~= false then
					local d = (child.Position - origin).Magnitude
					if d <= bestDist + 8 then
						local id = child:GetAttribute(Constants.Attributes.ObjectiveId)
						if typeof(id) == "string" then
							bestDist = d
							best = { kind = "objective", objectiveId = id, position = child.Position, isChampion = false }
						end
					end
				end
			end
		end
	end
	return best
end

local function lanePushed(team: Types.TeamId, lane: string): boolean
	local follow = waveFollow(team, lane)
	if not follow then
		return false
	end
	if team == "Blue" then
		return follow.X > 18
	end
	return follow.X < -18
end

local function enemyTowerAt(team: Types.TeamId, position: Vector3): (Vector3?, number?, Types.TeamId?)
	for _, state in MapBuilder.objectiveStates() do
		if state.alive and state.team ~= team then
			local part = MapBuilder.getObjectivePart(state.id)
			if part then
				local range = Config.Towers.Range
				if state.kind == "Nexus" then
					range = Config.Towers.NexusRange
				elseif state.tier == "Inner" then
					range = Config.Towers.InnerRange
				end
				if (part.Position - position).Magnitude <= range then
					return part.Position, range, state.team
				end
			end
		end
	end
	return nil, nil, nil
end

local function waveCountUnder(team: Types.TeamId, towerPos: Vector3, range: number): (number, number)
	local allies = 0
	local enemies = 0
	for _, minion in MinionService.list() do
		if (minion.part.Position - towerPos).Magnitude <= range + 4 then
			if minion.team == team then
				allies += 1
			else
				enemies += 1
			end
		end
	end
	return allies, enemies
end

local function targetHpRatio(hunt: Hunt): number
	if hunt.kind == "player" and hunt.userId then
		local combat = CombatService.get(hunt.userId)
		if combat and combat.maxHealth > 0 then
			return combat.health / combat.maxHealth
		end
	end
	if hunt.health and hunt.health > 0 then
		return 1
	end
	return 1
end

local function allowDive(tune: Tune, brain: BotBrain, team: Types.TeamId, origin: Vector3, dest: Vector3, hunt: Hunt?): boolean
	local towerPos, range, defender = enemyTowerAt(team, dest)
	if not towerPos or not range or not defender then
		return true
	end
	if not tune.DiveIq then
		return false
	end
	local aggro = TowerService.aggroUserId(defender)
	local allies, enemies = waveCountUnder(team, towerPos, range)
	local crashing = allies >= 2 and allies > enemies
	local hp = if hunt then targetHpRatio(hunt) else 1
	local killDive = hunt ~= nil and hunt.isChampion and hp <= (if currentDifficulty == "Hard" then 0.38 else 0.24)
	local short = (origin - towerPos).Magnitude <= range + 6
	if aggro == brain.userId and not killDive then
		return false
	end
	if crashing then
		return true
	end
	if killDive and short then
		return true
	end
	if currentDifficulty == "Hard" and killDive then
		return true
	end
	return false
end

local function sidestepFromCast(cast: CombatService.AbilityCast)
	local tune = tunables(currentDifficulty)
	if currentDifficulty == "Easy" then
		return
	end
	local line = cast.mode == "line" and tune.Dodge
	local aoe = cast.mode == "ground" and tune.AvoidAoe
	if not line and not aoe then
		return
	end
	local snapshot = matchSnapshot()
	if not snapshot then
		return
	end
	for _, brain in brains do
		local matchPlayer = snapshot.players[tostring(brain.userId)]
		local root = CombatService.rootOf(brain.userId)
		local combat = CombatService.get(brain.userId)
		if not matchPlayer or matchPlayer.team == cast.team or not root or not combat or not combat.alive then
			continue
		end
		local pad = if currentDifficulty == "Hard" then 6 else 4
		if not Targeting.hits(cast.mode, cast.origin, cast.dest, root.Position, cast.radius + pad) then
			continue
		end
		local flat = Targeting.flat(cast.origin, cast.dest)
		local perp = Vector3.new(-flat.Z, 0, flat.X)
		if perp.Magnitude < 0.5 then
			perp = Vector3.new(1, 0, 0)
		else
			perp = perp.Unit
		end
		local away = root.Position - cast.origin
		if away:Dot(perp) < 0 then
			perp = -perp
		end
		local dist = if currentDifficulty == "Hard" then 12 else 8
		local dest = root.Position + perp * dist
		root.CFrame = CFrame.new(dest.X, root.Position.Y, dest.Z)
		local hang = if cast.travel then math.clamp(cast.travel + 0.12, 0.28, 0.75) else 0.32
		brain.dodgeUntil = Workspace:GetServerTimeNow() + hang
		brain.dodgeDest = dest + perp * 4
	end
end

local function gankKey(team: Types.TeamId, userId: number): string
	return `{team}:{userId}`
end

local function aliveCamps(): { JungleBotLogic.CampView }
	local list = {}
	for _, monster in JungleService.list() do
		table.insert(list, {
			id = monster.id,
			x = monster.spawn.X,
			z = monster.spawn.Z,
			health = monster.health,
			maxHealth = monster.maxHealth,
		})
	end
	return list
end

local function laneViews(team: Types.TeamId, viewerUserId: number): { JungleBotLogic.LaneView }
	local now = Workspace:GetServerTimeNow()
	local hints: { [string]: { x: number, z: number, laneDist: number } } = {}
	local snapshot = matchSnapshot()
	if snapshot then
		for _, other in snapshot.players do
			if other.team ~= team and other.respawnAt == nil then
				local key = gankKey(team, other.userId)
				if VisionService.canSeeChampion(viewerUserId, other.userId) then
					gankSeenAt[key] = now
				end
				local stamped = gankSeenAt[key]
				local known = VisionService.lastKnownOf(team, other.userId)
				local fresh = stamped ~= nil and (now - stamped) <= JungleBotLogic.GankMemorySeconds
				if known and fresh then
					local bestLane: string? = nil
					local bestDist = 36
					for _, name in Constants.Lanes do
						local gap = math.abs(known.Z - assignedZ(name))
						if gap <= bestDist then
							bestDist = gap
							bestLane = name
						end
					end
					if bestLane then
						local prev = hints[bestLane]
						if not prev or bestDist < prev.laneDist then
							hints[bestLane] = { x = known.X, z = known.Z, laneDist = bestDist }
						end
					end
				end
			end
		end
	end
	local lanes = {}
	for _, name in Constants.Lanes do
		local follow = waveFollow(team, name)
		local hint = hints[name]
		table.insert(lanes, {
			name = name,
			z = assignedZ(name),
			waveX = if follow then follow.X else nil,
			lastKnownX = if hint then hint.x else nil,
			lastKnownZ = if hint then hint.z else nil,
		})
	end
	return lanes
end

local function visibleEnemy(team: Types.TeamId, origin: Vector3, userId: number): JungleBotLogic.EnemyView?
	local champ = nearestChampion(team, origin, Config.AutoAttack.AcquireRange + 8, userId)
	if not champ then
		return nil
	end
	return { x = champ.position.X, z = champ.position.Z }
end

local function clearJungleNav(brain: BotBrain)
	brain.navKind = nil
	brain.navX = nil
	brain.navZ = nil
	brain.closing = false
end

local function releaseCamp(brain: BotBrain)
	if brain.closing or brain.navKind == "camp" then
		CombatService.issueAttackFor(brain.userId, { kind = "stop" })
	end
	clearJungleNav(brain)
end

-- Returns true when the jungler should not fall through into lane combat this think.
local function pursueJungle(brain: BotBrain, team: Types.TeamId, tune: Tune, root: BasePart, dt: number): boolean
	if not tune.Jungle or not brain.jungler then
		clearJungleNav(brain)
		brain.campId = nil
		return false
	end
	local decision = JungleBotLogic.decide({
		difficulty = currentDifficulty,
		team = team,
		jungler = true,
		x = root.Position.X,
		z = root.Position.Z,
		lanePushed = lanePushed(team, brain.lane),
		attackRange = Config.AutoAttack.Range,
		memory = { campId = brain.campId, routeIndex = brain.routeIndex },
		camps = aliveCamps(),
		enemy = visibleEnemy(team, root.Position, brain.userId),
		lanes = laneViews(team, brain.userId),
		brushes = BRUSH_BOXES,
	})
	brain.campId = decision.memory.campId
	brain.routeIndex = decision.memory.routeIndex
	if decision.action == "lane" or decision.action == "fight" then
		releaseCamp(brain)
		return false
	end
	if decision.action == "rotate" then
		local dest = Vector3.new(decision.x or root.Position.X, root.Position.Y, decision.z or root.Position.Z)
		if not allowDive(tune, brain, team, root.Position, dest, nil) then
			releaseCamp(brain)
			return false
		end
	end
	local stepX = decision.stepX or decision.x or root.Position.X
	local stepZ = decision.stepZ or decision.z or root.Position.Z
	brain.navKind = decision.action
	brain.navX = stepX
	brain.navZ = stepZ
	if (root.Position - fountainPos(team)).Magnitude > 40 then
		brain.visitedLane = true
	end
	if decision.action == "camp" and decision.campId and decision.x and decision.z then
		local atGoal = math.abs(stepX - decision.x) < 0.1 and math.abs(stepZ - decision.z) < 0.1
		local monster = JungleService.get(decision.campId)
		local aim = if monster then monster.part.Position else Vector3.new(decision.x, root.Position.Y, decision.z)
		local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
		if atGoal and flat.Magnitude <= Config.AutoAttack.Range then
			local swung = CombatService.issueAttackFor(brain.userId, { kind = "jungle", jungleId = decision.campId })
			if swung.ok then
				brain.closing = true
				return true
			end
			-- Fog or a drum is in the way. Creep to the spawn instead of standing in brush.
			brain.closing = false
		end
	end
	brain.closing = false
	stepToward(brain.userId, Vector3.new(stepX, root.Position.Y, stepZ), dt)
	return true
end

local function think(brain: BotBrain, dt: number)
	local snapshot = matchSnapshot()
	if not snapshot or snapshot.phase ~= "InProgress" then
		return
	end
	local matchPlayer = snapshot.players[tostring(brain.userId)]
	local combat = CombatService.get(brain.userId)
	local root = CombatService.rootOf(brain.userId)
	if not matchPlayer or not combat or not root then
		return
	end
	if not combat.alive then
		return
	end
	if CombatService.isChanneling(brain.userId) then
		return
	end

	local tune = tunables(currentDifficulty)
	local now = Workspace:GetServerTimeNow()
	local team = matchPlayer.team
	local fountain = fountainPos(team)
	local atFountain = ShopService.nearFountain(brain.userId, root.Position)
	local hpRatio = if combat.maxHealth > 0 then combat.health / combat.maxHealth else 1

	if hpRatio <= tune.RetreatHp then
		releaseCamp(brain)
		stepToward(brain.userId, fountain, dt)
		return
	end

	if brain.dodgeUntil > now and brain.dodgeDest then
		stepToward(brain.userId, brain.dodgeDest, dt)
		return
	end

	local hereTower = enemyTowerAt(team, root.Position)
	if hereTower and not allowDive(tune, brain, team, root.Position, root.Position, nil) then
		releaseCamp(brain)
		stepToward(brain.userId, fountain, dt)
		return
	end

	if atFountain and brain.visitedLane and brain.bought < #tune.ShopItems then
		local nextItem = tune.ShopItems[brain.bought + 1]
		local def = if nextItem then ItemCatalog.get(nextItem) else nil
		if nextItem and def and matchPlayer.gold >= def.cost then
			local result = ShopService.grant(brain.userId, nextItem)
			if result.ok then
				brain.bought += 1
			end
		end
		if hpRatio < 0.92 then
			releaseCamp(brain)
			return
		end
	end

	if tune.UseLens and ShopService.has(brain.userId, "WhiskerLens") and now >= WardService.lensReadyAt(brain.userId) then
		for _, ward in WardService.list() do
			if ward.team ~= team and WardService.canSee(team, ward.id, root.Position) then
				if (ward.part.Position - root.Position).Magnitude <= Config.Vision.LensRadius then
					CombatService.useLensFor(brain.userId)
					break
				end
			end
		end
	end

	if tune.Ward and brain.jungler and not brain.warded and brain.visitedLane then
		local started = snapshot.startedAt
		local early = typeof(started) == "number" and (now - started) <= 80
		if early and now >= WardService.trinketReadyAt(brain.userId) then
			local towardRiver = Vector3.new(if team == "Blue" then 18 else -18, 0, 0)
			local dest = root.Position + towardRiver
			local placed = if currentDifficulty == "Hard"
				then WardService.placeControlFor(brain.userId, team, dest, root)
				else WardService.placeTrinketFor(brain.userId, team, dest, root)
			if placed.ok then
				brain.warded = true
			end
		end
	end

	if pursueJungle(brain, team, tune, root, dt) then
		return
	end

	local hunt = nearestHunt(team, root.Position, brain.userId, tune)
	if hunt then
		if not allowDive(tune, brain, team, root.Position, hunt.position, hunt) then
			stepToward(brain.userId, fountain, dt)
			return
		end
		local dist = (hunt.position - root.Position).Magnitude
		if dist > Config.AutoAttack.Range then
			stepToward(brain.userId, hunt.position, dt)
		else
			if hunt.kind == "player" then
				CombatService.issueAttackFor(brain.userId, { kind = "player", userId = hunt.userId })
			elseif hunt.kind == "minion" then
				CombatService.issueAttackFor(brain.userId, { kind = "minion", minionId = hunt.minionId })
			elseif hunt.kind == "jungle" then
				CombatService.issueAttackFor(brain.userId, { kind = "jungle", jungleId = hunt.jungleId })
			else
				CombatService.issueAttackFor(brain.userId, { kind = "objective", objectiveId = hunt.objectiveId })
			end
		end

		if hunt.isChampion and now >= brain.nextAbility and math.random() <= tune.AbilityChance then
			local champ = if matchPlayer.championId then ChampionCatalog.get(matchPlayer.championId) else nil
			if champ then
				for _, slot in Constants.Slots do
					local ability = champ.abilities[slot]
					local rank = if combat.ranks then combat.ranks[slot] else 0
					if ability and (rank or 0) > 0 and combat.cooldowns[slot] <= now and combat.mana >= ability.manaCost then
						if dist <= ability.range + 8 then
							local aim = hunt.position
							if Targeting.of(ability) == "line" then
								aim = leadAim(tune, hunt.userId, hunt.position, root.Position)
							end
							CombatService.useAbilityFor(brain.userId, { slot = slot, aimPosition = aim })
							brain.nextAbility = now + 0.8 + tune.ExtraAaDelay
							break
						end
					end
				end
			end
		end
		return
	end

	local follow = waveFollow(team, brain.lane)
	local dest = follow or Vector3.new(lanePushX(team), 3, assignedZ(brain.lane))
	if (dest - fountain).Magnitude > 40 then
		brain.visitedLane = true
	end
	stepToward(brain.userId, dest, dt)
end

function BotService.stop()
	generation += 1
	running = false
	for userId, _ in brains do
		local model = CombatService.modelOf(userId)
		CombatService.unbindCharacter(userId)
		CombatService.clear(userId)
		if model and model.Parent then
			model:Destroy()
		end
	end
	table.clear(brains)
	table.clear(lastSeen)
	table.clear(gankSeenAt)
	local map = Workspace:FindFirstChild(Constants.MapFolderName)
	local folder = if map then map:FindFirstChild("Bots") else nil
	if folder then
		folder:Destroy()
	end
end

function BotService.start()
	BotService.stop()
	local snapshot = matchSnapshot()
	if not snapshot then
		return
	end
	currentDifficulty = snapshot.botDifficulty or Config.Bots.DefaultDifficulty

	local lanes = Constants.Lanes
	local laneIndex: { [string]: number } = { Blue = 0, Red = 0 }
	local junglerAssigned: { [string]: boolean } = {}
	local tune = tunables(currentDifficulty)

	for _, matchPlayer in snapshot.players do
		if matchPlayer.isBot and matchPlayer.championId then
			laneIndex[matchPlayer.team] = (laneIndex[matchPlayer.team] or 0) + 1
			local lane = lanes[((laneIndex[matchPlayer.team] - 1) % #lanes) + 1]
			local model = makeBotModel(matchPlayer)
			CombatService.bindCharacter(matchPlayer.userId, model)
			CombatService.resetBot(matchPlayer.userId, matchPlayer.championId)
			CombatService.setOutgoingAmp(matchPlayer.userId, tune.DamageAmp)
			local spawn = MapBuilder.getSpawn(matchPlayer.team)
			local offsetZ = assignedZ(lane) * 0.12
			pcall(function()
				model:PivotTo(spawn.CFrame + Vector3.new(0, 4, offsetZ))
			end)
			local jungler = tune.Jungle and lane == "Mid" and not junglerAssigned[matchPlayer.team]
			if jungler then
				junglerAssigned[matchPlayer.team] = true
			end
			brains[matchPlayer.userId] = {
				userId = matchPlayer.userId,
				lane = lane,
				visitedLane = false,
				bought = 0,
				nextThink = 0,
				nextAbility = 0,
				jungler = jungler,
				warded = false,
				dodgeUntil = 0,
				dodgeDest = nil,
				campId = nil,
				routeIndex = 1,
				navKind = nil,
				navX = nil,
				navZ = nil,
				closing = false,
			}
		end
	end

	running = true
	local gen = generation
	task.spawn(function()
		local last = os.clock()
		while running and generation == gen do
			local clock = os.clock()
			local dt = math.clamp(clock - last, 0, 0.2)
			last = clock
			local snapshotNow = matchSnapshot()
			if snapshotNow and snapshotNow.phase == "InProgress" then
				local now = Workspace:GetServerTimeNow()
				local interval = tunables(currentDifficulty).ThinkInterval
				for _, brain in brains do
					if now >= brain.nextThink then
						brain.nextThink = now + interval
						think(brain, dt + interval)
					else
						-- Keep walking between thinks so bots don't hitch.
						local root = CombatService.rootOf(brain.userId)
						local combat = CombatService.get(brain.userId)
						if root and combat and combat.alive then
							local matchPlayer = snapshotNow.players[tostring(brain.userId)]
							local walkTune = tunables(currentDifficulty)
							local nowWalk = Workspace:GetServerTimeNow()
							local hpRatio = if combat.maxHealth > 0 then combat.health / combat.maxHealth else 1
							if matchPlayer and hpRatio <= walkTune.RetreatHp then
								stepToward(brain.userId, fountainPos(matchPlayer.team), dt)
							elseif matchPlayer and brain.dodgeUntil > nowWalk and brain.dodgeDest then
								stepToward(brain.userId, brain.dodgeDest, dt)
							elseif matchPlayer and brain.navKind == "camp" and brain.navX and brain.navZ and not brain.closing then
								stepToward(brain.userId, Vector3.new(brain.navX, root.Position.Y, brain.navZ), dt)
							elseif matchPlayer and brain.navKind == "rotate" and brain.navX and brain.navZ then
								stepToward(brain.userId, Vector3.new(brain.navX, root.Position.Y, brain.navZ), dt)
							elseif matchPlayer then
								local hunt = nearestHunt(matchPlayer.team, root.Position, brain.userId, walkTune)
								if hunt and (hunt.position - root.Position).Magnitude > Config.AutoAttack.Range then
									if allowDive(walkTune, brain, matchPlayer.team, root.Position, hunt.position, hunt) then
										stepToward(brain.userId, hunt.position, dt)
									else
										stepToward(brain.userId, fountainPos(matchPlayer.team), dt)
									end
								elseif not hunt then
									local follow = waveFollow(matchPlayer.team, brain.lane)
									local dest = follow or Vector3.new(lanePushX(matchPlayer.team), 3, assignedZ(brain.lane))
									if allowDive(walkTune, brain, matchPlayer.team, root.Position, dest, nil) then
										stepToward(brain.userId, dest, dt)
									end
								end
							end
						end
					end
				end
			end
			task.wait(0.1)
		end
	end)
end

CombatService.onAbilityCast(sidestepFromCast)

return BotService
