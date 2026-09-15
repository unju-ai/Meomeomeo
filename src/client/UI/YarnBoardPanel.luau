--!strict

-- Daily Yarn Run board. Roblox display names only.

local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local YarnRunCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("YarnRunCatalog"))

local YarnBoardPanel = {}

export type BoardApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	isOpen: () -> boolean,
	update: (board: Types.YarnBoard) -> (),
}

function YarnBoardPanel.create(parent: Instance): BoardApi
	local root = Instance.new("Frame")
	root.Name = "YarnBoard"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(460, 460)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.ZIndex = 40
	root.Parent = parent
	Theme.corner(root, 20)
	Theme.stroke(root, Theme.amber, 3, 0.12)
	Theme.pad(root, 16)

	local title = Theme.text(root, "Title", "Daily Yarn", 24, Theme.amber, Theme.fontTitle)
	title.Size = UDim2.new(1, -40, 0, 28)

	local close = Theme.button(root, "Close", "✕", Theme.coral)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, 0)
	close.Size = UDim2.fromOffset(32, 32)
	close.TextSize = 16
	close.ZIndex = 41

	local sub = Theme.text(root, "Sub", "UTC day · display names only", 13, Theme.peach)
	sub.Position = UDim2.fromOffset(0, 30)
	sub.Size = UDim2.new(1, 0, 0, 18)

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(0, 54)
	list.Size = UDim2.new(1, 0, 1, -54)
	list.Parent = root
	Theme.list(list, 6)

	local function paint(board: Types.YarnBoard)
		for _, child in list:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		sub.Text = `{board.dayKey}  ·  Save: {board.persistMode}  ·  names only`
		if #board.entries == 0 then
			local empty = Theme.text(list, "Empty", "No dashes logged today. Be the first Yarn Lord.", 15, Theme.muted)
			empty.Size = UDim2.new(1, 0, 0, 40)
			empty.TextWrapped = true
			return
		end
		for _, row in board.entries do
			local color = if row.isSelf then Theme.amber elseif row.rank == 1 then Theme.amber elseif row.rank == 2 then Theme.peach elseif row.rank == 3 then Theme.mint else Theme.cream
			local line = Theme.text(
				list,
				`R{row.rank}`,
				`#{row.rank}  {row.name}  ·  {row.score}  ·  {row.meters}m  ·  {YarnRunCatalog.runnerTag(row.championId)}`,
				15,
				color,
				if row.rank <= 3 then Theme.fontTitle else Theme.fontBody
			)
			line.Size = UDim2.new(1, 0, 0, 28)
			if row.isSelf then
				Theme.stroke(line, Theme.amber, 1, 0.4)
			end
		end
	end

	close.MouseButton1Click:Connect(function()
		root.Visible = false
	end)

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
		end,
		isOpen = function()
			return root.Visible
		end,
		update = function(board: Types.YarnBoard)
			paint(board)
		end,
	}
end

return YarnBoardPanel
