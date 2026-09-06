--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Types = require(Shared:WaitForChild("Types"))

local MapBuilder = {}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, extras: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	if extras then
		for key, value in extras do
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function spawnLocation(parent: Instance, name: string, position: Vector3, team: Team?, color: Color3): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = name
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(position)
	spawn.Color = color
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.35
	spawn.Duration = 0
	spawn.Neutral = team == nil
	spawn.AllowTeamChangeOnTouch = false
	if team then
		spawn.TeamColor = team.TeamColor
	end
	spawn.Parent = parent
	return spawn
end

local function billboard(adornee: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(180, 40)
	gui.StudsOffset = Vector3.new(0, adornee.Size.Y / 2 + 3, 0)
	gui.AlwaysOnTop = true
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
end

local function makeObjective(
	parent: Instance,
	id: string,
	team: Types.TeamId,
	kind: Types.ObjectiveKind,
	lane: string,
	position: Vector3,
	maxHealth: number
): Part
	local color = if team == "Blue" then Color3.fromRGB(80, 150, 230) else Color3.fromRGB(230, 90, 90)
	local size = if kind == "Nexus" then Vector3.new(14, 18, 14) else Vector3.new(8, 22, 8)
	local shape = if kind == "Nexus" then Enum.PartType.Ball else Enum.PartType.Cylinder

	local objective = part(parent, id, size, CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, {
		Material = Enum.Material.Neon,
		Shape = shape,
	})
	if kind == "Nexus" then
		objective.CFrame = CFrame.new(position)
		objective.Shape = Enum.PartType.Ball
	end

	objective:SetAttribute(Constants.Attributes.ObjectiveId, id)
	objective:SetAttribute(Constants.Attributes.Team, team)
	objective:SetAttribute("Kind", kind)
	objective:SetAttribute("Lane", lane)
	objective:SetAttribute("MaxHealth", maxHealth)
	objective:SetAttribute("Health", maxHealth)

	local suffix = if lane ~= "Base" then ` ({lane})` else ""
	billboard(objective, `{team} {kind}{suffix}`, Color3.new(1, 1, 1))
	return objective
end

local function makeCatNpc(parent: Instance, id: string, name: string, position: Vector3, fur: Color3)
	local model = Instance.new("Model")
	model.Name = id
	model.Parent = parent

	local body = part(model, "Body", Vector3.new(4.2, 2.4, 6.2), CFrame.new(position + Vector3.new(0, 1.4, 0)), fur)
	body.Material = Enum.Material.SmoothPlastic
	model.PrimaryPart = body

	local head = part(model, "Head", Vector3.new(2.6, 2.4, 2.6), CFrame.new(position + Vector3.new(0, 3.4, -2.2)), fur)
	head.Shape = Enum.PartType.Ball

	part(model, "EarL", Vector3.new(0.8, 1.4, 0.8), CFrame.new(position + Vector3.new(-0.8, 4.8, -2.3)), fur)
	part(model, "EarR", Vector3.new(0.8, 1.4, 0.8), CFrame.new(position + Vector3.new(0.8, 4.8, -2.3)), fur)
	part(model, "Tail", Vector3.new(0.7, 0.7, 3.4), CFrame.new(position + Vector3.new(1.4, 2.2, 3.4)), fur)

	body:SetAttribute(Constants.Attributes.NpcId, id)
	head:SetAttribute(Constants.Attributes.NpcId, id)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	billboard(head, name, Color3.fromRGB(255, 236, 210))
	return model
end

function MapBuilder.build(): Folder
	local existing = Workspace:FindFirstChild(Constants.MapFolderName)
	if existing then
		existing:Destroy()
	end

	local root = folder(Workspace, Constants.MapFolderName)
	local terrain = folder(root, "Terrain")
	local lanes = folder(root, "Lanes")
	local objectives = folder(root, "Objectives")
	local bases = folder(root, "Bases")
	local npcs = folder(root, "Npcs")
	local spawns = folder(root, "Spawns")
	folder(root, "Minions")
	folder(root, "Jungle")
	folder(root, "Wards")

	-- Ground + river + jungle
	part(terrain, "Ground", Vector3.new(420, 2, 280), CFrame.new(0, -1, 0), Color3.fromRGB(126, 168, 92))
	part(terrain, "River", Vector3.new(28, 1.2, 280), CFrame.new(0, 0.2, 0), Color3.fromRGB(90, 160, 210), {
		Material = Enum.Material.Glass,
		Transparency = 0.25,
	})
	part(terrain, "JungleNorth", Vector3.new(90, 1.4, 50), CFrame.new(-70, 0.3, -90), Color3.fromRGB(70, 110, 60))
	part(terrain, "JungleSouth", Vector3.new(90, 1.4, 50), CFrame.new(70, 0.3, 90), Color3.fromRGB(70, 110, 60))
	part(terrain, "LobbyPad", Vector3.new(36, 1.2, 36), CFrame.new(0, 0.6, 0), Color3.fromRGB(255, 214, 170), {
		Material = Enum.Material.Marble,
	})

	-- Three lanes
	local laneColor = Color3.fromRGB(196, 176, 132)
	for _, spec in {
		{ name = "Top", z = -80 },
		{ name = "Mid", z = 0 },
		{ name = "Bot", z = 80 },
	} do
		part(lanes, spec.name, Vector3.new(320, 0.8, 16), CFrame.new(0, 0.4, spec.z), laneColor)
	end

	local blueTeam = Teams:FindFirstChild(Constants.Teams.BlueInstance) :: Team?
	local redTeam = Teams:FindFirstChild(Constants.Teams.RedInstance) :: Team?

	part(bases, "BlueKeep", Vector3.new(48, 8, 48), CFrame.new(-170, 4, 0), Color3.fromRGB(60, 100, 170), {
		Transparency = 0.35,
		CanCollide = false,
	})
	part(bases, "RedKeep", Vector3.new(48, 8, 48), CFrame.new(170, 4, 0), Color3.fromRGB(170, 70, 70), {
		Transparency = 0.35,
		CanCollide = false,
	})

	local lobbySpawn = spawnLocation(spawns, "Lobby", Vector3.new(0, 1.4, 0), nil, Color3.fromRGB(255, 196, 140))
	local blueSpawn = spawnLocation(spawns, "BlueFountain", Vector3.new(-176, 1.4, 0), blueTeam, Color3.fromRGB(90, 160, 255))
	local redSpawn = spawnLocation(spawns, "RedFountain", Vector3.new(176, 1.4, 0), redTeam, Color3.fromRGB(255, 110, 110))

	-- Towers + nexuses (outer → inner → nexus)
	local defs: {
		{
			id: string,
			team: Types.TeamId,
			kind: Types.ObjectiveKind,
			lane: string,
			position: Vector3,
			maxHealth: number,
		}
	} =
		{
			{ id = "BlueTopOuter", team = "Blue", kind = "Tower", lane = "Top", position = Vector3.new(-90, 11, -80), maxHealth = 1400 },
			{ id = "BlueMidOuter", team = "Blue", kind = "Tower", lane = "Mid", position = Vector3.new(-90, 11, 0), maxHealth = 1400 },
			{ id = "BlueBotOuter", team = "Blue", kind = "Tower", lane = "Bot", position = Vector3.new(-90, 11, 80), maxHealth = 1400 },
			{ id = "BlueNexus", team = "Blue", kind = "Nexus", lane = "Base", position = Vector3.new(-168, 10, 0), maxHealth = 2200 },
			{ id = "RedTopOuter", team = "Red", kind = "Tower", lane = "Top", position = Vector3.new(90, 11, -80), maxHealth = 1400 },
			{ id = "RedMidOuter", team = "Red", kind = "Tower", lane = "Mid", position = Vector3.new(90, 11, 0), maxHealth = 1400 },
			{ id = "RedBotOuter", team = "Red", kind = "Tower", lane = "Bot", position = Vector3.new(90, 11, 80), maxHealth = 1400 },
			{ id = "RedNexus", team = "Red", kind = "Nexus", lane = "Base", position = Vector3.new(168, 10, 0), maxHealth = 2200 },
		}

	for _, def in defs do
		makeObjective(objectives, def.id, def.team, def.kind, def.lane, def.position, def.maxHealth)
	end

	makeCatNpc(npcs, "PawmartBlue", "Pawmart Clerk", Vector3.new(-160, 0, 18), Color3.fromRGB(240, 200, 120))
	makeCatNpc(npcs, "PawmartRed", "Pawmart Clerk", Vector3.new(160, 0, -18), Color3.fromRGB(240, 200, 120))
	makeCatNpc(npcs, "OldTom", "Old Tom", Vector3.new(-40, 0, -100), Color3.fromRGB(160, 140, 120))
	makeCatNpc(npcs, "KittyCaster", "Kitty Caster", Vector3.new(0, 0, 24), Color3.fromRGB(80, 80, 90))

	root:SetAttribute("Built", true)
	root:SetAttribute("LobbySpawn", lobbySpawn.Name)
	root:SetAttribute("BlueSpawn", blueSpawn.Name)
	root:SetAttribute("RedSpawn", redSpawn.Name)
	MapBuilder.refreshNexusGate()

	return root
end

function MapBuilder.get(): Folder
	local folderInstance = Workspace:FindFirstChild(Constants.MapFolderName)
	if folderInstance and folderInstance:IsA("Folder") then
		return folderInstance
	end
	return MapBuilder.build()
end

function MapBuilder.getSpawn(team: Types.TeamId?): SpawnLocation
	local map = MapBuilder.get()
	local spawns = map:FindFirstChild("Spawns")
	local name = if team == "Blue" then "BlueFountain" elseif team == "Red" then "RedFountain" else "Lobby"
	local spawn = if spawns then spawns:FindFirstChild(name) else nil
	if spawn and spawn:IsA("SpawnLocation") then
		return spawn
	end
	error(`Missing spawn {name}`)
end

function MapBuilder.getObjectivePart(id: string): BasePart?
	local map = MapBuilder.get()
	local objectives = map:FindFirstChild("Objectives")
	if not objectives then
		return nil
	end
	local child = objectives:FindFirstChild(id)
	if child and child:IsA("BasePart") then
		return child
	end
	return nil
end

local function readObjectives(): { [string]: Types.ObjectiveState }
	local map = MapBuilder.get()
	local objectives = map:FindFirstChild("Objectives")
	local states: { [string]: Types.ObjectiveState } = {}
	if not objectives then
		return states
	end
	for _, child in objectives:GetChildren() do
		if child:IsA("BasePart") then
			local id = child:GetAttribute(Constants.Attributes.ObjectiveId)
			local team = child:GetAttribute(Constants.Attributes.Team)
			local kind = child:GetAttribute("Kind")
			if typeof(id) == "string" and (team == "Blue" or team == "Red") and (kind == "Tower" or kind == "Nexus") then
				local maxHealth = child:GetAttribute("MaxHealth")
				local health = child:GetAttribute("Health")
				local hp = if typeof(health) == "number" then health else 1000
				states[id] = {
					id = id,
					team = team,
					kind = kind,
					lane = (child:GetAttribute("Lane") :: string?) or "Mid",
					maxHealth = if typeof(maxHealth) == "number" then maxHealth else 1000,
					health = hp,
					alive = hp > 0,
					vulnerable = kind ~= "Nexus",
				}
			end
		end
	end
	return states
end

function MapBuilder.livingTowerCount(team: Types.TeamId): number
	local count = 0
	for _, state in readObjectives() do
		if state.team == team and state.kind == "Tower" and state.alive then
			count += 1
		end
	end
	return count
end

function MapBuilder.towerCount(team: Types.TeamId): number
	local count = 0
	for _, state in readObjectives() do
		if state.team == team and state.kind == "Tower" then
			count += 1
		end
	end
	return count
end

function MapBuilder.isNexusVulnerable(team: Types.TeamId): boolean
	local Config = require(script.Parent.Parent.Config)
	local down = MapBuilder.towerCount(team) - MapBuilder.livingTowerCount(team)
	return down >= Config.Nexus.TowersRequiredDown
end

function MapBuilder.objectiveStates(): { [string]: Types.ObjectiveState }
	local states = readObjectives()
	for _, state in states do
		if state.kind == "Nexus" then
			state.vulnerable = MapBuilder.isNexusVulnerable(state.team)
		end
	end
	return states
end

function MapBuilder.refreshNexusGate()
	local map = MapBuilder.get()
	local objectives = map:FindFirstChild("Objectives")
	if not objectives then
		return
	end
	for _, child in objectives:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("Kind") == "Nexus" then
			local team = child:GetAttribute(Constants.Attributes.Team)
			if team == "Blue" or team == "Red" then
				local open = MapBuilder.isNexusVulnerable(team)
				child:SetAttribute("Vulnerable", open)
				local label = child:FindFirstChild("Label")
				if label and label:IsA("BillboardGui") then
					local text = label:FindFirstChildWhichIsA("TextLabel")
					if text then
						text.Text = if open then `{team} Nexus (OPEN)` else `{team} Nexus (gated)`
					end
				end
				local hp = child:GetAttribute("Health")
				if typeof(hp) ~= "number" or hp > 0 then
					child.Transparency = if open then 0 else 0.35
				end
			end
		end
	end
end

function MapBuilder.minionFolder(): Folder
	local map = MapBuilder.get()
	local existing = map:FindFirstChild("Minions")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folderInstance = Instance.new("Folder")
	folderInstance.Name = "Minions"
	folderInstance.Parent = map
	return folderInstance
end

function MapBuilder.jungleFolder(): Folder
	local map = MapBuilder.get()
	local existing = map:FindFirstChild("Jungle")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folderInstance = Instance.new("Folder")
	folderInstance.Name = "Jungle"
	folderInstance.Parent = map
	return folderInstance
end

function MapBuilder.laneZ(lane: string): number
	if lane == "Top" then
		return -80
	elseif lane == "Bot" then
		return 80
	end
	return 0
end

return MapBuilder

