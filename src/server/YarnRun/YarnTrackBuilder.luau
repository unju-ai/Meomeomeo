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

local INDIGO = Color3.fromRGB(36, 24, 48)
local GOLD = Color3.fromRGB(255, 196, 74)
local CORAL = Color3.fromRGB(255, 122, 98)
local PEACH = Color3.fromRGB(255, 184, 140)
local CREAM = Color3.fromRGB(255, 243, 224)
local BROWN = Color3.fromRGB(92, 58, 42)
local INK = Color3.fromRGB(28, 18, 24)

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
	part(parent, "DogBody", Vector3.new(3.2, 2.2, 3.6), CFrame.new(at), BROWN)
	part(parent, "DogHead", Vector3.new(2.2, 1.8, 2.2), CFrame.new(at + Vector3.new(0, 1.4, 1.4)), BROWN)
	part(parent, "EarL", Vector3.new(0.7, 1.2, 0.5), CFrame.new(at + Vector3.new(-0.8, 2.6, 1.3)), Color3.fromRGB(60, 36, 28))
	part(parent, "EarR", Vector3.new(0.7, 1.2, 0.5), CFrame.new(at + Vector3.new(0.8, 2.6, 1.3)), Color3.fromRGB(60, 36, 28))
	part(parent, "Nose", Vector3.new(0.5, 0.4, 0.5), CFrame.new(at + Vector3.new(0, 1.4, 2.4)), INK, { Material = Enum.Material.Neon })
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

	local z0 = index * YarnRunCatalog.SegmentLength
	local mid = origin() + Vector3.new(0, 0, z0 + YarnRunCatalog.SegmentLength * 0.5)
	part(bag, "Floor", Vector3.new(36, 1.2, YarnRunCatalog.SegmentLength), CFrame.new(mid), INDIGO)
	for _, x in YarnRunCatalog.LaneXs do
		part(
			bag,
			"Lane",
			Vector3.new(0.45, 0.2, YarnRunCatalog.SegmentLength - 2),
			CFrame.new(origin() + Vector3.new(x, 0.75, z0 + YarnRunCatalog.SegmentLength * 0.5)),
			GOLD,
			{ Material = Enum.Material.Neon, Transparency = 0.25 }
		)
	end
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

	local segment = YarnRunCatalog.segment(kindSeed, index)
	for i, obstacle in segment.obstacles do
		if obstacle.kind == "dog" then
			paintDog(bag, obstacle.lane, obstacle.z)
		elseif obstacle.kind == "sign" then
			paintSign(bag, obstacle.lane, obstacle.z)
		elseif obstacle.kind == "yarn" then
			paintYarn(bag, obstacle.lane, obstacle.z)
		elseif obstacle.kind == "roomba" then
			paintRoomba(bag, obstacle.lane, obstacle.z)
		end
		local _ = i
	end
end

function YarnTrackBuilder.reset(nextSeed: number)
	seed = nextSeed
	local folder = YarnTrackBuilder.ensure()
	folder:ClearAllChildren()
	table.clear(built)
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
