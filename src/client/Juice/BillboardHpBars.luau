--!strict

-- Client-only night-market HP bars for posts / stalls / yarn core / Canal Levi /
-- lane kittens / jungle camps. Reads Health / MaxHealth (and Vulnerable / InCombat)
-- on the model. Fog + aim rules live in Shared.BillboardHp.

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
	aimedMinionId: string?,
	aimedJungleId: string?,
	jungleVisible: { [string]: boolean }?,
	minionVisible: { [string]: boolean }?,
}

type BarKind = "structure" | "epic" | "kitten" | "camp"

type BarRefs = {
	gui: BillboardGui,
	fill: Frame,
	caption: TextLabel,
	kind: BarKind,
}

local bars: { [BasePart]: BarRefs } = {}

local function rgb(triplet: { number }): Color3
	return Color3.fromRGB(triplet[1], triplet[2], triplet[3])
end

local function ensureBar(adornee: BasePart, kind: BarKind): BarRefs
	local existing = bars[adornee]
	if existing and existing.gui.Parent == adornee and existing.kind == kind then
		return existing
	end
	local old = adornee:FindFirstChild(BillboardHp.GuiName)
	if old then
		old:Destroy()
	end

	local width = 168
	local height = 36
	local trackH = 10
	local captionH = 16
	local offsetY = 4.2
	local maxDist = 110
	if kind == "epic" then
		width = 220
		height = 44
		trackH = 14
		captionH = 20
		offsetY = 2.8
		maxDist = 140
	elseif kind == "kitten" then
		width = 64
		height = 10
		trackH = 8
		captionH = 0
		offsetY = 2.0
		maxDist = 70
	elseif kind == "camp" then
		width = 120
		height = 28
		trackH = 10
		captionH = 14
		offsetY = 2.4
		maxDist = 100
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = BillboardHp.GuiName
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(width, height)
	gui.StudsOffset = Vector3.new(0, adornee.Size.Y / 2 + offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = maxDist
	gui.Enabled = false
	gui.Parent = adornee

	local track = Instance.new("Frame")
	track.Name = BillboardHp.TrackName
	track.BackgroundColor3 = rgb(BillboardHp.Track)
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, 0, 0, trackH)
	track.Position = UDim2.fromOffset(0, if captionH > 0 then captionH + 2 else 0)
	track.Parent = gui
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, if kind == "kitten" then 3 else 4)
	trackCorner.Parent = track
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(BillboardHp.Stroke)
	stroke.Thickness = 1
	stroke.Transparency = if kind == "kitten" then 0.45 else 0.35
	stroke.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = BillboardHp.FillName
	fill.BackgroundColor3 = rgb(BillboardHp.Cream)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, if kind == "kitten" then 3 else 4)
	fillCorner.Parent = fill

	local caption = Instance.new("TextLabel")
	caption.Name = BillboardHp.CaptionName
	caption.BackgroundTransparency = 1
	caption.Size = UDim2.new(1, 0, 0, captionH)
	caption.Position = UDim2.fromOffset(0, 0)
	caption.Font = Enum.Font.FredokaOne
	caption.TextScaled = true
	caption.TextColor3 = rgb(BillboardHp.Cream)
	caption.TextStrokeColor3 = rgb(BillboardHp.Ink)
	caption.TextStrokeTransparency = 0.35
	caption.Text = ""
	caption.Visible = captionH > 0
	caption.Parent = gui

	local refs: BarRefs = { gui = gui, fill = fill, caption = caption, kind = kind }
	bars[adornee] = refs
	return refs
end

local function paint(
	refs: BarRefs,
	health: number,
	maxHealth: number,
	caption: string,
	show: boolean,
	fillRgb: { number }?
)
	local ratio = BillboardHp.ratio(health, maxHealth)
	refs.fill.Size = UDim2.fromScale(ratio, 1)
	local tone = BillboardHp.fillTone(ratio)
	refs.fill.BackgroundColor3 = rgb(if fillRgb then fillRgb else BillboardHp.toneRgb(tone))
	refs.caption.Text = caption
	refs.gui.Enabled = show
end

local function setPlainLabel(part: BasePart, enabled: boolean)
	local label = part:FindFirstChild("Label")
	if label and label:IsA("BillboardGui") then
		label.Enabled = enabled
	end
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
	local refs = ensureBar(part, "structure")
	local title = BillboardHp.structureTitle(tier, lane)
	local hpLine = BillboardHp.formatHp(health, maxHealth)
	paint(refs, health, maxHealth, BillboardHp.structureCaption(title, hpLine, not vulnerable), show)
end

