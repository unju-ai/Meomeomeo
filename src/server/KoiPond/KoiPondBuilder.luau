--!strict

-- Night-market canal. Engine Parts only — lanterns, lily pads, loaf-koi.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local KoiPondBuilder = {}

local INDIGO = Color3.fromRGB(28, 36, 58)
local WATER = Color3.fromRGB(62, 118, 132)
local WOOD = Color3.fromRGB(92, 58, 42)
local CREAM = Color3.fromRGB(255, 243, 224)
local CORAL = Color3.fromRGB(255, 122, 98)
local PEACH = Color3.fromRGB(255, 184, 140)
local AMBER = Color3.fromRGB(255, 196, 74)
local MINT = Color3.fromRGB(120, 196, 150)
local COBALT = Color3.fromRGB(86, 148, 230)
local STONE = Color3.fromRGB(54, 44, 52)
local INK = Color3.fromRGB(28, 18, 24)

local root: Folder? = nil

local function origin(): Vector3
	return Constants.KoiPondOrigin
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
	gui.Size = UDim2.fromOffset(180, 36)
	gui.StudsOffset = offset or Vector3.new(0, 2.4, 0)
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

local function lantern(parent: Instance, name: string, at: Vector3)
	local pole = part(parent, name .. "Pole", Vector3.new(0.45, 8, 0.45), CFrame.new(at + Vector3.new(0, 4, 0)), INK)
	local lamp = part(parent, name .. "Lamp", Vector3.new(1.6, 1.8, 1.6), CFrame.new(at + Vector3.new(0, 8.2, 0)), AMBER, {
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Brightness = 1.1
	light.Range = 18
	light.Color = AMBER
	light.Parent = lamp
	return pole, lamp
end

function KoiPondBuilder.dockCFrame(): CFrame
	local at = origin() + Vector3.new(0, 3.4, -20)
	return CFrame.lookAt(at, at + Vector3.new(0, 0, 12))
end

function KoiPondBuilder.pondLook(): Vector3
	return origin() + Vector3.new(0, 1.2, 2)
end

function KoiPondBuilder.ensure()
	if root and root.Parent then
		return root
	end
	local existing = Workspace:FindFirstChild(Constants.KoiPondFolderName)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = Constants.KoiPondFolderName
	folder.Parent = Workspace
	root = folder

	local o = origin()
	part(folder, "Water", Vector3.new(52, 0.5, 38), CFrame.new(o + Vector3.new(0, 0.8, 2)), WATER, {
		Material = Enum.Material.Glass,
		Transparency = 0.32,
	})
	part(folder, "Basin", Vector3.new(54, 1.2, 40), CFrame.new(o + Vector3.new(0, 0.1, 2)), INDIGO)
	part(folder, "RimN", Vector3.new(56, 1.6, 2.2), CFrame.new(o + Vector3.new(0, 1.2, 22)), STONE)
	part(folder, "RimS", Vector3.new(56, 1.6, 2.2), CFrame.new(o + Vector3.new(0, 1.2, -18)), STONE)
	part(folder, "RimE", Vector3.new(2.2, 1.6, 38), CFrame.new(o + Vector3.new(27, 1.2, 2)), STONE)
	part(folder, "RimW", Vector3.new(2.2, 1.6, 38), CFrame.new(o + Vector3.new(-27, 1.2, 2)), STONE)

	local dock = part(folder, "Dock", Vector3.new(14, 1.2, 10), CFrame.new(o + Vector3.new(0, 1.6, -22)), WOOD, {
		CanCollide = true,
	})
	part(folder, "Plank", Vector3.new(4, 0.4, 8), CFrame.new(o + Vector3.new(0, 2.1, -16)), Color3.fromRGB(120, 78, 52), {
		CanCollide = true,
	})
	labelOn(dock, "KOI POND", CREAM, Vector3.new(0, 3.2, 0))

	lantern(folder, "L1", o + Vector3.new(-24, 0, -16))
	lantern(folder, "L2", o + Vector3.new(24, 0, -16))
	lantern(folder, "L3", o + Vector3.new(-24, 0, 20))
	lantern(folder, "L4", o + Vector3.new(24, 0, 20))

	local pads = {
		Vector3.new(-8, 1.05, 6),
		Vector3.new(10, 1.05, 10),
		Vector3.new(-14, 1.05, 14),
		Vector3.new(6, 1.05, -2),
		Vector3.new(16, 1.05, 4),
	}
	for i, off in pads do
		part(folder, "Lily" .. i, Vector3.new(3.4, 0.22, 3.4), CFrame.new(o + off), MINT)
	end

	local loafs: { { name: string, offset: Vector3, color: Color3, yaw: number } } = {
		{ name = "DecoCream", offset = Vector3.new(-10, 1.15, 8), color = CREAM, yaw = 4.2 },
		{ name = "DecoPeach", offset = Vector3.new(8, 1.15, 12), color = PEACH, yaw = -20 },
		{ name = "DecoMint", offset = Vector3.new(14, 1.15, 0), color = MINT, yaw = 50 },
		{ name = "DecoCobalt", offset = Vector3.new(-6, 1.15, 16), color = COBALT, yaw = 160 },
		{ name = "DecoCoral", offset = Vector3.new(0, 1.15, 9), color = CORAL, yaw = 90 },
	}
	for _, row in loafs do
		local body = part(
			folder,
			row.name,
			Vector3.new(3.4, 0.7, 1.3),
			CFrame.new(o + row.offset) * CFrame.Angles(0, math.rad(row.yaw), 0),
			row.color
		)
		part(
			folder,
			row.name .. "EarL",
			Vector3.new(0.45, 0.7, 0.35),
			body.CFrame * CFrame.new(-0.7, 0.55, 0.15),
			row.color
		)
		part(
			folder,
			row.name .. "EarR",
			Vector3.new(0.45, 0.7, 0.35),
			body.CFrame * CFrame.new(-0.7, 0.55, -0.15),
			row.color
		)
	end

	local stall = part(folder, "Stall", Vector3.new(6, 4, 2.4), CFrame.new(o + Vector3.new(-18, 3.2, -20)), Color3.fromRGB(70, 42, 48))
	labelOn(stall, "yarn bait", PEACH, Vector3.new(0, 2.6, 0))

	local sessions = Instance.new("Folder")
	sessions.Name = "Sessions"
	sessions.Parent = folder
	return folder
end

function KoiPondBuilder.setBobber(userId: number, mode: "none" | "waiting" | "bite" | "catch", color: Color3?)
	KoiPondBuilder.ensure()
	local folder = root
	if not folder then
		return
	end
	local sessions = folder:FindFirstChild("Sessions")
	if not sessions then
		return
	end
	local name = `P{userId}`
	local existing = sessions:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	if mode == "none" then
		return
	end
	local bag = Instance.new("Folder")
	bag.Name = name
	bag.Parent = sessions
	local o = origin()
	local tint = color or CREAM
	local bob = part(bag, "Bobber", Vector3.new(0.9, 0.9, 0.9), CFrame.new(o + Vector3.new(2.4, 1.35, 6)), tint, {
		Material = Enum.Material.Neon,
	})
	part(bag, "Line", Vector3.new(0.12, 4.2, 0.12), CFrame.new(o + Vector3.new(1.2, 3.4, -6)), CREAM)
	if mode == "bite" or mode == "catch" then
		local fish = part(
			bag,
			"Fish",
			Vector3.new(if mode == "catch" then 4.2 else 2.8, 0.85, 1.2),
			CFrame.new(o + Vector3.new(4.2, if mode == "catch" then 3.4 else 1.2, 7)) * CFrame.Angles(0, math.rad(-25), if mode == "catch" then 0.4 else 0),
			tint,
			{ Material = Enum.Material.SmoothPlastic }
		)
		if mode == "catch" then
			labelOn(fish, "!", tint, Vector3.new(0, 1.6, 0))
		end
	end
	if mode == "waiting" then
		labelOn(bob, "…", CREAM, Vector3.new(0, 1.4, 0))
	end
end

function KoiPondBuilder.clearBobber(userId: number)
	KoiPondBuilder.setBobber(userId, "none")
end

return KoiPondBuilder
