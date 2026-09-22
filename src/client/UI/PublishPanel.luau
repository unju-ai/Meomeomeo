--!strict

-- Compact hub overlay. Paints the server checklist. It never invents
-- PlaceIds: digit runs of 4+ are scrubbed before they can land in a label.

local Theme = require(script.Parent.Parent.Theme)

local PublishPanel = {}

export type PublishApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	isOpen: () -> boolean,
	apply: (report: any) -> (),
	showError: (message: string) -> (),
}

local STATUS_LABEL: { [string]: string } = {
	Ready = "Ready",
	Stub = "Still Studio stub",
	Blocked = "Blocked",
}

local function scrub(text: string): string
	return (string.gsub(text, "%d%d%d%d+", "…"))
end

local function statusColor(status: string): Color3
	if status == "Ready" then
		return Theme.mint
	end
	if status == "Blocked" then
		return Theme.coral
	end
	return Theme.amber
end

function PublishPanel.create(parent: Instance): PublishApi
	local root = Instance.new("Frame")
	root.Name = "PublishPanel"
	root.BackgroundColor3 = Theme.panel
	root.BorderSizePixel = 0
	root.Position = UDim2.fromOffset(0, 0)
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.ZIndex = 8
	root.Parent = parent
	Theme.corner(root, 18)
	Theme.stroke(root, Theme.mint, 2, 0.2)
	Theme.pad(root, 12)

	local title = Theme.text(root, "Title", "Publish / Live", 22, Theme.mint, Theme.fontTitle)
	title.Size = UDim2.new(1, -36, 0, 26)
	title.ZIndex = 9

	local close = Theme.button(root, "Close", "✕", Theme.coral)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(28, 28)
	close.TextSize = 14
	close.ZIndex = 9

	local summary = Theme.text(root, "Summary", "Reading the server checklist…", 13, Theme.cream, Theme.fontMono)
	summary.Position = UDim2.fromOffset(0, 28)
	summary.Size = UDim2.new(1, 0, 0, 18)
	summary.ZIndex = 9

	local note = Theme.text(
		root,
		"Note",
		"Informational only. Studio Play stays open when these are still 0. PLAYTEST §7.",
		12,
		Theme.peach
	)
	note.Position = UDim2.fromOffset(0, 48)
	note.Size = UDim2.new(1, 0, 0, 32)
	note.ZIndex = 9

	local list = Instance.new("ScrollingFrame")
	list.Name = "Rows"
	list.BackgroundColor3 = Theme.panelAlt
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, 84)
	list.Size = UDim2.new(1, 0, 1, -84)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.ZIndex = 9
	list.Parent = root
	Theme.corner(list, 12)
	Theme.pad(list, 8)
	Theme.list(list, 6)

	local function clearRows()
		local doomed = {}
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				table.insert(doomed, child)
			end
		end
		for _, child in doomed do
			child:Destroy()
		end
	end

	local function addRow(id: string, labelText: string, status: string, fixText: string, order: number)
		local row = Instance.new("Frame")
		row.Name = id
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, 68)
		row.ZIndex = 9
		row.Parent = list

		local label = Theme.text(row, "Label", scrub(labelText), 15, Theme.cream, Theme.fontTitle)
		label.Size = UDim2.new(1, -150, 0, 20)
		label.ZIndex = 9

		local statusLabel = Theme.text(row, "Status", STATUS_LABEL[status] or status, 13, statusColor(status), Theme.fontMono)
		statusLabel.AnchorPoint = Vector2.new(1, 0)
		statusLabel.Position = UDim2.fromScale(1, 0)
		statusLabel.Size = UDim2.fromOffset(142, 20)
		statusLabel.TextXAlignment = Enum.TextXAlignment.Right
		statusLabel.ZIndex = 9

		local fix = Theme.text(row, "Fix", scrub(fixText), 12, Theme.peach)
		fix.Position = UDim2.fromOffset(0, 22)
		fix.Size = UDim2.new(1, 0, 0, 44)
		fix.ZIndex = 9
	end

	local api: PublishApi
	api = {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
		end,
		isOpen = function()
			return root.Visible == true
		end,
		apply = function(report: any)
			clearRows()
			if typeof(report) ~= "table" then
				summary.Text = "Could not read the server checklist."
				addRow("Error", "Checklist", "Blocked", "Play is not blocked. See PLAYTEST §7.", 1)
				return
			end
			summary.Text = if typeof(report.summary) == "string"
				then scrub(report.summary)
				else "Checklist"
			local rows = report.rows
			if typeof(rows) ~= "table" then
				return
			end
			local order = 0
			for _, item in rows do
				if order >= 8 then
					break
				end
				if
					typeof(item) == "table"
					and typeof(item.id) == "string"
					and typeof(item.label) == "string"
					and typeof(item.status) == "string"
					and typeof(item.fix) == "string"
					and STATUS_LABEL[item.status] ~= nil
				then
					order += 1
					addRow(scrub(item.id), item.label, item.status, item.fix, order)
				end
			end
		end,
		showError = function(message: string)
			clearRows()
			summary.Text = "Checklist unavailable"
			addRow("Error", "Checklist", "Blocked", message, 1)
		end,
	}

	close.MouseButton1Click:Connect(function()
		api.setVisible(false)
	end)

	return api
end

return PublishPanel
