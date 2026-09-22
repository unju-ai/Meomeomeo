--!strict

-- Stream-readable Yarn Run chrome: giant score, loud power chips, PB, funny fail card.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Theme)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local YarnRunCatalog = require(Shared:WaitForChild("YarnRunCatalog"))

local YarnRunHud = {}

export type YarnHudApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (snap: Types.YarnRunSnapshot) -> (),
	onRetry: (() -> ()) -> (),
	onHub: (() -> ()) -> (),
	onBoard: (() -> ()) -> (),
}

local POWER_ORDER: { YarnRunCatalog.PowerId } = { "speed", "magnet", "shield", "double" }

local function chipColor(kind: YarnRunCatalog.PowerId): Color3
	local r, g, b = YarnRunCatalog.powerRgb(kind)
	return Color3.fromRGB(r, g, b)
end

local function chip(parent: Instance, kind: YarnRunCatalog.PowerId, order: number): TextLabel
	local label = Theme.text(parent, kind, YarnRunCatalog.powerChipLabel(kind), 20, Theme.ink, Theme.fontTitle)
	label.BackgroundColor3 = chipColor(kind)
	label.BackgroundTransparency = 0.02
	label.Size = UDim2.fromOffset(108, 44)
	label.LayoutOrder = order
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextStrokeTransparency = 0.55
	label.Visible = false
	Theme.corner(label, 12)
	Theme.stroke(label, Theme.foam, 3, 0.18)
	return label
end

local function pulseChip(label: TextLabel)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	label.Size = UDim2.fromOffset(124, 52)
	label.TextSize = 24
	if stroke then
		stroke.Thickness = 5
		stroke.Transparency = 0
	end
	TweenService:Create(label, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(108, 44),
		TextSize = 20,
	}):Play()
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.28), { Thickness = 3, Transparency = 0.18 }):Play()
	end
end

