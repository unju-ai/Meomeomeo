--!strict

-- Client-only keybind overlay. Toggle with ? or hold H. No remotes.

local Theme = require(script.Parent.Parent.Theme)

local HelpPanel = {}

export type HelpApi = {
	root: Frame,
	button: TextButton,
	setHeld: (held: boolean) -> (),
	toggle: () -> (),
	setVisible: (visible: boolean) -> (),
	isOpen: () -> boolean,
}

local LINES: { { string } } = {
	{ "LMB", "Lock auto-attack on an enemy / minion / tower" },
	{ "X + click", "Attack-move (walk and auto-acquire)" },
	{ "S", "Stop attack · cancel recall orders" },
	{ "Q W E R", "Abilities · hold line/dash, release to fire" },
	{ "4", "Trinket ward (free, one live)" },
	{ "5", "Whisker Lens (buy at Pawmart first)" },
	{ "B", "Pawmart at fountain — not recall" },
	{ "F", "Recall 7s to fountain (damage cancels)" },
	{ "T", "Hold emote wheel · release or click" },
	{ "Tab", "Hold scoreboard" },
	{ "V", "Toggle follow camera" },
	{ "SFX", "Volume / mute (top-right)" },
	{ "H / ?", "This help (hold H or click ?)" },
	{ "Minimap", "Click to ping teammates" },
	{ "Talk", "Fountain / jungle cats" },
	{ "Practice", "Easy / Normal / Hard (Hard dodges + lens)" },
	{ "Tips", "First Practice cards · replay from lobby" },
}

function HelpPanel.create(parent: Instance): HelpApi
	local pinned = false
	local held = false

	local button = Theme.button(parent, "HelpButton", "?", Theme.mint)
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -76, 0, 96)
	button.Size = UDim2.fromOffset(40, 40)
	button.TextSize = 20
	button.ZIndex = 30

	local root = Instance.new("Frame")
	root.Name = "HelpPanel"
	root.AnchorPoint = Vector2.new(0, 0.5)
	root.Position = UDim2.new(0, 16, 0.48, 0)
	root.Size = UDim2.fromOffset(320, 488)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.ZIndex = 28
	root.Parent = parent
	Theme.corner(root, 18)
	Theme.stroke(root, Theme.mint, 2, 0.18)
	Theme.pad(root, 12)

	local title = Theme.text(root, "Title", "Controls", 20, Theme.mint, Theme.fontTitle)
	title.Size = UDim2.new(1, -28, 0, 24)

	local close = Theme.button(root, "Close", "✕", Theme.coral)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(28, 28)
	close.TextSize = 14

	local sub = Theme.text(root, "Sub", "Hold H or click ?  ·  PLAYTEST.md", 11, Theme.peach)
	sub.Position = UDim2.fromOffset(0, 26)
	sub.Size = UDim2.new(1, 0, 0, 16)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Binds"
	list.BackgroundColor3 = Theme.panelAlt
	list.Position = UDim2.fromOffset(0, 48)
	list.Size = UDim2.new(1, 0, 1, -48)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = root
	Theme.corner(list, 10)
	Theme.pad(list, 8)
	Theme.list(list, 4)

	for i, pair in LINES do
		local row = Instance.new("Frame")
		row.Name = `Bind{i}`
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -4, 0, 22)
		row.LayoutOrder = i
		row.Parent = list

		local key = Theme.text(row, "K", pair[1], 12, Theme.amber, Theme.fontMono)
		key.Size = UDim2.fromOffset(88, 22)
		key.TextWrapped = false

		local desc = Theme.text(row, "D", pair[2], 12, Theme.cream)
		desc.Position = UDim2.fromOffset(92, 0)
		desc.Size = UDim2.new(1, -92, 0, 22)
		desc.TextWrapped = false
		desc.TextTruncate = Enum.TextTruncate.AtEnd
	end

	local function paint()
		root.Visible = pinned or held
		button.BackgroundColor3 = if root.Visible then Theme.good else Theme.mint
	end

	local function setPinned(on: boolean)
		pinned = on
		paint()
	end

	button.MouseButton1Click:Connect(function()
		setPinned(not pinned)
	end)
	close.MouseButton1Click:Connect(function()
		setPinned(false)
	end)

	paint()

	return {
		root = root,
		button = button,
		setHeld = function(on: boolean)
			held = on
			paint()
		end,
		toggle = function()
			setPinned(not pinned)
		end,
		setVisible = function(visible: boolean)
			setPinned(visible)
		end,
		isOpen = function()
			return pinned or held
		end,
	}
end

return HelpPanel
