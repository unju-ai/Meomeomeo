--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Types = require(Shared:WaitForChild("Types"))
local BrandCatalog = require(Shared:WaitForChild("BrandCatalog"))

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

-- Visual-only kit: never collides, never steals click/AA raycasts, never blocks bots.
local function decor(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, extras: { [string]: any }?): Part
	local merged: { [string]: any } = {
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}
	if extras then
		for key, value in extras do
			merged[key] = value
		end
	end
	return part(parent, name, size, cframe, color, merged)
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function lamp(parent: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Parent = parent
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

local function applyNightMarketLighting()
	Lighting.ClockTime = 21.15
	Lighting.Brightness = 1.4
	Lighting.Ambient = Color3.fromRGB(52, 42, 68)
	Lighting.OutdoorAmbient = Color3.fromRGB(78, 62, 96)
	Lighting.GeographicLatitude = 28
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.22
	Lighting.FogColor = Color3.fromRGB(36, 28, 52)
	Lighting.FogStart = 90
	Lighting.FogEnd = 460

	local function ensure(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing then
			return existing
		end
		local inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
		return inst
	end

	local atmosphere = ensure("Atmosphere", "MeoAtmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.18
	atmosphere.Color = Color3.fromRGB(118, 96, 148)
	atmosphere.Decay = Color3.fromRGB(92, 58, 48)
	atmosphere.Glare = 0.12
	atmosphere.Haze = 1.35

	local cc = ensure("ColorCorrectionEffect", "MeoColor") :: ColorCorrectionEffect
	cc.Enabled = true
	cc.Brightness = 0.02
	cc.Contrast = 0.08
	cc.Saturation = 0.12
	cc.TintColor = Color3.fromRGB(255, 236, 220)

	local bloom = ensure("BloomEffect", "MeoBloom") :: BloomEffect
	bloom.Enabled = true
	bloom.Intensity = 0.28
	bloom.Size = 12
	bloom.Threshold = 0.85
end

local function dressTower(objective: Part, team: Types.TeamId, position: Vector3)
	local accent = if team == "Blue" then Color3.fromRGB(180, 210, 255) else Color3.fromRGB(255, 190, 170)
	local yarn = Color3.fromRGB(255, 196, 90)
	decor(objective, "EarL", Vector3.new(1.6, 2.4, 1.1), CFrame.new(position + Vector3.new(-2.1, 12.4, 0)), accent)
	decor(objective, "EarR", Vector3.new(1.6, 2.4, 1.1), CFrame.new(position + Vector3.new(2.1, 12.4, 0)), accent)
	decor(objective, "Yarn", Vector3.new(2.2, 2.2, 2.2), CFrame.new(position + Vector3.new(0, 13.6, 0)), yarn, {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
	})
	local collar = decor(objective, "Collar", Vector3.new(9.2, 0.7, 9.2), CFrame.new(position + Vector3.new(0, 6, 0)), accent, {
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	lamp(collar, accent, 0.35, 14)
end

local function dressNexus(objective: Part, team: Types.TeamId, position: Vector3)
	local accent = if team == "Blue" then Color3.fromRGB(160, 200, 255) else Color3.fromRGB(255, 170, 160)
	decor(objective, "EarL", Vector3.new(2.4, 3.2, 1.6), CFrame.new(position + Vector3.new(-3.2, 8.2, 0)), accent)
	decor(objective, "EarR", Vector3.new(2.4, 3.2, 1.6), CFrame.new(position + Vector3.new(3.2, 8.2, 0)), accent)
	for i, offset in { Vector3.new(7, -4, 5), Vector3.new(-7, -4, 5), Vector3.new(0, -4, -8) } do
		decor(objective, `Yarn{i}`, Vector3.new(2.4, 2.4, 2.4), CFrame.new(position + offset), Color3.fromRGB(255, 196, 90), {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.SmoothPlastic,
		})
	end
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
	if kind == "Nexus" then
		dressNexus(objective, team, position)
	else
		dressTower(objective, team, position)
	end
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

local function catStatue(parent: Instance, name: string, position: Vector3, fur: Color3, facing: number)
	local root = CFrame.new(position) * CFrame.Angles(0, facing, 0)
	decor(parent, `{name}Body`, Vector3.new(2.4, 1.5, 3.4), root * CFrame.new(0, 1.1, 0), fur)
	decor(parent, `{name}Head`, Vector3.new(1.6, 1.6, 1.6), root * CFrame.new(0, 2.4, -1.2), fur, { Shape = Enum.PartType.Ball })
	decor(parent, `{name}EarL`, Vector3.new(0.5, 0.9, 0.45), root * CFrame.new(-0.45, 3.3, -1.2), fur)
	decor(parent, `{name}EarR`, Vector3.new(0.5, 0.9, 0.45), root * CFrame.new(0.45, 3.3, -1.2), fur)
	decor(parent, `{name}Tail`, Vector3.new(0.4, 0.4, 2.1), root * CFrame.new(0.8, 1.3, 1.8), fur)
end

local function fountainKit(parent: Instance, team: Types.TeamId, center: Vector3)
	local color = if team == "Blue" then Color3.fromRGB(70, 120, 210) else Color3.fromRGB(210, 80, 80)
	local warm = Color3.fromRGB(255, 196, 110)
	part(parent, `{team}FountainPad`, Vector3.new(40, 1, 40), CFrame.new(center.X, 0.12, center.Z), color, {
		Material = Enum.Material.Marble,
	})
	decor(parent, `{team}FountainRim`, Vector3.new(28, 0.5, 28), CFrame.new(center.X, 0.55, center.Z), warm, {
		Material = Enum.Material.Neon,
		Transparency = 0.4,
	})
	for i, offset in {
		Vector3.new(-16, 0, -16),
		Vector3.new(16, 0, -16),
		Vector3.new(-16, 0, 16),
		Vector3.new(16, 0, 16),
	} do
		local pillar = decor(
			parent,
			`{team}Pillar{i}`,
			Vector3.new(2.2, 10, 2.2),
			CFrame.new(center + offset + Vector3.new(0, 5.4, 0)),
			color:Lerp(Color3.new(1, 1, 1), 0.15),
			{ Material = Enum.Material.Concrete }
		)
		local lantern = decor(
			parent,
			`{team}Lantern{i}`,
			Vector3.new(1.1, 1.1, 1.1),
			CFrame.new(center + offset + Vector3.new(0, 11, 0)),
			warm,
			{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon }
		)
		lamp(lantern, warm, 0.45, 18)
		lamp(pillar, color, 0.15, 10)
	end
	local facing = if team == "Blue" then 0 else math.pi
	catStatue(parent, `{team}Statue`, center + Vector3.new(if team == "Blue" then 14 else -14, 0, 14), color:Lerp(Color3.fromRGB(240, 210, 170), 0.35), facing)
end

local function campPedestal(parent: Instance, id: string, position: Vector3, color: Color3, label: string)
	local pad = decor(parent, `{id}Pad`, Vector3.new(8.5, 0.4, 8.5), CFrame.new(position.X, 0.22, position.Z), color, {
		Material = Enum.Material.Slate,
		Transparency = 0.05,
	})
	decor(parent, `{id}Ring`, Vector3.new(7.2, 0.18, 7.2), CFrame.new(position.X, 0.48, position.Z), color:Lerp(Color3.new(1, 1, 1), 0.25), {
		Material = Enum.Material.Neon,
		Transparency = 0.45,
	})
	local marker = decor(parent, `{id}Yarn`, Vector3.new(1.3, 1.3, 1.3), CFrame.new(position.X, 1.1, position.Z), color, {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
	})
	lamp(marker, color, 0.25, 10)
	billboard(pad, label, Color3.fromRGB(255, 236, 210))
	local gui = pad:FindFirstChild("Label")
	if gui and gui:IsA("BillboardGui") then
		gui.AlwaysOnTop = false
		gui.MaxDistance = 70
		gui.StudsOffset = Vector3.new(0, 3.2, 0)
	end
end

local function brushPocket(parent: Instance, name: string, position: Vector3, size: Vector3)
	decor(parent, name, size, CFrame.new(position), Color3.fromRGB(36, 72, 48), {
		Material = Enum.Material.Glass,
		Transparency = 0.62,
	})
	decor(parent, `{name}Fog`, size * 0.7, CFrame.new(position + Vector3.new(0, 2, 0)), Color3.fromRGB(70, 90, 80), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.ForceField,
		Transparency = 0.82,
	})
end

local function makeHost(parent: Instance, host: BrandCatalog.HostDef, position: Vector3)
	local model = Instance.new("Model")
	model.Name = host.id
	model.Parent = parent

	-- Placeholder art-toy silhouette. Non-colliding so the lobby cast cannot block a lane.
	local function detail(name: string, size: Vector3, offset: Vector3, color: Color3): Part
		return part(model, name, size, CFrame.new(position + offset), color, {
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		})
	end
	local body = detail("Body", Vector3.new(3.4, 4.2, 2.8), Vector3.new(0, 2.1, 0), host.color)
	body.Shape = Enum.PartType.Ball
	model.PrimaryPart = body
	detail("EarL", Vector3.new(0.6, 0.9, 0.6), Vector3.new(-1, 3.9, 0), host.color)
	detail("EarR", Vector3.new(0.6, 0.9, 0.6), Vector3.new(1, 3.9, 0), host.color)
	for _, side in { -1, 1 } do
		local eyeY = if host.id == "HostMo" and side == 1 then 2.7 else 2.6
		local eye = detail(`Eye{side}`, Vector3.new(0.32, 0.32, 0.2), Vector3.new(side * 0.8, eyeY, -1.24), BrandCatalog.PaperColor)
		eye.Shape = Enum.PartType.Ball
		local pupil = detail(`Pupil{side}`, Vector3.new(0.12, 0.12, 0.08), Vector3.new(side * 0.8, eyeY, -1.36), BrandCatalog.InkColor)
		pupil.Shape = Enum.PartType.Ball
	end
	detail("Mouth", Vector3.new(0.32, 0.06, 0.08), Vector3.new(0, 2.1, -1.4), Color3.fromRGB(8, 8, 8))
	detail("Braincell", Vector3.new(0.3, 0.3, 0.1), Vector3.new(0, 3.2, -1.15), BrandCatalog.BraincellColor)
	body:SetAttribute(Constants.Attributes.NpcId, host.id)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = host.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	billboard(body, host.name, BrandCatalog.PaperColor)
end

function MapBuilder.build(): Folder
	local existing = Workspace:FindFirstChild(Constants.MapFolderName)
	if existing then
		existing:Destroy()
	end

	applyNightMarketLighting()

	local root = folder(Workspace, Constants.MapFolderName)
	local terrain = folder(root, "Terrain")
	local lanes = folder(root, "Lanes")
	local objectives = folder(root, "Objectives")
	local bases = folder(root, "Bases")
	local npcs = folder(root, "Npcs")
	local spawns = folder(root, "Spawns")
	local decorFolder = folder(root, "Decor")
	folder(root, "Minions")
	folder(root, "Jungle")
	folder(root, "Wards")

	-- Ground + river + jungle (same bounds as Constants.MapBounds / minimap).
	part(terrain, "Ground", Vector3.new(420, 2, 280), CFrame.new(0, -1, 0), Color3.fromRGB(58, 78, 52))
	part(terrain, "River", Vector3.new(28, 1.2, 280), CFrame.new(0, 0.2, 0), Color3.fromRGB(48, 92, 148), {
		Material = Enum.Material.Glass,
		Transparency = 0.18,
	})
	decor(terrain, "RiverFoamW", Vector3.new(2.2, 0.35, 280), CFrame.new(-14.4, 0.55, 0), Color3.fromRGB(180, 220, 240), {
		Material = Enum.Material.Neon,
		Transparency = 0.55,
	})
	decor(terrain, "RiverFoamE", Vector3.new(2.2, 0.35, 280), CFrame.new(14.4, 0.55, 0), Color3.fromRGB(180, 220, 240), {
		Material = Enum.Material.Neon,
		Transparency = 0.55,
	})
	part(terrain, "JungleNorth", Vector3.new(90, 1.4, 50), CFrame.new(-70, 0.3, -90), Color3.fromRGB(42, 72, 48))
	part(terrain, "JungleSouth", Vector3.new(90, 1.4, 50), CFrame.new(70, 0.3, 90), Color3.fromRGB(42, 72, 48))
	part(terrain, "LobbyPad", Vector3.new(36, 1.2, 36), CFrame.new(0, 0.6, 0), Color3.fromRGB(255, 200, 140), {
		Material = Enum.Material.Marble,
	})

	-- Three lanes — same Z as Constants.LaneZ so bots / minions / minimap stay aligned.
	local laneColor = Color3.fromRGB(214, 176, 110)
	local laneInner = Color3.fromRGB(92, 64, 40)
	for _, spec in {
		{ name = "Top", z = -80 },
		{ name = "Mid", z = 0 },
		{ name = "Bot", z = 80 },
	} do
		part(lanes, spec.name, Vector3.new(320, 0.8, 16), CFrame.new(0, 0.4, spec.z), laneColor)
		decor(lanes, `{spec.name}Inner`, Vector3.new(320, 0.12, 4.5), CFrame.new(0, 0.86, spec.z), laneInner, {
			Transparency = 0.15,
		})
		for x = -140, 140, 40 do
			decor(lanes, `{spec.name}Dot{x}`, Vector3.new(2.2, 0.28, 2.2), CFrame.new(x, 0.95, spec.z), Color3.fromRGB(255, 220, 140), {
				Material = Enum.Material.Neon,
				Transparency = 0.25,
			})
		end
	end

	-- Brush sits in jungle pockets only — off the 16-stud lane corridors.
	brushPocket(decorFolder, "BrushNW", Vector3.new(-88, 3.2, -108), Vector3.new(22, 7, 16))
	brushPocket(decorFolder, "BrushNE", Vector3.new(-48, 3.2, -78), Vector3.new(16, 6, 14))
	brushPocket(decorFolder, "BrushSE", Vector3.new(88, 3.2, 108), Vector3.new(22, 7, 16))
	brushPocket(decorFolder, "BrushSW", Vector3.new(48, 3.2, 78), Vector3.new(16, 6, 14))
	brushPocket(decorFolder, "BrushCrabN", Vector3.new(-22, 2.8, -48), Vector3.new(12, 5, 10))
	brushPocket(decorFolder, "BrushCrabS", Vector3.new(22, 2.8, 48), Vector3.new(12, 5, 10))

	-- Camp pedestals match JungleService spawn XZ (Decor folder, not Jungle).
	campPedestal(decorFolder, "YarnGolemNW", Vector3.new(-70, 0, -100), Color3.fromRGB(230, 190, 110), "Yarn Golem")
	campPedestal(decorFolder, "PigeonsNW", Vector3.new(-100, 0, -88), Color3.fromRGB(170, 168, 176), "Pigeons")
	campPedestal(decorFolder, "YarnGolemSE", Vector3.new(70, 0, 100), Color3.fromRGB(230, 190, 110), "Yarn Golem")
	campPedestal(decorFolder, "PigeonsSE", Vector3.new(100, 0, 88), Color3.fromRGB(170, 168, 176), "Pigeons")
	campPedestal(decorFolder, "RiverCrabN", Vector3.new(0, 0, -48), Color3.fromRGB(90, 170, 160), "River Crab")
	campPedestal(decorFolder, "RiverCrabS", Vector3.new(0, 0, 48), Color3.fromRGB(90, 170, 160), "River Crab")

	local blueTeam = Teams:FindFirstChild(Constants.Teams.BlueInstance) :: Team?
	local redTeam = Teams:FindFirstChild(Constants.Teams.RedInstance) :: Team?

	part(bases, "BlueKeep", Vector3.new(48, 8, 48), CFrame.new(-170, 4, 0), Color3.fromRGB(60, 100, 170), {
		Transparency = 0.45,
		CanCollide = false,
	})
	part(bases, "RedKeep", Vector3.new(48, 8, 48), CFrame.new(170, 4, 0), Color3.fromRGB(170, 70, 70), {
		Transparency = 0.45,
		CanCollide = false,
	})
	fountainKit(bases, "Blue", Vector3.new(-176, 0, 0))
	fountainKit(bases, "Red", Vector3.new(176, 0, 0))

	local lobbySpawn = spawnLocation(spawns, "Lobby", Vector3.new(0, 1.4, 0), nil, Color3.fromRGB(255, 196, 140))
	local blueSpawn = spawnLocation(spawns, "BlueFountain", Vector3.new(-176, 1.4, 0), blueTeam, Color3.fromRGB(90, 160, 255))
	local redSpawn = spawnLocation(spawns, "RedFountain", Vector3.new(176, 1.4, 0), redTeam, Color3.fromRGB(255, 110, 110))

	-- Towers + nexuses (outer → inner → nexus). Positions unchanged.
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
	for index, host in BrandCatalog.hosts() do
		makeHost(npcs, host, Vector3.new((index - 2) * 9, 1.2, 12))
	end

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