function YarnRunHud.create(parent: Instance): YarnHudApi
	local root = Instance.new("Frame")
	root.Name = "YarnRunHud"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = parent

	local tint = Instance.new("Frame")
	tint.Name = "PowerTint"
	tint.BackgroundColor3 = Color3.fromRGB(90, 220, 255)
	tint.BackgroundTransparency = 1
	tint.BorderSizePixel = 0
	tint.Size = UDim2.fromScale(1, 1)
	tint.ZIndex = 0
	tint.Parent = root

	local score = Theme.text(root, "Score", "0", 56, Theme.amber, Theme.fontTitle)
	score.AnchorPoint = Vector2.new(0.5, 0)
	score.Position = UDim2.new(0.5, 0, 0, 72)
	score.Size = UDim2.fromOffset(420, 62)
	score.TextXAlignment = Enum.TextXAlignment.Center
	score.TextStrokeTransparency = 0.3
	score.ZIndex = 2

	local combo = Theme.text(root, "Combo", "", 26, Theme.coral, Theme.fontTitle)
	combo.AnchorPoint = Vector2.new(0.5, 0)
	combo.Position = UDim2.new(0.5, 0, 0, 132)
	combo.Size = UDim2.fromOffset(320, 30)
	combo.TextXAlignment = Enum.TextXAlignment.Center
	combo.TextStrokeTransparency = 0.35
	combo.ZIndex = 2

	local meta = Theme.text(root, "Meta", "0m  ·  best 0", 14, Theme.cream, Theme.fontMono)
	meta.AnchorPoint = Vector2.new(0.5, 0)
	meta.Position = UDim2.new(0.5, 0, 0, 162)
	meta.Size = UDim2.fromOffset(420, 18)
	meta.TextXAlignment = Enum.TextXAlignment.Center
	meta.ZIndex = 2

	local day = Theme.text(root, "Day", "", 13, Theme.peach, Theme.fontMono)
	day.AnchorPoint = Vector2.new(0.5, 0)
	day.Position = UDim2.new(0.5, 0, 0, 180)
	day.Size = UDim2.fromOffset(360, 16)
	day.TextXAlignment = Enum.TextXAlignment.Center
	day.ZIndex = 2

	local powers = Instance.new("Frame")
	powers.Name = "Powers"
	powers.BackgroundTransparency = 1
	powers.AnchorPoint = Vector2.new(0.5, 0)
	powers.Position = UDim2.new(0.5, 0, 0, 198)
	powers.Size = UDim2.fromOffset(460, 52)
	powers.ZIndex = 2
	powers.Parent = root
	local layout = Theme.list(powers, 10, Enum.FillDirection.Horizontal)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local chips: { [YarnRunCatalog.PowerId]: TextLabel } = {
		speed = chip(powers, "speed", 1),
		magnet = chip(powers, "magnet", 2),
		shield = chip(powers, "shield", 3),
		double = chip(powers, "double", 4),
	}
	local lastPowers: Types.YarnRunPowers = {
		speed = false,
		magnet = false,
		shield = false,
		double = false,
	}

	local rankChip = Theme.text(root, "DailyRank", "Daily —", 18, Theme.ink, Theme.fontTitle)
	rankChip.AnchorPoint = Vector2.new(1, 0)
	rankChip.Position = UDim2.new(1, -16, 0, 148)
	rankChip.Size = UDim2.fromOffset(168, 36)
	rankChip.BackgroundColor3 = Theme.amber
	rankChip.BackgroundTransparency = 0.08
	rankChip.TextXAlignment = Enum.TextXAlignment.Center
	rankChip.ZIndex = 2
	Theme.corner(rankChip, 10)
	Theme.stroke(rankChip, Theme.foam, 2, 0.3)

	local event = Theme.text(root, "Event", "", 36, Theme.foam, Theme.fontTitle)
	event.AnchorPoint = Vector2.new(0, 0)
	event.Position = UDim2.new(0, 20, 0, 258)
	event.Size = UDim2.fromOffset(520, 44)
	event.TextStrokeTransparency = 0.18
	event.ZIndex = 2

	local hint = Theme.text(root, "Hint", "A / D lanes  ·  Space jump  ·  C slide  ·  chase the ghost", 13, Theme.peach)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -18)
	hint.Size = UDim2.fromOffset(560, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.ZIndex = 2

	local summary = Instance.new("Frame")
	summary.Name = "Summary"
	summary.AnchorPoint = Vector2.new(0.5, 0.5)
	summary.Position = UDim2.fromScale(0.5, 0.55)
	summary.Size = UDim2.fromOffset(460, 392)
	summary.BackgroundColor3 = Theme.panel
	summary.Visible = false
	summary.ZIndex = 3
	summary.Parent = root
	Theme.corner(summary, 20)
	Theme.stroke(summary, Theme.coral, 3, 0.12)
	Theme.pad(summary, 18)

	local fail = Theme.text(summary, "Fail", "Oof", 22, Theme.coral, Theme.fontTitle)
	fail.Size = UDim2.new(1, 0, 0, 28)
	fail.TextXAlignment = Enum.TextXAlignment.Center

	local recap = Theme.text(summary, "Recap", "", 15, Theme.cream)
	recap.Position = UDim2.fromOffset(0, 34)
	recap.Size = UDim2.new(1, 0, 0, 44)
	recap.TextXAlignment = Enum.TextXAlignment.Center

	local pbLine = Theme.text(summary, "PbCompare", "", 17, Theme.amber, Theme.fontTitle)
	pbLine.Position = UDim2.fromOffset(0, 82)
	pbLine.Size = UDim2.new(1, 0, 0, 24)
	pbLine.TextXAlignment = Enum.TextXAlignment.Center
	pbLine.BackgroundColor3 = Theme.panelAlt
	pbLine.BackgroundTransparency = 0.35
	Theme.corner(pbLine, 8)

	local podium = Instance.new("Frame")
	podium.Name = "Podium"
	podium.BackgroundTransparency = 1
	podium.Position = UDim2.fromOffset(90, 118)
	podium.Size = UDim2.fromOffset(260, 56)
	podium.Visible = false
	podium.Parent = summary
	local function step(name: string, x: number, h: number, color: Color3): Frame
		local bar = Instance.new("Frame")
		bar.Name = name
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromOffset(x, 56)
		bar.Size = UDim2.fromOffset(70, h)
		bar.BackgroundColor3 = color
		bar.Parent = podium
		Theme.corner(bar, 8)
		return bar
	end
	step("P2", 8, 36, Theme.peach)
	step("P1", 94, 52, Theme.amber)
	step("P3", 180, 28, Theme.mint)

	local rankLine = Theme.text(summary, "Rank", "", 18, Theme.amber, Theme.fontTitle)
	rankLine.Position = UDim2.fromOffset(0, 182)
	rankLine.Size = UDim2.new(1, 0, 0, 28)
	rankLine.TextXAlignment = Enum.TextXAlignment.Center
	rankLine.BackgroundColor3 = Color3.fromRGB(255, 196, 74)
	rankLine.BackgroundTransparency = 0.82
	rankLine.TextColor3 = Theme.cream
	Theme.corner(rankLine, 10)
	Theme.stroke(rankLine, Theme.amber, 2, 0.35)

	local retry = Theme.button(summary, "Retry", "Retry dash", Theme.amber)
	retry.Position = UDim2.new(0, 0, 1, -88)
	retry.Size = UDim2.new(1, 0, 0, 38)

	local hub = Theme.button(summary, "Hub", "Back to hub", Theme.peach)
	hub.Position = UDim2.new(0, 0, 1, -42)
	hub.Size = UDim2.new(0.48, 0, 0, 36)

	local board = Theme.button(summary, "Board", "Leaderboard", Theme.amber)
	board.Position = UDim2.new(0.52, 0, 1, -42)
	board.Size = UDim2.new(0.48, 0, 0, 36)

	local retryHandler: (() -> ())? = nil
	local hubHandler: (() -> ())? = nil
	local boardHandler: (() -> ())? = nil
	local lastEvent: string? = nil
	local lastCombo = 0

	retry.MouseButton1Click:Connect(function()
		if retryHandler then
			retryHandler()
		end
	end)
	hub.MouseButton1Click:Connect(function()
		if hubHandler then
			hubHandler()
		end
	end)
	board.MouseButton1Click:Connect(function()
		if boardHandler then
			boardHandler()
		end
	end)

	local function applyTint(snap: Types.YarnRunSnapshot)
		local active: YarnRunCatalog.PowerId? = nil
		for _, kind in POWER_ORDER do
			if snap.powers[kind] then
				active = kind
				break
			end
		end
		if active then
			tint.BackgroundColor3 = chipColor(active)
			TweenService:Create(tint, TweenInfo.new(0.14), { BackgroundTransparency = 0.88 }):Play()
		else
			TweenService:Create(tint, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		end
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if not visible then
				summary.Visible = false
				tint.BackgroundTransparency = 1
				lastPowers = { speed = false, magnet = false, shield = false, double = false }
				lastEvent = nil
				lastCombo = 0
			end
		end,
		update = function(snap: Types.YarnRunSnapshot)
			score.Text = tostring(snap.score)
			if snap.combo >= 2 then
				combo.Text = `COMBO x{snap.combo}`
				combo.TextTransparency = 0
				if snap.combo > lastCombo then
					combo.TextSize = 32
					TweenService:Create(combo, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						TextSize = 26,
					}):Play()
				end
			else
				combo.Text = ""
			end
			lastCombo = snap.combo
			local pb = if snap.bestMeters > 0 then `{snap.bestScore} / {snap.bestMeters}m` else tostring(snap.bestScore)
			meta.Text = `{snap.meters}m  ·  yarn {snap.yarn}  ·  PB {pb}`
			day.Text = if snap.dayKey ~= "" then `Daily seed  {snap.dayKey}` else ""
			for _, kind in POWER_ORDER do
				local on = snap.powers[kind]
				local label = chips[kind]
				label.Visible = on
				if on and not lastPowers[kind] then
					pulseChip(label)
				end
				lastPowers[kind] = on
			end
			applyTint(snap)
			event.Text = snap.event or ""
			if snap.dailyRank then
				rankChip.Text = `Daily #{snap.dailyRank}`
				rankChip.Visible = true
			else
				rankChip.Text = "Daily —"
				rankChip.Visible = snap.phase == "Running" or snap.phase == "Dead"
			end
			local powerKind = YarnRunCatalog.isPowerEvent(snap.event)
			if snap.event == "MEGA YARN" or snap.event == "NEW PB" or snap.event == "2X YARN" or snap.event == "#1 YARN LORD" or snap.event == "BEAT YOUR GHOST" then
				event.TextColor3 = Theme.amber
			elseif snap.event == "COMBO BREAK" or snap.event == "CLOSE!" then
				event.TextColor3 = Theme.coral
			elseif powerKind == "shield" or snap.event == "MAGNET ON" or snap.event == "#3 YARN CREW" then
				event.TextColor3 = Theme.mint
			elseif powerKind == "speed" then
				event.TextColor3 = Color3.fromRGB(90, 220, 255)
			elseif powerKind == "magnet" then
				event.TextColor3 = Color3.fromRGB(220, 90, 210)
			else
				event.TextColor3 = Theme.foam
			end
			if snap.event and snap.event ~= lastEvent then
				if snap.event == "CLOSE!" or snap.event == "COMBO BREAK" then
					event.TextSize = 44
					TweenService:Create(event, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						TextSize = 36,
					}):Play()
				elseif powerKind then
					event.TextSize = 42
					TweenService:Create(event, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						TextSize = 36,
					}):Play()
				end
			end
			lastEvent = snap.event
			local dead = snap.phase == "Dead"
			summary.Visible = dead
			if dead then
				local crowned = snap.podium == true
				fail.Text = if crowned and snap.dailyRank == 1
					then "#1 YARN LORD"
					elseif snap.newBest then "NEW PERSONAL BEST"
					else (snap.failReason or "Faceplant")
				fail.TextColor3 = if crowned or snap.newBest then Theme.amber else Theme.coral
				recap.Text = YarnRunCatalog.deathRecapLine(snap.score, snap.yarn, snap.bestCombo, snap.meters)
				pbLine.Text = YarnRunCatalog.pbCompareLine(snap.score, snap.meters, snap.bestScore, snap.bestMeters, snap.newBest)
				pbLine.TextColor3 = if snap.newBest then Theme.amber else Theme.cream
				podium.Visible = crowned
				rankLine.Text = YarnRunCatalog.deathRankLine(snap.dailyRank, snap.weeklyRank, crowned)
				rankLine.TextColor3 = if snap.dailyRank or snap.weeklyRank then Theme.ink else Theme.cream
				rankLine.BackgroundColor3 = if snap.dailyRank or snap.weeklyRank then Theme.amber else Theme.panelAlt
				rankLine.BackgroundTransparency = if snap.dailyRank or snap.weeklyRank then 0.12 else 0.45
			end
		end,
		onRetry = function(fn)
			retryHandler = fn
		end,
		onHub = function(fn)
			hubHandler = fn
		end,
		onBoard = function(fn)
			boardHandler = fn
		end,
	}
end

return YarnRunHud
