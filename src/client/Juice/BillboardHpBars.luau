--!strict

-- Client-only night-market HP bars for posts / stalls / yarn core / Canal Levi.
-- Reads Health / MaxHealth / Vulnerable on the model. Fog + aim rules live in Shared.BillboardHp.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BillboardHp = require(Shared:WaitForChild("BillboardHp"))
local Constants = require(Shared:WaitForChild("Constants"))
local RiverEpic = require(Shared:WaitForChild("RiverEpic"))
local VisionLogic = require(Shared:WaitForChild("VisionLogic"))

local BillboardHpBars = {}

export type SyncCtx = {
	active: boolean,
	localTeam: string?,
	fogBits: { number }?,
	aimedObjectiveId: string?,
	jungleVisible: { [string]: boolean }?,
}

type BarRefs = {
	gui: BillboardGui,
	fill: Frame,
	caption: TextLabel,
}

local bars: { [BasePart]: BarRefs } = {}

local function rgb(triplet: { number }): Color3
	return Color3.fromRGB(triplet[1], triplet[2], triplet[3])
end

local function ensureBar(adornee: BasePart, epic: boolean): BarRefs
	local existing = bars[adornee]
	if existing and existing.gui.Parent == adornee then
		return existing
	end
	local old = adornee:FindFirstChild(BillboardHp.GuiName)
	if old then
		old:Destroy()
	end

	local width = if epic then 220 else 168
	local height = if epic then 44 else 36
	local gui = Instance.new("BillboardGui")
	gui.Name = BillboardHp.GuiName
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(width, height)
	gui.StudsOffset = Vector3.new(0, adornee.Size.Y / 2 + (if epic then 2.8 else 4.2), 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = if epic then 140 else 110
	gui.Enabled = false
	gui.Parent = adornee

	local track = Instance.new("Frame")
	track.Name = BillboardHp.TrackName
	track.BackgroundColor3 = rgb(BillboardHp.Track)
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, 0, 0, if epic then 14 else 10)
	track.Position = UDim2.fromOffset(0, if epic then 22 else 18)
	track.Parent = gui
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 4)
	trackCorner.Parent = track
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(BillboardHp.Stroke)
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = BillboardHp.FillName
	fill.BackgroundColor3 = rgb(BillboardHp.Cream)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local caption = Instance.new("TextLabel")
	caption.Name = BillboardHp.CaptionName
	caption.BackgroundTransparency = 1
	caption.Size = UDim2.new(1, 0, 0, if epic then 20 else 16)
	caption.Position = UDim2.fromOffset(0, 0)
	caption.Font = Enum.Font.FredokaOne
	caption.TextScaled = true
	caption.TextColor3 = rgb(BillboardHp.Cream)
	caption.TextStrokeColor3 = rgb(BillboardHp.Ink)
	caption.TextStrokeTransparency = 0.35
	caption.Text = ""
	caption.Parent = gui

	local refs: BarRefs = { gui = gui, fill = fill, caption = caption }
	bars[adornee] = refs
	return refs
end

local function paint(refs: BarRefs, health: number, maxHealth: number, caption: string, show: boolean)
	local ratio = BillboardHp.ratio(health, maxHealth)
	refs.fill.Size = UDim2.fromScale(ratio, 1)
	refs.fill.BackgroundColor3 = rgb(BillboardHp.toneRgb(BillboardHp.fillTone(ratio)))
	refs.caption.Text = caption
	refs.gui.Enabled = show
end

local function fogLit(fogBits: { number }?, x: number, z: number): boolean
	if fogBits == nil or #fogBits == 0 then
		return true
	end
	return VisionLogic.bitOn(fogBits, VisionLogic.indexOf(x, z))
end

local function readHp(part: BasePart): (number, number, boolean)
	local healthAttr = part:GetAttribute("Health")
	local maxAttr = part:GetAttribute("MaxHealth")
	local health = if typeof(healthAttr) == "number" then healthAttr else 0
	local maxHealth = if typeof(maxAttr) == "number" then maxAttr else 0
	local alive = health > 0
	return health, maxHealth, alive
