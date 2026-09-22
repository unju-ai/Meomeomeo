--!strict

-- Cat Rift kill feed: short stack of night-market chips under the Kitty Caster banner.
-- Push API and combat copy are unchanged; plates + fade are presentation only.

local Players = game:GetService("Players")

local KillFeedPaint = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KillFeedPaint"))
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local KillFeed = {}

export type FeedApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	push: (event: Types.FeedEvent) -> (),
}

local function color3(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function localNames(): { string }
	local player = Players.LocalPlayer
	local names: { string } = {}
	if player then
		if player.DisplayName ~= "" then
			table.insert(names, player.DisplayName)
		end
		if player.Name ~= "" and player.Name ~= player.DisplayName then
			table.insert(names, player.Name)
		end
	end
	return names
end

type RowUi = {
	frame: Frame,
	stroke: UIStroke,
	label: TextLabel,
}

function KillFeed.create(parent: Instance): FeedApi
	local maxRows = KillFeedPaint.MaxRows
	local rowH = KillFeedPaint.RowHeight
	local gap = KillFeedPaint.RowGap
	local stackH = maxRows * rowH + (maxRows - 1) * gap

	local root = Instance.new("Frame")
	root.Name = "KillFeed"
	root.AnchorPoint = Vector2.new(0.5, 0)
	-- Sit under the banner band; leave a clear gap above the meme tape (Y≈130).
	root.Position = UDim2.new(0.5, 0, 0, 36)
	root.Size = UDim2.fromOffset(520, stackH)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.ZIndex = 5
	root.ClipsDescendants = false
	root.Parent = parent
	local layout = Theme.list(root, gap)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top

	local rows: { RowUi } = {}
	for i = 1, maxRows do
		local frame = Instance.new("Frame")
		frame.Name = `R{i}`
		frame.Size = UDim2.new(1, 0, 0, rowH)
		frame.BackgroundColor3 = Theme.panel
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.LayoutOrder = i
		frame.ZIndex = 5
		frame.Parent = root
		Theme.corner(frame, 8)
		local stroke = Theme.stroke(frame, Theme.cream, 1, 1)
		stroke.Enabled = false

		local label = Theme.text(frame, "Line", "", 13, Theme.cream, Theme.fontBody)
		label.Size = UDim2.new(1, -16, 1, 0)
		label.Position = UDim2.fromOffset(8, 0)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextStrokeTransparency = 0.5
		label.TextStrokeColor3 = Theme.ink
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.TextWrapped = false
		label.ZIndex = 6
		label.Parent = frame

		table.insert(rows, { frame = frame, stroke = stroke, label = label })
	end

	local lines: { Types.FeedEvent } = {}

	local function paint()
		local names = localNames()
		for i, row in rows do
			local event = lines[i]
			if event then
				local plateKind = KillFeedPaint.resolveKind(event.kind, event.text)
				local involvement = KillFeedPaint.involvement(event.kind, event.text, names)
				local plate = KillFeedPaint.plate(plateKind, involvement, i)
				row.frame.Visible = true
				row.frame.BackgroundColor3 = color3(plate.fill)
				row.frame.BackgroundTransparency = plate.fillAlpha
				row.stroke.Enabled = true
				row.stroke.Color = color3(plate.stroke)
				row.stroke.Transparency = plate.strokeAlpha
				row.stroke.Thickness = if plate.bold then 1.5 else 1
				row.label.Text = event.text
				row.label.TextColor3 = color3(plate.text)
				row.label.TextTransparency = plate.textAlpha
				row.label.Font = if plate.bold then Theme.fontMono else Theme.fontBody
				row.label.TextSize = if plate.bold then 13 else 12
			else
				row.frame.Visible = false
				row.stroke.Enabled = false
			end
		end
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if not visible then
				table.clear(lines)
				paint()
			end
		end,
		push = function(event: Types.FeedEvent)
			table.insert(lines, 1, event)
			while #lines > maxRows do
				table.remove(lines)
			end
			paint()
			local plateKind = KillFeedPaint.resolveKind(event.kind, event.text)
			local hold = KillFeedPaint.holdSeconds(plateKind)
			task.delay(hold, function()
				local index = table.find(lines, event)
				if index then
					table.remove(lines, index)
					paint()
				end
			end)
		end,
	}
end

return KillFeed
