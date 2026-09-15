--!strict

-- Night-market tape stall. Neon tickers + yarn bags — not a Bloomberg pit.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArcadeCatalog = require(Shared:WaitForChild("ArcadeCatalog"))
local Constants = require(Shared:WaitForChild("Constants"))

local ArcadeBuilder = {}

local INDIGO = Color3.fromRGB(28, 22, 42)
local WOOD = Color3.fromRGB(92, 58, 42)
local CREAM = Color3.fromRGB(255, 243, 224)
local CORAL = Color3.fromRGB(255, 122, 98)
local PEACH = Color3.fromRGB(255, 184, 140)
local AMBER = Color3.fromRGB(255, 196, 74)
local MINT = Color3.fromRGB(120, 196, 150)
local INK = Color3.fromRGB(22, 16, 28)

local root: Folder? = nil
local tapeLabels: { [string]: TextLabel } = {}
local bannerLabel: TextLabel? = nil

local function origin(): Vector3
	return Constants.MemeArcadeOrigin
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

local function labelOn(host: BasePart, text: string, color: Color3, offset: Vector3?, size: Vector2?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(if size then size.X else 200, if size then size.Y else 36)
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
	return lab
end

function ArcadeBuilder.origin(): Vector3
	return origin()
end

function ArcadeBuilder.lookAt(): Vector3
	return origin() + Vector3.new(0, 5.2, -8)
end

function ArcadeBuilder.counterCFrame(): CFrame
	local at = origin() + Vector3.new(0, 3.6, 11)
	return CFrame.lookAt(at, origin() + Vector3.new(0, 4.2, -8))
end

function ArcadeBuilder.ensure()
	if root and root.Parent then
		return root
	end
	local existing = Workspace:FindFirstChild(Constants.MemeArcadeFolderName)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = Constants.MemeArcadeFolderName
	folder.Parent = Workspace
	root = folder
	tapeLabels = {}
	bannerLabel = nil

	local o = origin()
	part(folder, "Floor", Vector3.new(36, 1.2, 28), CFrame.new(o), WOOD, { CanCollide = true })
	part(folder, "Rug", Vector3.new(22, 0.18, 16), CFrame.new(o + Vector3.new(0, 0.7, 4)), INDIGO)
	part(folder, "WallN", Vector3.new(36, 14, 1.2), CFrame.new(o + Vector3.new(0, 7.2, -13.4)), INK, { CanCollide = true })
	part(folder, "WallE", Vector3.new(1.2, 8, 26), CFrame.new(o + Vector3.new(17.4, 4.4, 0)), INK, { CanCollide = true })
	part(folder, "WallW", Vector3.new(1.2, 8, 26), CFrame.new(o + Vector3.new(-17.4, 4.4, 0)), INK, { CanCollide = true })

	local counter = part(folder, "Counter", Vector3.new(18, 2.4, 3.2), CFrame.new(o + Vector3.new(0, 1.8, 8.4)), Color3.fromRGB(70, 42, 48), {
		CanCollide = true,
	})
	labelOn(counter, "yarn tap", PEACH, Vector3.new(0, 2.2, 0))

	local pad = part(folder, "Pad", Vector3.new(6, 0.4, 6), CFrame.new(o + Vector3.new(0, 1.0, 11.2)), CREAM, {
		CanCollide = true,
	})
	labelOn(pad, "stand here", AMBER, Vector3.new(0, 1.6, 0), Vector2.new(160, 28))

	local sign = part(folder, "Banner", Vector3.new(16, 2.6, 0.5), CFrame.new(o + Vector3.new(0, 12.4, -12.6)), AMBER, {
		Material = Enum.Material.Neon,
	})
	bannerLabel = labelOn(sign, "MEME ARCADE", CREAM, Vector3.new(0, 0.15, 0), Vector2.new(280, 40))

	local disclaimer = part(folder, "Disclaimer", Vector3.new(14, 1.4, 0.4), CFrame.new(o + Vector3.new(0, 10.4, -12.7)), INDIGO)
	labelOn(disclaimer, ArcadeCatalog.Disclaimer, PEACH, Vector3.new(0, 0.05, 0), Vector2.new(320, 28))

	local defs = ArcadeCatalog.all()
	local span = 22
	for i, def in defs do
		local x = -span / 2 + (i - 0.5) * (span / #defs)
		local panel = part(
			folder,
			"Tape" .. def.id,
			Vector3.new(3.6, 5.2, 0.45),
			CFrame.new(o + Vector3.new(x, 5.6, -12.8)),
			def.color,
			{ Material = Enum.Material.Neon }
		)
		local lab = labelOn(panel, `{def.ticker}  {def.basePrice}`, INK, Vector3.new(0, 0.1, 0), Vector2.new(180, 48))
		lab.TextSize = 18
		tapeLabels[def.id] = lab
		local lamp = part(
			folder,
			"Lamp" .. def.id,
			Vector3.new(0.7, 0.7, 0.7),
			CFrame.new(o + Vector3.new(x, 8.6, -12.2)),
			AMBER,
			{ Material = Enum.Material.Neon }
		)
		local light = Instance.new("PointLight")
		light.Brightness = 0.8
		light.Range = 14
		light.Color = AMBER
		light.Parent = lamp
	end

	local bags = {
		Vector3.new(-10, 1.7, 6),
		Vector3.new(10, 1.7, 6),
		Vector3.new(-7, 1.5, 12),
		Vector3.new(7, 1.5, 12),
	}
	for i, off in bags do
		local bag = part(folder, "Yarn" .. i, Vector3.new(2.2, 2.2, 2.2), CFrame.new(o + off), if i % 2 == 0 then CORAL else MINT, {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Neon,
		})
		labelOn(bag, "yarn", CREAM, Vector3.new(0, 1.6, 0), Vector2.new(80, 24))
	end

	return folder
end

function ArcadeBuilder.setTape(
	rows: { { id: string, ticker: string, price: number, change: number, eventKind: string } },
	banner: string
)
	ArcadeBuilder.ensure()
	for _, row in rows do
		local lab = tapeLabels[row.id]
		if lab then
			local arrow = if row.change >= 0 then "▲" else "▼"
			lab.Text = `{row.ticker}  {row.price}  {arrow}`
			if row.eventKind == "rug" then
				lab.TextColor3 = CORAL
			elseif row.eventKind == "moon" then
				lab.TextColor3 = MINT
			elseif row.change >= 0 then
				lab.TextColor3 = INK
			else
				lab.TextColor3 = Color3.fromRGB(90, 32, 40)
			end
		end
	end
	if bannerLabel then
		bannerLabel.Text = if banner ~= "" then banner else "MEME ARCADE"
		if string.find(banner, "RUG", 1, true) then
			bannerLabel.TextColor3 = CORAL
		elseif string.find(banner, "MOON", 1, true) then
			bannerLabel.TextColor3 = MINT
		else
			bannerLabel.TextColor3 = CREAM
		end
	end
end

function ArcadeBuilder.destroy()
	if root then
		root:Destroy()
	end
	root = nil
	tapeLabels = {}
	bannerLabel = nil
end

return ArcadeBuilder