end

local function syncStructure(part: BasePart, ctx: SyncCtx)
	local health, maxHealth, alive = readHp(part)
	local team = part:GetAttribute(Constants.Attributes.Team)
	local ally = ctx.localTeam ~= nil and team == ctx.localTeam
	local tierAttr = part:GetAttribute("Tier")
	local laneAttr = part:GetAttribute("Lane")
	local tier = if tierAttr == "Inner" or tierAttr == "Core" or tierAttr == "Outer" then tierAttr else "Outer"
	local lane = if typeof(laneAttr) == "string" then laneAttr else "Mid"
	local vulnerable = part:GetAttribute("Vulnerable") == true
	local id = part:GetAttribute(Constants.Attributes.ObjectiveId)
	local aimed = typeof(id) == "string" and ctx.aimedObjectiveId == id
	local inVision = fogLit(ctx.fogBits, part.Position.X, part.Position.Z)
	local show = ctx.active
		and BillboardHp.showStructure({
			alive = alive,
			ally = ally == true,
			inVision = inVision,
			damaged = BillboardHp.damaged(health, maxHealth),
			aimed = aimed,
		})
	local refs = ensureBar(part, false)
	local title = BillboardHp.structureTitle(tier, lane)
	local hpLine = BillboardHp.formatHp(health, maxHealth)
	paint(refs, health, maxHealth, BillboardHp.structureCaption(title, hpLine, not vulnerable), show)
end

local function syncEpic(part: BasePart, ctx: SyncCtx)
	local health, maxHealth, alive = readHp(part)
	local inVision = ctx.jungleVisible ~= nil and ctx.jungleVisible[RiverEpic.Id] == true
	local show = ctx.active and BillboardHp.showEpic({ alive = alive, inVision = inVision })
	local refs = ensureBar(part, true)
	local hpLine = BillboardHp.formatHp(health, maxHealth)
	paint(refs, health, maxHealth, BillboardHp.epicCaption(RiverEpic.Name, hpLine), show)
	-- Prefer the night-market bar over the plain white nameplate while Levi is up.
	local label = part:FindFirstChild("Label")
	if label and label:IsA("BillboardGui") then
		label.Enabled = not show and alive
	end
end

function BillboardHpBars.clear()
	for part, refs in bars do
		if refs.gui.Parent then
			refs.gui:Destroy()
		end
		local label = part:FindFirstChild("Label")
		if label and label:IsA("BillboardGui") then
			label.Enabled = true
		end
	end
	table.clear(bars)
end

function BillboardHpBars.sync(ctx: SyncCtx)
	if not ctx.active then
		BillboardHpBars.clear()
		return
	end
	local map = Workspace:FindFirstChild(Constants.MapFolderName)
	if not map then
		BillboardHpBars.clear()
		return
	end

	local seen: { [BasePart]: boolean } = {}
	local stale: { BasePart } = {}
	local objectives = map:FindFirstChild("Objectives")
	if objectives then
		for _, child in objectives:GetChildren() do
			if child:IsA("BasePart") and typeof(child:GetAttribute(Constants.Attributes.ObjectiveId)) == "string" then
				syncStructure(child, ctx)
				seen[child] = true
			end
		end
	end

	local jungle = map:FindFirstChild("Jungle")
	if jungle then
		local levi = jungle:FindFirstChild(RiverEpic.Id)
		if levi and levi:IsA("BasePart") then
			syncEpic(levi, ctx)
			seen[levi] = true
		end
	end

	for part, refs in bars do
		if not seen[part] then
			if refs.gui.Parent then
				refs.gui:Destroy()
			end
			local label = part:FindFirstChild("Label")
			if label and label:IsA("BillboardGui") then
				label.Enabled = true
			end
			table.insert(stale, part)
		end
	end
	for _, part in stale do
		bars[part] = nil
	end
end

return BillboardHpBars