local function syncEpic(part: BasePart, ctx: SyncCtx)
	local health, maxHealth, alive = readHp(part)
	local inVision = ctx.jungleVisible ~= nil and ctx.jungleVisible[RiverEpic.Id] == true
	local show = ctx.active and BillboardHp.showEpic({ alive = alive, inVision = inVision })
	local refs = ensureBar(part, "epic")
	local hpLine = BillboardHp.formatHp(health, maxHealth)
	paint(refs, health, maxHealth, BillboardHp.epicCaption(RiverEpic.Name, hpLine), show)
	-- Prefer the night-market bar over the plain white nameplate while Levi is up.
	setPlainLabel(part, not show and alive)
end

local function syncKitten(part: BasePart, ctx: SyncCtx): boolean
	local health, maxHealth, alive = readHp(part)
	local teamAttr = part:GetAttribute(Constants.Attributes.Team)
	local team = if teamAttr == "Blue" or teamAttr == "Red" then teamAttr else nil
	local ally = ctx.localTeam ~= nil and team == ctx.localTeam
	local id = part:GetAttribute(Constants.Attributes.MinionId)
	local aimed = typeof(id) == "string" and ctx.aimedMinionId == id
	local inVision = if ally
		then true
		else (typeof(id) == "string" and ctx.minionVisible ~= nil and ctx.minionVisible[id] == true)
	local show = ctx.active
		and BillboardHp.showKitten({
			alive = alive,
			ally = ally == true,
			inVision = inVision,
			damaged = BillboardHp.damaged(health, maxHealth),
			aimed = aimed,
		})
	if not show then
		-- Drop pooled bar when quiet so a full healthy wave does not keep GUIs.
		local existing = bars[part]
		if existing then
			if existing.gui.Parent then
				existing.gui:Destroy()
			end
			bars[part] = nil
		end
		setPlainLabel(part, alive)
		return false
	end
	local refs = ensureBar(part, "kitten")
	local tone = BillboardHp.fillTone(BillboardHp.ratio(health, maxHealth))
	paint(refs, health, maxHealth, "", true, BillboardHp.teamFillRgb(tone, team))
	setPlainLabel(part, false)
	return true
end

local function syncCamp(part: BasePart, ctx: SyncCtx): boolean
	local health, maxHealth, alive = readHp(part)
	local id = part:GetAttribute(Constants.Attributes.JungleId)
	if typeof(id) ~= "string" or id == RiverEpic.Id then
		return false
	end
	local aimed = ctx.aimedJungleId == id
	local inCombat = aimed or part:GetAttribute("InCombat") == true
	local inVision = ctx.jungleVisible ~= nil and ctx.jungleVisible[id] == true
	local show = ctx.active
		and BillboardHp.showCamp({
			alive = alive,
			inVision = inVision,
			damaged = BillboardHp.damaged(health, maxHealth),
			inCombat = inCombat,
		})
	if not show then
		local existing = bars[part]
		if existing then
			if existing.gui.Parent then
				existing.gui:Destroy()
			end
			bars[part] = nil
		end
		setPlainLabel(part, alive)
		return false
	end
	local refs = ensureBar(part, "camp")
	local nameAttr = part:GetAttribute("CampName")
	local name = if typeof(nameAttr) == "string" and nameAttr ~= "" then nameAttr else part.Name
	local hpLine = BillboardHp.formatHp(health, maxHealth)
	paint(refs, health, maxHealth, BillboardHp.campCaption(name, hpLine), true)
	setPlainLabel(part, false)
	return true
end

function BillboardHpBars.clear()
	for part, refs in bars do
		if refs.gui.Parent then
			refs.gui:Destroy()
		end
		setPlainLabel(part, true)
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
	local unitBars = 0

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
		for _, child in jungle:GetChildren() do
			if child:IsA("BasePart") and child ~= levi then
				if typeof(child:GetAttribute(Constants.Attributes.JungleId)) == "string" then
					if unitBars < BillboardHp.MaxUnitBars then
						if syncCamp(child, ctx) then
							unitBars += 1
							seen[child] = true
						end
					else
						local existing = bars[child]
						if existing then
							if existing.gui.Parent then
								existing.gui:Destroy()
							end
							bars[child] = nil
							setPlainLabel(child, true)
						end
					end
				end
			end
		end
	end

	local minions = map:FindFirstChild("Minions")
	if minions then
		for _, child in minions:GetChildren() do
			if child:IsA("BasePart") and typeof(child:GetAttribute(Constants.Attributes.MinionId)) == "string" then
				if unitBars < BillboardHp.MaxUnitBars then
					if syncKitten(child, ctx) then
						unitBars += 1
						seen[child] = true
					end
				else
					local existing = bars[child]
					if existing then
						if existing.gui.Parent then
							existing.gui:Destroy()
						end
						bars[child] = nil
						setPlainLabel(child, true)
					end
				end
			end
		end
	end

	for part, refs in bars do
		if not seen[part] then
			if refs.gui.Parent then
				refs.gui:Destroy()
			end
			setPlainLabel(part, true)
			table.insert(stale, part)
		end
	end
	for _, part in stale do
		bars[part] = nil
	end
end

return BillboardHpBars
