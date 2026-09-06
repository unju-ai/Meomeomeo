--!strict

local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local KillFeed = {}

export type FeedApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	push: (event: Types.FeedEvent) -> (),
}

function KillFeed.create(parent: Instance): FeedApi
	local root = Instance.new("Frame")
	root.Name = "KillFeed"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 34)
	root.Size = UDim2.fromOffset(560, 92)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = parent
	Theme.list(root, 2)

	local rows: { TextLabel } = {}
	for i = 1, 5 do
		local row = Theme.text(root, `R{i}`, "", 13, Theme.cream, Theme.fontBody)
		row.Size = UDim2.new(1, 0, 0, 16)
		row.TextXAlignment = Enum.TextXAlignment.Center
		row.TextStrokeTransparency = 0.45
		row.LayoutOrder = i
		row.Visible = false
		table.insert(rows, row)
	end

	local lines: { Types.FeedEvent } = {}

	local function paint()
		for i, row in rows do
			local event = lines[i]
			if event then
				row.Visible = true
				row.Text = event.text
				if event.kind == "kill" then
					row.TextColor3 = Theme.peach
				elseif event.kind == "tower" then
					row.TextColor3 = Theme.amber
				elseif event.kind == "nexus" then
					row.TextColor3 = Theme.coral
				else
					row.TextColor3 = Theme.mint
				end
			else
				row.Visible = false
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
			while #lines > 5 do
				table.remove(lines)
			end
			paint()
			task.delay(5.5, function()
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
