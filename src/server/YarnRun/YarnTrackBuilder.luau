--!strict

-- Night-market 3-lane ribbon far from the MOBA map. Engine Parts only.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local YarnRunCatalog = require(Shared:WaitForChild("YarnRunCatalog"))

local YarnTrackBuilder = {}

local built: { [number]: Folder } = {}
local root: Folder? = nil
local seed = 0
local pbMarker: Folder? = nil

local INDIGO = Color3.fromRGB(36, 24, 48)
local GOLD = Color3.fromRGB(255, 196, 74)
local CORAL = Color3.fromRGB(255, 122, 98)
local PEACH = Color3.fromRGB(255, 184, 140)
local CREAM = Color3.fromRGB(255, 243, 224)
local BROWN = Color3.fromRGB(92, 58, 42)
local INK = Color3.fromRGB(28, 18, 24)
local CYAN = Color3.fromRGB(90, 220, 255)
local MAGENTA = Color3.fromRGB(220, 90, 210)
local MINT = Color3.fromRGB(120, 220, 160)
local PIT = Color3.fromRGB(12, 8, 18)

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, extras: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CastShadow = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extras then
		for key, value in extras do
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function labelOn(host: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(140, 32)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = host
	local lab = Instance.new("TextLabel")
	lab.BackgroundTransparency = 1
	lab.Size = UDim2.fromScale(1, 1)
	lab.Font = Enum.Font.FredokaOne
	lab.TextSize = 22
	lab.TextColor3 = color
	lab.TextStrokeTransparency = 0.4
	lab.Text = text
	lab.Parent = gui
end

local function origin(): Vector3
	return Constants.YarnRunOrigin
end

function YarnTrackBuilder.world(lane: number, y: number, z: number): Vector3
	return origin() + Vector3.new(YarnRunCatalog.laneX(lane), y, z)
end

function YarnTrackBuilder.ensure()
	if root and root.Parent then
		return root
	end
	local existing = Workspace:FindFirstChild(Constants.YarnRunFolderName)
	if existing and existing:IsA("Folder") then
		root = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = Constants.YarnRunFolderName
	folder.Parent = Workspace
	root = folder
	return folder
end

local function paintDog(parent: Folder, lane: number, z: number)
	local at = YarnTrackBuilder.world(lane, 1.6, z)
	-- Soft hazard pad so brown dogs read against indigo floor on stream.
	part(parent, "HazardPad", Vector3.new(5.2, 0.18, 5.6), CFrame.new(at + Vector3.new(0, -1.35, 0.2)), CORAL, {
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	part(parent, "DogBody", Vector3.new(3.2, 2.2, 3.6), CFrame.new(at), BROWN)
	part(parent, "DogHead", Vector3.new(2.2, 1.8, 2.2), CFrame.new(at + Vector3.new(0, 1.4, 1.4)), BROWN)
	part(parent, "EarL", Vector3.new(0.7, 1.2, 0.5), CFrame.new(at + Vector3.new(-0.8, 2.6, 1.3)), Color3.fromRGB(60, 36, 28))
	part(parent, "EarR", Vector3.new(0.7, 1.2, 0.5), CFrame.new(at + Vector3.new(0.8, 2.6, 1.3)), Color3.fromRGB(60, 36, 28))
	part(parent, "Nose", Vector3.new(0.5, 0.4, 0.5), CFrame.new(at + Vector3.new(0, 1.4, 2.4)), INK, { Material = Enum.Material.Neon })
	part(parent, "EyeGlow", Vector3.new(0.35, 0.35, 0.35), CFrame.new(at + Vector3.new(-0.45, 1.7, 2.1)), CORAL, { Material = Enum.Material.Neon })
	part(parent, "EyeGlowR", Vector3.new(0.35, 0.35, 0.35), CFrame.new(at + Vector3.new(0.45, 1.7, 2.1)), CORAL, { Material = Enum.Material.Neon })
end

local function paintSign(parent: Folder, lane: number, z: number)
	local at = YarnTrackBuilder.world(lane, 6.2, z)
	part(parent, "PostL", Vector3.new(0.5, 8, 0.5), CFrame.new(YarnTrackBuilder.world(lane, 4, z) + Vector3.new(-2.4, 0, 0)), PEACH)
	part(parent, "PostR", Vector3.new(0.5, 8, 0.5), CFrame.new(YarnTrackBuilder.world(lane, 4, z) + Vector3.new(2.4, 0, 0)), PEACH)
	part(parent, "Board", Vector3.new(6.4, 2.6, 0.6), CFrame.new(at), CORAL, { Material = Enum.Material.Neon })
	part(parent, "YarnIcon", Vector3.new(1.4, 1.4, 0.7), CFrame.new(at + Vector3.new(0, 0, 0.2)), CREAM)
end

local function paintYarn(parent: Folder, lane: number, z: number)
	local at = YarnTrackBuilder.world(lane, 2.4, z)
	part(parent, "Yarn", Vector3.new(1.8, 1.8, 1.8), CFrame.new(at), CORAL, { Material = Enum.Material.Neon, Shape = Enum.PartType.Ball })
	part(parent, "YarnGlow", Vector3.new(2.4, 0.3, 2.4), CFrame.new(at + Vector3.new(0, -1.4, 0)), PEACH, { Transparency = 0.45 })
end

local function paintRoomba(parent: Folder, lane: number, z: number)
	local at = YarnTrackBuilder.world(lane, 0.7, z)
	part(parent, "Roomba", Vector3.new(5.4, 0.7, 5.4), CFrame.new(at), Color3.fromRGB(80, 80, 90), { Material = Enum.Material.Metal })
	part(parent, "Ring", Vector3.new(5.8, 0.2, 5.8), CFrame.new(at + Vector3.new(0, 0.4, 0)), Color3.fromRGB(120, 220, 255), {
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	})
	part(parent, "Button", Vector3.new(1.1, 0.4, 1.1), CFrame.new(at + Vector3.new(0, 0.5, 0)), CORAL, { Material = Enum.Material.Neon })
end

local function paintWall(parent: Folder, lane: number, z: number)
	local at = YarnTrackBuilder.world(lane, 6, z)
	part(parent, "Billboard", Vector3.new(8.4, 11, 1.1), CFrame.new(at), Color3.fromRGB(40, 28, 70), { Material = Enum.Material.SmoothPlastic })
	local neon = part(parent, "BillboardFace", Vector3.new(7.4, 8.4, 0.4), CFrame.new(at + Vector3.new(0, 0.4, 0.5)), MAGENTA, { Material = Enum.Material.Neon })
	part(parent, "EarL", Vector3.new(1.4, 2.2, 0.5), CFrame.new(at + Vector3.new(-2.2, 5.6, 0.4)), PEACH)
	part(parent, "EarR", Vector3.new(1.4, 2.2, 0.5), CFrame.new(at + Vector3.new(2.2, 5.6, 0.4)), PEACH)
	-- Ground telegraph so tall walls still read from chase cam.
	part(parent, "WallPad", Vector3.new(8.8, 0.2, 2.4), CFrame.new(at + Vector3.new(0, -5.7, 0)), MAGENTA, {
		Material = Enum.Material.Neon,
		Transparency = 0.28,
	})
	labelOn(neon, "DODGE", CREAM)
end

local function paintSpeed(parent: Folder, lane: number, z: number)
	local at = YarnTrackBuilder.world(lane, 2.6, z)
	part(parent, "Bolt", Vector3.new(1.1, 3.4, 0.6), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(18)), CYAN, { Material = Enum.Material.Neon })
	part(parent, "Bolt2", Vector3.new(2.4, 0.7, 0.6), CFrame.new(at + Vector3.new(0.4, 0.2, 0)), CYAN, { Material = Enum.Material.Neon })
	part(parent, "Chev", Vector3.new(2.2, 0.35, 1.6), CFrame.new(at + Vector3.new(0, -1.6, 1.2)), GOLD, { Material = Enum.Material.Neon })
	labelOn(part(parent, "SpeedTag", Vector3.new(0.4, 0.4, 0.4), CFrame.new(at + Vector3.new(0, 2.2, 0)), CYAN, { Transparency = 1 }), "SPD", CYAN)
end

local function paintMagnet(parent: Folder, lane: number, z: number)
	local at = YarnTrackBuilder.world(lane, 2.4, z)
	part(parent, "MagL", Vector3.new(0.7, 3.2, 0.7), CFrame.new(at + Vector3.new(-1.1, 0.4, 0)), MAGENTA, { Material = Enum.Material.Neon })
	part(parent, "MagR", Vector3.new(0.7, 3.2, 0.7), CFrame.new(at + Vector3.new(1.1, 0.4, 0)), MAGENTA, { Material = Enum.Material.Neon })
	part(parent, "MagBar", Vector3.new(3, 0.7, 0.7), CFrame.new(at + Vector3.new(0, -1.1, 0)), MAGENTA, { Material = Enum.Material.Neon })
	labelOn(part(parent, "MagTag", Vector3.new(0.4, 0.4, 0.4), CFrame.new(at + Vector3.new(0, 2.4, 0)), MAGENTA, { Transparency = 1 }), "MAG", MAGENTA)
end

local function paintShield(parent: Folder, lane: number, z: number)
	local at = YarnTrackBuilder.world(lane, 2.6, z)
	part(parent, "Dome", Vector3.new(3.2, 3.2, 3.2), CFrame.new(at), MINT, {
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		Shape = Enum.PartType.Ball,
	})
	part(parent, "Core", Vector3.new(1.2, 1.2, 1.2), CFrame.new(at), CREAM, { Material = Enum.Material.Neon, Shape = Enum.PartType.Ball })
	labelOn(part(parent, "ShdTag", Vector3.new(0.4, 0.4, 0.4), CFrame.new(at + Vector3.new(0, 2.4, 0)), MINT, { Transparency = 1 }), "SHD", MINT)
end

local function paintDouble(parent: Folder, lane: number, z: number)
	local at = YarnTrackBuilder.world(lane, 2.5, z)
	part(parent, "BallA", Vector3.new(1.7, 1.7, 1.7), CFrame.new(at + Vector3.new(-0.7, 0.2, 0)), GOLD, { Material = Enum.Material.Neon, Shape = Enum.PartType.Ball })
	part(parent, "BallB", Vector3.new(1.7, 1.7, 1.7), CFrame.new(at + Vector3.new(0.8, -0.1, 0.2)), CORAL, { Material = Enum.Material.Neon, Shape = Enum.PartType.Ball })
	labelOn(part(parent, "DblTag", Vector3.new(0.4, 0.4, 0.4), CFrame.new(at + Vector3.new(0, 2.3, 0)), GOLD, { Transparency = 1 }), "2X", GOLD)
end

local function paintFloor(bag: Folder, index: number, kind: YarnRunCatalog.SegmentKind)
	local z0 = index * YarnRunCatalog.SegmentLength
	local mid = origin() + Vector3.new(0, 0, z0 + YarnRunCatalog.SegmentLength * 0.5)
	if kind == "gap" then
		part(bag, "Pit", Vector3.new(22, 0.6, 16), CFrame.new(origin() + Vector3.new(0, -1.4, z0 + 28)), PIT)
		part(bag, "FloorA", Vector3.new(36, 1.2, 16), CFrame.new(origin() + Vector3.new(0, 0, z0 + 10)), INDIGO)
		part(bag, "FloorB", Vector3.new(36, 1.2, 10), CFrame.new(origin() + Vector3.new(0, 0, z0 + 36)), INDIGO)
		part(bag, "RailL", Vector3.new(1.2, 1.6, 18), CFrame.new(origin() + Vector3.new(-17, 1.2, z0 + 26)), GOLD, { Material = Enum.Material.Neon })
		part(bag, "RailR", Vector3.new(1.2, 1.6, 18), CFrame.new(origin() + Vector3.new(17, 1.2, z0 + 26)), GOLD, { Material = Enum.Material.Neon })
		part(bag, "JumpChev", Vector3.new(6, 0.4, 3), CFrame.new(origin() + Vector3.new(0, 1.4, z0 + 18)), CYAN, { Material = Enum.Material.Neon })
	elseif kind == "bridge" then
		part(bag, "DropL", Vector3.new(12, 0.5, YarnRunCatalog.SegmentLength), CFrame.new(origin() + Vector3.new(-14, -0.8, z0 + 20)), PIT)
		part(bag, "DropR", Vector3.new(12, 0.5, YarnRunCatalog.SegmentLength), CFrame.new(origin() + Vector3.new(14, -0.8, z0 + 20)), PIT)
		part(bag, "Span", Vector3.new(12, 1.4, YarnRunCatalog.SegmentLength), CFrame.new(mid + Vector3.new(0, 0.4, 0)), Color3.fromRGB(70, 48, 40))
		part(bag, "EdgeL", Vector3.new(0.5, 2.2, YarnRunCatalog.SegmentLength - 4), CFrame.new(origin() + Vector3.new(-6, 2, z0 + 20)), PEACH, { Material = Enum.Material.Neon })
		part(bag, "EdgeR", Vector3.new(0.5, 2.2, YarnRunCatalog.SegmentLength - 4), CFrame.new(origin() + Vector3.new(6, 2, z0 + 20)), PEACH, { Material = Enum.Material.Neon })
	elseif kind == "tunnel" then
		part(bag, "Floor", Vector3.new(36, 1.2, YarnRunCatalog.SegmentLength), CFrame.new(mid), INDIGO)
		part(bag, "Sheet", Vector3.new(32, 2.8, 1.2), CFrame.new(origin() + Vector3.new(0, 6.4, z0 + 22)), CORAL, { Material = Enum.Material.Neon, Transparency = 0.12 })
		part(bag, "PostA", Vector3.new(0.6, 8, 0.6), CFrame.new(origin() + Vector3.new(-16, 4, z0 + 22)), PEACH)
		part(bag, "PostB", Vector3.new(0.6, 8, 0.6), CFrame.new(origin() + Vector3.new(16, 4, z0 + 22)), PEACH)
	elseif kind == "fountain" then
		part(bag, "Floor", Vector3.new(36, 1.2, YarnRunCatalog.SegmentLength), CFrame.new(mid), INDIGO)
		part(bag, "Plinth", Vector3.new(6, 1.2, 6), CFrame.new(origin() + Vector3.new(0, 1.2, z0 + 20)), Color3.fromRGB(70, 40, 80), { Material = Enum.Material.Marble })
		part(bag, "Spray", Vector3.new(2.4, 4.2, 2.4), CFrame.new(origin() + Vector3.new(0, 4.2, z0 + 20)), CORAL, { Material = Enum.Material.Neon, Transparency = 0.35 })
	else
		part(bag, "Floor", Vector3.new(36, 1.2, YarnRunCatalog.SegmentLength), CFrame.new(mid), INDIGO)
	end
	for _, x in YarnRunCatalog.LaneXs do
		local dim = if kind == "bridge" and math.abs(x) > 1 then 0.08 else 0.12
		part(
			bag,
			"Lane",
			Vector3.new(0.55, 0.22, YarnRunCatalog.SegmentLength - 2),
			CFrame.new(origin() + Vector3.new(x, if kind == "bridge" and math.abs(x) < 1 then 1.2 else 0.75, z0 + YarnRunCatalog.SegmentLength * 0.5)),
			GOLD,
			{ Material = Enum.Material.Neon, Transparency = dim }
		)
	end
	-- Soft outer rails so the three lanes stay separable on stream.
	part(
		bag,
		"RailOuterL",
		Vector3.new(0.35, 0.55, YarnRunCatalog.SegmentLength - 4),
		CFrame.new(origin() + Vector3.new(-15.2, 1.05, z0 + YarnRunCatalog.SegmentLength * 0.5)),
		PEACH,
		{ Material = Enum.Material.Neon, Transparency = 0.22 }
	)
	part(
		bag,
		"RailOuterR",
		Vector3.new(0.35, 0.55, YarnRunCatalog.SegmentLength - 4),
		CFrame.new(origin() + Vector3.new(15.2, 1.05, z0 + YarnRunCatalog.SegmentLength * 0.5)),
		CORAL,
		{ Material = Enum.Material.Neon, Transparency = 0.22 }
	)
	part(
		bag,
		"LanternL",
		Vector3.new(0.8, 2.4, 0.8),
		CFrame.new(origin() + Vector3.new(-16, 3.4, z0 + 10)),
		PEACH,
		{ Material = Enum.Material.Neon }
	)
	part(
		bag,
		"LanternR",
		Vector3.new(0.8, 2.4, 0.8),
		CFrame.new(origin() + Vector3.new(16, 3.4, z0 + 30)),
		CORAL,
		{ Material = Enum.Material.Neon }
	)
end

local function paintObstacle(bag: Folder, obstacle: YarnRunCatalog.Obstacle)
	if obstacle.kind == "dog" then
		paintDog(bag, obstacle.lane, obstacle.z)
	elseif obstacle.kind == "sign" then
		paintSign(bag, obstacle.lane, obstacle.z)
	elseif obstacle.kind == "yarn" then
		paintYarn(bag, obstacle.lane, obstacle.z)
	elseif obstacle.kind == "roomba" then
		paintRoomba(bag, obstacle.lane, obstacle.z)
	elseif obstacle.kind == "wall" then
		paintWall(bag, obstacle.lane, obstacle.z)
	elseif obstacle.kind == "speed" then
		paintSpeed(bag, obstacle.lane, obstacle.z)
	elseif obstacle.kind == "magnet" then
		paintMagnet(bag, obstacle.lane, obstacle.z)
	elseif obstacle.kind == "shield" then
		paintShield(bag, obstacle.lane, obstacle.z)
	elseif obstacle.kind == "double" then
		paintDouble(bag, obstacle.lane, obstacle.z)
	end
end

local function paintSegment(index: number, kindSeed: number)
	local folder = YarnTrackBuilder.ensure()
	local existing = built[index]
	if existing then
		return
	end
	local bag = Instance.new("Folder")
	bag.Name = `Seg_{index}`
	bag.Parent = folder
	built[index] = bag

	local segment = YarnRunCatalog.segment(kindSeed, index)
	paintFloor(bag, index, segment.kind)
	for _, obstacle in segment.obstacles do
		paintObstacle(bag, obstacle)
	end
end

function YarnTrackBuilder.reset(nextSeed: number)
	seed = nextSeed
	local folder = YarnTrackBuilder.ensure()
	folder:ClearAllChildren()
	table.clear(built)
	pbMarker = nil
end

function YarnTrackBuilder.markBest(meters: number)
	local folder = YarnTrackBuilder.ensure()
	if pbMarker then
		pbMarker:Destroy()
		pbMarker = nil
	end
	if meters < 24 then
		return
	end
	local bag = Instance.new("Folder")
	bag.Name = "PBMarker"
	bag.Parent = folder
	pbMarker = bag
	local z = meters
	local gate = part(bag, "Gate", Vector3.new(28, 0.7, 0.7), CFrame.new(origin() + Vector3.new(0, 8.4, z)), GOLD, { Material = Enum.Material.Neon })
	part(bag, "PostL", Vector3.new(0.7, 9, 0.7), CFrame.new(origin() + Vector3.new(-14, 4.5, z)), GOLD, { Material = Enum.Material.Neon })
	part(bag, "PostR", Vector3.new(0.7, 9, 0.7), CFrame.new(origin() + Vector3.new(14, 4.5, z)), GOLD, { Material = Enum.Material.Neon })
	labelOn(gate, `PB {meters}m`, GOLD)
end

function YarnTrackBuilder.sync(z: number, kindSeed: number?)
	local useSeed = kindSeed or seed
	local start = math.max(0, math.floor(z / YarnRunCatalog.SegmentLength) - 1)
	local last = start + 8
	for index = start, last do
		paintSegment(index, useSeed)
	end
	for index, bag in built do
		if index < start - 1 or index > last + 1 then
			bag:Destroy()
			built[index] = nil
		end
	end
end

function YarnTrackBuilder.startCFrame(): CFrame
	local at = YarnTrackBuilder.world(1, 3.2, 4)
	return CFrame.lookAt(at, at + Vector3.new(0, 0, 8))
end

return YarnTrackBuilder
