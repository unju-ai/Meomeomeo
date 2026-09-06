--!strict

local Workspace = game:GetService("Workspace")

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local CombatService = require(script.Parent.CombatService)
local Config = require(script.Parent.Parent.Config)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local MinionService = require(script.Parent.MinionService)
local ShopService = require(script.Parent.ShopService)

type BotBrain = {
	userId: number,
	lane: string,
	visitedLane: boolean,
	bought: number,
	nextThink: number,
	nextAbility: number,
}

local BotService = {}

local running = false
local generation = 0
local brains: { [number]: BotBrain } = {}

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

	local bb = Instance.new("BillboardGui")
	bb.Name = "BotName"
	bb.Size = UDim2.fromOffset(160, 22)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.Parent = root
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = matchPlayer.displayName
	label.Parent = bb

	model.Parent = botsFolder()
	return model
end

local function tunables(difficulty: Types.BotDifficulty): { ThinkInterval: number, RetreatHp: number, AbilityChance: number, ExtraAaDelay: number }
	return if difficulty == "Easy" then Config.Bots.Easy else Config.Bots.Normal
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
	local root = CombatService.rootOf(userId)
	if not root then
		return
	end
	local speed = 16 + ShopService.bonuses(userId).walkSpeed
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
	kind: "player" | "minion" | "objective",
	userId: number?,
	minionId: string?,
	objectiveId: string?,
	position: Vector3,
	isChampion: boolean,
}

local function nearestHunt(team: Types.TeamId, origin: Vector3): Hunt?
	local snapshot = matchSnapshot()
	if not snapshot then
		return nil
	end
	local best: Hunt? = nil
	local bestDist = 48
	for _, other in snapshot.players do
		if other.team ~= team then
			local combat = CombatService.get(other.userId)
			local root = CombatService.rootOf(other.userId)
			if combat and combat.alive and root then
				local d = (root.Position - origin).Magnitude
				if d <= bestDist then
					bestDist = d
					best = { kind = "player", userId = other.userId, position = root.Position, isChampion = true }
				end
			end
		end
	end
	for _, minion in MinionService.list() do
		if minion.team ~= team then
			local d = (minion.part.Position - origin).Magnitude
			if d <= bestDist then
				bestDist = d
				best = { kind = "minion", minionId = minion.id, position = minion.part.Position, isChampion = false }
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

	local tune = tunables(currentDifficulty)
	local now = Workspace:GetServerTimeNow()
	local team = matchPlayer.team
	local fountain = fountainPos(team)
	local atFountain = ShopService.nearFountain(brain.userId, root.Position)
	local hpRatio = if combat.maxHealth > 0 then combat.health / combat.maxHealth else 1

	if hpRatio <= tune.RetreatHp then
		stepToward(brain.userId, fountain, dt)
		return
	end

	if atFountain and brain.visitedLane and brain.bought < #Config.Bots.ShopItems then
		local nextItem = Config.Bots.ShopItems[brain.bought + 1]
		if nextItem and matchPlayer.gold >= 200 then
			local result = ShopService.grant(brain.userId, nextItem)
			if result.ok then
				brain.bought += 1
			end
		end
		if hpRatio < 0.92 then
			return
		end
	end

	local hunt = nearestHunt(team, root.Position)
	if hunt then
		local dist = (hunt.position - root.Position).Magnitude
		if dist > Config.AutoAttack.Range then
			stepToward(brain.userId, hunt.position, dt)
		else
			if hunt.kind == "player" then
				CombatService.issueAttackFor(brain.userId, { kind = "player", userId = hunt.userId })
			elseif hunt.kind == "minion" then
				CombatService.issueAttackFor(brain.userId, { kind = "minion", minionId = hunt.minionId })
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
							CombatService.useAbilityFor(brain.userId, { slot = slot, aimPosition = hunt.position })
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

	for _, matchPlayer in snapshot.players do
		if matchPlayer.isBot and matchPlayer.championId then
			laneIndex[matchPlayer.team] = (laneIndex[matchPlayer.team] or 0) + 1
			local lane = lanes[((laneIndex[matchPlayer.team] - 1) % #lanes) + 1]
			local model = makeBotModel(matchPlayer)
			CombatService.bindCharacter(matchPlayer.userId, model)
			CombatService.resetBot(matchPlayer.userId, matchPlayer.championId)
			local spawn = MapBuilder.getSpawn(matchPlayer.team)
			local offsetZ = assignedZ(lane) * 0.12
			pcall(function()
				model:PivotTo(spawn.CFrame + Vector3.new(0, 4, offsetZ))
			end)
			brains[matchPlayer.userId] = {
				userId = matchPlayer.userId,
				lane = lane,
				visitedLane = false,
				bought = 0,
				nextThink = 0,
				nextAbility = 0,
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
							if matchPlayer then
								local hunt = nearestHunt(matchPlayer.team, root.Position)
								if hunt and (hunt.position - root.Position).Magnitude > Config.AutoAttack.Range then
									stepToward(brain.userId, hunt.position, dt)
								elseif not hunt then
									local follow = waveFollow(matchPlayer.team, brain.lane)
									stepToward(brain.userId, follow or Vector3.new(lanePushX(matchPlayer.team), 3, assignedZ(brain.lane)), dt)
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

return BotService
