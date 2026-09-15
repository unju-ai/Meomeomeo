--!strict

-- Lantern-rail QTE + stall log. Cream window, not a generic fishing meter.

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

	local meta = Theme.text(root, "Meta", "best catch —", 14, Theme.cream, Theme.fontMono)
	meta.AnchorPoint = Vector2.new(0.5, 0)
	meta.Position = UDim2.new(0.5, 0, 0, 166)
	meta.Size = UDim2.fromOffset(480, 18)
	meta.TextXAlignment = Enum.TextXAlignment.Center

	local day = Theme.text(root, "Day", "", 13, Theme.peach, Theme.fontMono)
	day.AnchorPoint = Vector2.new(0.5, 0)
	day.Position = UDim2.new(0.5, 0, 0, 184)
	day.Size = UDim2.fromOffset(360, 16)
	day.TextXAlignment = Enum.TextXAlignment.Center

	local rail = Instance.new("Frame")
	rail.Name = "Rail"
	rail.AnchorPoint = Vector2.new(0.5, 0)
	rail.Position = UDim2.new(0.5, 0, 0, 214)
	rail.Size = UDim2.fromOffset(420, 28)
	rail.BackgroundColor3 = Theme.panelAlt
	rail.Visible = false
	rail.Parent = root
	Theme.corner(rail, 10)
	Theme.stroke(rail, Theme.amber, 2, 0.25)

	local window = Instance.new("Frame")
	window.Name = "Cream"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.28, 0.72)
	window.BackgroundColor3 = Theme.cream
	window.BackgroundTransparency = 0.12
	window.Parent = rail
	Theme.corner(window, 8)

	local marker = Instance.new("Frame")
	marker.Name = "Loaf"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0, 0.5)
	marker.Size = UDim2.fromOffset(18, 22)
	marker.BackgroundColor3 = Theme.coral
	marker.Parent = rail
	Theme.corner(marker, 6)
	Theme.stroke(marker, Theme.foam, 2, 0.2)

	local pop = Theme.text(root, "Pop", "", 42, Theme.coral, Theme.fontTitle)
	pop.AnchorPoint = Vector2.new(0.5, 0)
	pop.Position = UDim2.new(0.5, 0, 0.42, 0)
	pop.Size = UDim2.fromOffset(640, 52)
	pop.TextXAlignment = Enum.TextXAlignment.Center
	pop.TextStrokeTransparency = 0.25

	local hint = Theme.text(root, "Hint", "Space / Click  ·  cast  ·  reel in the cream window", 13, Theme.peach)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -18)
	hint.Size = UDim2.fromOffset(560, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Center

	local log = Instance.new("Frame")
	log.Name = "Log"
	log.AnchorPoint = Vector2.new(1, 0)
	log.Position = UDim2.new(1, -16, 0, 148)
	log.Size = UDim2.fromOffset(220, 280)
	log.BackgroundColor3 = Theme.panel
	log.Parent = root
	Theme.corner(log, 14)
	Theme.stroke(log, Theme.mint, 2, 0.35)
	Theme.pad(log, 10)

	local logTitle = Theme.text(log, "Title", "Stall log", 16, Theme.mint, Theme.fontTitle)
	logTitle.Size = UDim2.new(1, 0, 0, 20)

	local logList = Instance.new("Frame")
	logList.Name = "Rows"
	logList.BackgroundTransparency = 1
	logList.Position = UDim2.fromOffset(0, 24)
	logList.Size = UDim2.new(1, 0, 1, -24)
	logList.Parent = log
	Theme.list(logList, 4)

	local hub = Theme.button(root, "Hub", "Back to hub", Theme.peach)
	hub.AnchorPoint = Vector2.new(0, 1)
	hub.Position = UDim2.new(0, 18, 1, -18)
	hub.Size = UDim2.fromOffset(148, 36)

	local board = Theme.button(root, "Board", "Board", Theme.amber)
	board.AnchorPoint = Vector2.new(0, 1)
	board.Position = UDim2.new(0, 176, 1, -18)
	board.Size = UDim2.fromOffset(110, 36)

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

	local function paintLog(rows: { Types.KoiLogRow })
		for _, child in logList:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		if #rows == 0 then
			local empty = Theme.text(logList, "Empty", "No loafs yet", 12, Theme.muted)
			empty.Size = UDim2.new(1, 0, 0, 18)
			return
		end
		for i, row in rows do
			local tint = KoiCatalog.rarityTint(row.rarity)
			local line = Theme.text(logList, "Row" .. i, `{row.count}×  {row.name}`, 13, tint, Theme.fontMono)
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
			local pb = if snap.pb > 0 then `  ·  PB catch {snap.pb}` else ""
			local rank = if snap.dailyRank then `  ·  Daily #{snap.dailyRank}` else ""
			if snap.bestCatchName ~= "" then
				meta.Text = `best  {snap.bestCatchName}  {snap.bestCatchScore}{pb}{rank}`
			else
				meta.Text = `best catch —{pb}{rank}`
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
				event.TextColor3 = Theme.blue
			elseif snap.missReason then
				event.TextColor3 = Theme.peach
			else
				event.TextColor3 = Theme.foam
			end
			rail.Visible = snap.phase == "Bite"
			if snap.phase == "Bite" then
				local half = snap.sweetHalf or 0.12
				window.Size = UDim2.fromScale(math.clamp(half * 2, 0.08, 0.4), 0.72)
				marker.Position = UDim2.fromScale(math.clamp(snap.bar or 0, 0, 1), 0.5)
			end
			if snap.phase == "Reveal" and snap.lastCatchName then
				pop.Text = if snap.ticker then "LEGENDARY KOI" else snap.lastCatchName
				pop.TextColor3 = KoiCatalog.rarityTint(KoiCatalog.parseRarity(snap.lastCatchRarity or "Common"))
			elseif snap.phase == "Reveal" and snap.missReason then
				pop.Text = snap.missReason
				pop.TextColor3 = Theme.peach
			else
				pop.Text = ""
			end
			paintLog(snap.caught)
			if snap.phase == "Bite" then
				hint.Text = "Space / Click  ·  reel when the loaf hits cream"
			elseif snap.phase == "Waiting" then
				hint.Text = "Don't yank yet  ·  extra press spooked the canal"
			else
				hint.Text = "Space / Click  ·  cast  ·  reel in the cream window"
			end
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
