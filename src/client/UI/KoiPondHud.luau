--!strict

-- Lantern-rail QTE + stall log. Cream window, not a generic fishing meter.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Theme)
local KoiCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KoiCatalog"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local KoiPondHud = {}

export type KoiHudApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (snap: Types.KoiPondSnapshot) -> (),
	onHub: (() -> ()) -> (),
	onBoard: (() -> ()) -> (),
}

function KoiPondHud.create(parent: Instance): KoiHudApi
	local root = Instance.new("Frame")
	root.Name = "KoiPondHud"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = parent

	local score = Theme.text(root, "Score", "0", 56, Theme.amber, Theme.fontTitle)
	score.AnchorPoint = Vector2.new(0.5, 0)
	score.Position = UDim2.new(0.5, 0, 0, 72)
	score.Size = UDim2.fromOffset(420, 62)
	score.TextXAlignment = Enum.TextXAlignment.Center
	score.TextStrokeTransparency = 0.3

	local event = Theme.text(root, "Event", "Toss the yarn bobber", 28, Theme.foam, Theme.fontTitle)
	event.AnchorPoint = Vector2.new(0.5, 0)
	event.Position = UDim2.new(0.5, 0, 0, 132)
	event.Size = UDim2.fromOffset(560, 32)
	event.TextXAlignment = Enum.TextXAlignment.Center
	event.TextStrokeTransparency = 0.3

	local meta = Theme.text(root, "Meta", "Best catch —", 15, Theme.cream, Theme.fontMono)
	meta.AnchorPoint = Vector2.new(0.5, 0)
	meta.Position = UDim2.new(0.5, 0, 0, 166)
	meta.Size = UDim2.fromOffset(520, 18)
	meta.TextXAlignment = Enum.TextXAlignment.Center

	local day = Theme.text(root, "Day", "", 13, Theme.peach, Theme.fontMono)
	day.AnchorPoint = Vector2.new(0.5, 0)
	day.Position = UDim2.new(0.5, 0, 0, 186)
	day.Size = UDim2.fromOffset(360, 16)
	day.TextXAlignment = Enum.TextXAlignment.Center

	local rail = Instance.new("Frame")
	rail.Name = "Rail"
	rail.AnchorPoint = Vector2.new(0.5, 0)
	rail.Position = UDim2.new(0.5, 0, 0, 214)
	rail.Size = UDim2.fromOffset(460, 40)
	rail.BackgroundColor3 = Theme.panelAlt
	rail.Visible = false
	rail.ZIndex = 2
	rail.Parent = root
	Theme.corner(rail, 12)
	local railStroke = Theme.stroke(rail, Theme.cream, 3, 0.08)

	local glow = Instance.new("Frame")
	glow.Name = "LanternGlow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.42, 1.35)
	glow.BackgroundColor3 = Theme.cream
	glow.BackgroundTransparency = 0.55
	glow.ZIndex = 2
	glow.Parent = rail
	Theme.corner(glow, 14)

	local window = Instance.new("Frame")
	window.Name = "Cream"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.28, 0.78)
	window.BackgroundColor3 = Theme.cream
	window.BackgroundTransparency = 0.02
	window.ZIndex = 3
	window.Parent = rail
	Theme.corner(window, 10)
	local creamStroke = Theme.stroke(window, Theme.amber, 3, 0.05)

	local creamTag = Theme.text(window, "CreamTag", "REEL", 14, Theme.ink, Theme.fontTitle)
	creamTag.AnchorPoint = Vector2.new(0.5, 0.5)
	creamTag.Position = UDim2.fromScale(0.5, 0.5)
	creamTag.Size = UDim2.fromScale(1, 1)
	creamTag.TextXAlignment = Enum.TextXAlignment.Center
	creamTag.TextStrokeTransparency = 0.7
	creamTag.ZIndex = 4
	creamTag.BackgroundTransparency = 1

	local marker = Instance.new("Frame")
	marker.Name = "Loaf"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0, 0.5)
	marker.Size = UDim2.fromOffset(22, 28)
	marker.BackgroundColor3 = Theme.coral
	marker.ZIndex = 5
	marker.Parent = rail
	Theme.corner(marker, 7)
	Theme.stroke(marker, Theme.foam, 3, 0.1)

	local reelCue = Theme.text(root, "ReelCue", "REEL THE CREAM", 22, Theme.cream, Theme.fontTitle)
	reelCue.AnchorPoint = Vector2.new(0.5, 0)
	reelCue.Position = UDim2.new(0.5, 0, 0, 258)
	reelCue.Size = UDim2.fromOffset(420, 26)
	reelCue.TextXAlignment = Enum.TextXAlignment.Center
	reelCue.TextStrokeTransparency = 0.25
	reelCue.Visible = false
	reelCue.ZIndex = 3

	local pop = Theme.text(root, "Pop", "", 44, Theme.coral, Theme.fontTitle)
	pop.AnchorPoint = Vector2.new(0.5, 0)
	pop.Position = UDim2.fromScale(0.5, 0.4)
	pop.Size = UDim2.fromOffset(680, 56)
	pop.TextXAlignment = Enum.TextXAlignment.Center
	pop.TextStrokeTransparency = 0.2
	pop.ZIndex = 6

	local popSub = Theme.text(root, "PopSub", "", 18, Theme.cream, Theme.fontMono)
	popSub.AnchorPoint = Vector2.new(0.5, 0)
	popSub.Position = UDim2.new(0.5, 0, 0.4, 52)
	popSub.Size = UDim2.fromOffset(520, 22)
	popSub.TextXAlignment = Enum.TextXAlignment.Center
	popSub.TextStrokeTransparency = 0.35
	popSub.ZIndex = 6

	local hint = Theme.text(root, "Hint", "Space / Click  ·  cast  ·  reel in the cream window", 13, Theme.peach)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -18)
	hint.Size = UDim2.fromOffset(560, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Center

	local log = Instance.new("Frame")
	log.Name = "Log"
	log.AnchorPoint = Vector2.new(1, 0)
	log.Position = UDim2.new(1, -16, 0, 148)
	log.Size = UDim2.fromOffset(248, 300)
	log.BackgroundColor3 = Theme.panel
	log.Parent = root
	Theme.corner(log, 14)
	Theme.stroke(log, Theme.mint, 2, 0.28)
	Theme.pad(log, 10)

	local logTitle = Theme.text(log, "Title", "Stall log", 17, Theme.mint, Theme.fontTitle)
	logTitle.Size = UDim2.new(1, 0, 0, 22)

	local logHint = Theme.text(log, "Hint", "Session · rarity tinted", 11, Theme.peach, Theme.fontMono)
	logHint.Position = UDim2.fromOffset(0, 22)
	logHint.Size = UDim2.new(1, 0, 0, 14)

	local logList = Instance.new("Frame")
	logList.Name = "Rows"
	logList.BackgroundTransparency = 1
	logList.Position = UDim2.fromOffset(0, 40)
	logList.Size = UDim2.new(1, 0, 1, -40)
	logList.Parent = log
	Theme.list(logList, 4)

	local hub = Theme.button(root, "Hub", "Back to hub", Theme.peach)
	hub.AnchorPoint = Vector2.new(0, 1)
	hub.Position = UDim2.new(0, 18, 1, -18)
	hub.Size = UDim2.fromOffset(148, 36)

	local board = Theme.button(root, "Board", "Daily board", Theme.amber)
	board.AnchorPoint = Vector2.new(0, 1)
	board.Position = UDim2.new(0, 176, 1, -18)
	board.Size = UDim2.fromOffset(132, 36)

	local hubHandler: (() -> ())? = nil
	local boardHandler: (() -> ())? = nil
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

	local lastPhase: Types.KoiPondPhase? = nil
	local lastPopKey = ""

	local function pulseRail()
		rail.Size = UDim2.fromOffset(490, 46)
		railStroke.Thickness = 5
		railStroke.Transparency = 0
		glow.BackgroundTransparency = 0.35
		creamStroke.Thickness = 4
		TweenService:Create(rail, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(460, 40),
		}):Play()
		TweenService:Create(railStroke, TweenInfo.new(0.32), { Thickness = 3, Transparency = 0.08 }):Play()
		TweenService:Create(glow, TweenInfo.new(0.4), { BackgroundTransparency = 0.55 }):Play()
		TweenService:Create(creamStroke, TweenInfo.new(0.32), { Thickness = 3 }):Play()
	end

	local function pulsePop()
		pop.TextSize = 36
		TweenService:Create(pop, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			TextSize = if pop.Text == "LEGENDARY KOI" then 52 else 44,
		}):Play()
	end

	local function paintLog(rows: { Types.KoiLogRow })
		for _, child in logList:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		if #rows == 0 then
			local empty = Theme.text(logList, "Empty", "No loafs yet — cast", 12, Theme.muted)
			empty.Size = UDim2.new(1, 0, 0, 18)
			return
		end
		for i, row in rows do
			local tint = KoiCatalog.rarityTint(row.rarity)
			local tag = KoiCatalog.rarityTag(row.rarity)
			local line = Theme.text(logList, "Row" .. i, `{row.count}×  {row.name}  ·  {tag}`, 13, tint, Theme.fontMono)
			line.Size = UDim2.new(1, 0, 0, 18)
			line.LayoutOrder = i
		end
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
		end,
		update = function(snap: Types.KoiPondSnapshot)
			score.Text = tostring(snap.score)
			day.Text = if snap.dayKey ~= "" then `Canal  {snap.dayKey}` else ""
			local pb = if snap.pb > 0 then `  ·  PB {snap.pb}` else ""
			local rank = if snap.dailyRank then `  ·  Daily #{snap.dailyRank}` else ""
			if snap.bestCatchName ~= "" then
				local rarity = KoiCatalog.parseRarity(snap.bestCatchRarity or "Common")
				meta.Text = `Best  {snap.bestCatchName}  ·  {snap.bestCatchScore}  ·  {KoiCatalog.rarityTag(rarity)}{pb}{rank}`
				meta.TextColor3 = KoiCatalog.catchTint(snap.bestCatchName, rarity)
			else
				meta.Text = `Best catch —{pb}{rank}`
				meta.TextColor3 = Theme.cream
			end
			event.Text = snap.event or if snap.phase == "Idle"
				then "Toss the yarn bobber"
				elseif snap.phase == "Waiting" then "Wait for a nibble…"
				elseif snap.phase == "Bite" then "Reel the cream window"
				else ""
			if snap.event == "LEGENDARY KOI" then
				event.TextColor3 = Theme.coral
			elseif snap.lastCatchRarity == "Epic" then
				event.TextColor3 = Theme.amber
			elseif snap.lastCatchRarity == "Rare" then
				event.TextColor3 = KoiCatalog.catchTint(snap.lastCatchName, "Rare")
			elseif snap.lastCatchRarity == "Uncommon" or snap.missReason then
				event.TextColor3 = Theme.peach
			elseif snap.phase == "Bite" then
				event.TextColor3 = Theme.cream
			else
				event.TextColor3 = Theme.foam
			end

			local biting = snap.phase == "Bite"
			rail.Visible = biting
			reelCue.Visible = biting
			if biting then
				local half = snap.sweetHalf or 0.12
				local width = math.clamp(half * 2, 0.1, 0.42)
				window.Size = UDim2.fromScale(width, 0.78)
				glow.Size = UDim2.fromScale(math.clamp(width + 0.14, 0.22, 0.55), 1.35)
				marker.Position = UDim2.fromScale(math.clamp(snap.bar or 0, 0, 1), 0.5)
				local inCream = math.abs((snap.bar or 0) - 0.5) <= half
				marker.BackgroundColor3 = if inCream then Theme.amber else Theme.coral
				creamTag.Text = if inCream then "NOW" else "REEL"
				creamTag.TextColor3 = if inCream then Theme.coral else Theme.ink
				reelCue.Text = if inCream then "HIT CREAM · REEL" else "REEL THE CREAM"
				reelCue.TextColor3 = if inCream then Theme.amber else Theme.cream
				if lastPhase ~= "Bite" then
					pulseRail()
				end
			end

			local popKey = ""
			if snap.phase == "Reveal" and snap.lastCatchName then
				local rarity = KoiCatalog.parseRarity(snap.lastCatchRarity or "Common")
				local tint = KoiCatalog.catchTint(snap.lastCatchName, rarity)
				if snap.ticker then
					pop.Text = "LEGENDARY KOI"
					popSub.Text = `Coral Crown  ·  +{snap.lastCatchScore}  ·  CROWN`
				else
					pop.Text = snap.lastCatchName
					popSub.Text = `+{snap.lastCatchScore}  ·  {KoiCatalog.rarityTag(rarity)}`
				end
				pop.TextColor3 = tint
				popSub.TextColor3 = tint
				popKey = `{snap.lastCatchName}:{snap.lastCatchScore}`
			elseif snap.phase == "Reveal" and snap.missReason then
				pop.Text = snap.missReason
				pop.TextColor3 = Theme.peach
				popSub.Text = "Cast again"
				popSub.TextColor3 = Theme.muted
				popKey = snap.missReason
			else
				pop.Text = ""
				popSub.Text = ""
			end
			if popKey ~= "" and popKey ~= lastPopKey then
				pulsePop()
			end
			lastPopKey = popKey

			paintLog(snap.caught)
			if snap.phase == "Bite" then
				hint.Text = "Space / Click  ·  reel when the loaf hits cream"
			elseif snap.phase == "Waiting" then
				hint.Text = "Don't yank yet  ·  extra press spooked the canal"
			else
				hint.Text = "Space / Click  ·  cast  ·  reel in the cream window"
			end
			lastPhase = snap.phase
		end,
		onHub = function(fn)
			hubHandler = fn
		end,
		onBoard = function(fn)
			boardHandler = fn
		end,
	}
end

return KoiPondHud
