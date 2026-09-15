--!strict

-- Night-market party courtyard. Engine Parts — stalls, pillows, coral yarn.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local YarnPartyCatalog = require(Shared:WaitForChild("YarnPartyCatalog"))

local ChampionAppearance = require(script.Parent.Parent.World.ChampionAppearance)

local YarnPartyBuilder = {}

local INDIGO = Color3.fromRGB(36, 24, 48)
local WOOD = Color3.fromRGB(92, 58, 42)
local CREAM = Color3.fromRGB(255, 243, 224)
local CORAL = Color3.fromRGB(255, 122, 98)
local PEACH = Color3.fromRGB(255, 184, 140)
local AMBER = Color3.fromRGB(255, 196, 74)
local MINT = Color3.fromRGB(120, 196, 150)
local INK = Color3.fromRGB(28, 18, 24)
local PINK = Color3.fromRGB(255, 160, 200)

local root: Folder? = nil
local yarnPart: Part? = nil
local pads: { Part } = {}

local function origin(): Vector3
	return Constants.YarnPartyOrigin
end

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

local function labelOn(host: BasePart, text: string, color: Color3, offset: Vector3?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(200, 36)
	gui.StudsOffset = offset or Vector3.new(0, 2.6, 0)
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

function YarnPartyBuilder.origin(): Vector3
	return origin()
end

function YarnPartyBuilder.lookAt(): Vector3
	return origin() + Vector3.new(0, 1.4, 0)
end

function YarnPartyBuilder.spawnCFrame(index: number): CFrame
	local off = YarnPartyCatalog.spawnOffsets()[math.clamp(index, 1, 4)]
	local at = origin() + off
	return CFrame.lookAt(at, origin() + Vector3.new(0, 3, 0))
end

function YarnPartyBuilder.padWorld(index: number): Vector3
	local off = YarnPartyCatalog.padOffsets()[math.clamp(index, 1, 4)]
	return origin() + off + Vector3.new(0, 1.15, 0)
end

function YarnPartyBuilder.ensure()
	if root and root.Parent then
		return root
	end
	local existing = Workspace:FindFirstChild(Constants.YarnPartyFolderName)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = Constants.YarnPartyFolderName
	folder.Parent = Workspace
	root = folder
	pads = {}
	local o = origin()

	part(folder, "Floor", Vector3.new(42, 1.2, 42), CFrame.new(o), WOOD, { CanCollide = true })
	part(folder, "Rug", Vector3.new(28, 0.2, 28), CFrame.new(o + Vector3.new(0, 0.7, 0)), INDIGO)
	part(folder, "WallN", Vector3.new(44, 4, 1.2), CFrame.new(o + Vector3.new(0, 2.4, 21)), INK, { CanCollide = true })
	part(folder, "WallS", Vector3.new(44, 4, 1.2), CFrame.new(o + Vector3.new(0, 2.4, -21)), INK, { CanCollide = true })
	part(folder, "WallE", Vector3.new(1.2, 4, 42), CFrame.new(o + Vector3.new(21, 2.4, 0)), INK, { CanCollide = true })
	part(folder, "WallW", Vector3.new(1.2, 4, 42), CFrame.new(o + Vector3.new(-21, 2.4, 0)), INK, { CanCollide = true })

	local stallColors = { CORAL, PEACH, AMBER, MINT }
	for i, off in YarnPartyCatalog.padOffsets() do
		local stall = part(
			folder,
			"Stall" .. i,
			Vector3.new(5.2, 3.4, 1.4),
			CFrame.new(o + off + Vector3.new(0, 2.4, if off.Z < 0 then -8 else 8)),
			stallColors[i]
		)
		labelOn(stall, "yarn", CREAM, Vector3.new(0, 2.2, 0))
		local pad = part(
			folder,
			"Pillow" .. i,
			Vector3.new(6.4, 0.55, 6.4),
			CFrame.new(o + off + Vector3.new(0, 1.15, 0)),
			CREAM,
			{ CanCollide = true, Material = Enum.Material.SmoothPlastic }
		)
		table.insert(pads, pad)
		local lamp = part(
			folder,
			"Lamp" .. i,
			Vector3.new(1.2, 1.4, 1.2),
			CFrame.new(o + off + Vector3.new(0, 5.4, if off.Z < 0 then -8 else 8)),
			AMBER,
			{ Material = Enum.Material.Neon }
		)
		local light = Instance.new("PointLight")
		light.Brightness = 0.9
		light.Range = 16
		light.Color = AMBER
		light.Parent = lamp
	end

	local sign = part(folder, "Banner", Vector3.new(14, 2.4, 0.6), CFrame.new(o + Vector3.new(0, 8.2, -20.4)), PINK, {
		Material = Enum.Material.Neon,
	})
	labelOn(sign, "YARN PARTY", CREAM, Vector3.new(0, 0.2, 0))

	yarnPart = part(folder, "YarnBall", Vector3.new(3.6, 3.6, 3.6), CFrame.new(o + Vector3.new(0, 2.6, 0)), CORAL, {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
	})
	labelOn(yarnPart, "yarn", PEACH, Vector3.new(0, 2.2, 0))

	local bots = Instance.new("Folder")
	bots.Name = "Bots"
	bots.Parent = folder
	return folder
end

function YarnPartyBuilder.setYarn(world: Vector3)
	YarnPartyBuilder.ensure()
	if yarnPart then
		yarnPart.CFrame = CFrame.new(world)
		yarnPart.Transparency = 0
	end
end

function YarnPartyBuilder.hideYarn()
	if yarnPart then
		yarnPart.Transparency = 1
	end
end

function YarnPartyBuilder.setPads(safe: { boolean }, freeze: boolean)
	YarnPartyBuilder.ensure()
	for i, pad in pads do
		if freeze and safe[i] == true then
			pad.Color = MINT
			pad.Material = Enum.Material.Neon
		elseif freeze then
			pad.Color = INK
			pad.Material = Enum.Material.SmoothPlastic
		else
			pad.Color = CREAM
			pad.Material = Enum.Material.SmoothPlastic
		end
	end
end

local function weld(partA: BasePart, rootPart: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = rootPart
	w.Part1 = partA
	w.Parent = partA
end

function YarnPartyBuilder.spawnBot(userId: number, name: string, championId: string, at: CFrame): Model
	YarnPartyBuilder.ensure()
	local folder = root and root:FindFirstChild("Bots")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Bots"
		folder.Parent = root
	end
	local existing = folder:FindFirstChild(`Bot{userId}`)
	if existing then
		existing:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = `Bot{userId}`
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.Color = PEACH
	rootPart.Anchored = true
	rootPart.CanCollide = true
	rootPart.CFrame = at
	rootPart.Parent = model
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.1, 2.2, 1.2)
	torso.Color = PEACH
	torso.Anchored = false
	torso.CanCollide = false
	torso.Massless = true
	torso.CFrame = at * CFrame.new(0, 0.1, 0)
	torso.Parent = model
	weld(torso, rootPart)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.Color = CREAM
	head.Anchored = false
	head.CanCollide = false
	head.Massless = true
	head.CFrame = at * CFrame.new(0, 1.7, 0)
	head.Parent = model
	weld(head, rootPart)
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.WalkSpeed = YarnPartyCatalog.WalkSpeed
	humanoid.Parent = model
	model.PrimaryPart = rootPart
	model:SetAttribute(Constants.Attributes.UserId, userId)
	model:SetAttribute(Constants.Attributes.ChampionId, championId)
	model.Parent = folder
	ChampionAppearance.apply(model, {
		championId = championId,
		team = "Blue",
		displayName = `{name} (Bot)`,
		isBot = true,
	})
	return model
end

function YarnPartyBuilder.clearBots()
	if not root then
		return
	end
	local folder = root:FindFirstChild("Bots")
	if folder then
		folder:ClearAllChildren()
	end
end

function YarnPartyBuilder.destroy()
	YarnPartyBuilder.clearBots()
	if root then
		root:Destroy()
	end
	root = nil
	yarnPart = nil
	pads = {}
end

return YarnPartyBuilder
