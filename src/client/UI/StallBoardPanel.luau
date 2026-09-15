--!strict

-- Daily stall boards (Koi catch / Arcade profit). Display names only.

local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local StallBoardPanel = {}

export type StallBoardApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	isOpen: () -> boolean,
	update: (board: Types.StallBoard) -> (),
}

export type StallBoardConfig = {
	name: string,
	title: string,
	empty: string,
	accent: Color3?,
}

function StallBoardPanel.create(parent: Instance, config: StallBoardConfig): StallBoardApi
	local accent = config.accent or Theme.mint
	local root = Instance.new("Frame")
	root.Name = config.name
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(440, 460)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.ZIndex = 40
	root.Parent = parent
	Theme.corner(root, 20)
	Theme.stroke(root, accent, 3, 0.12)
	Theme.pad(root, 16)

	local title = Theme.text(root, "Title", config.title, 24, accent, Theme.fontTitle)
	title.Size = UDim2.new(1, -40, 0, 28)

	local close = Theme.button(root, "Close", "✕", Theme.coral)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, 0)
	close.Size = UDim2.fromOffset(32, 32)
	close.TextSize = 16
	close.ZIndex = 41

	local sub = Theme.text(root, "Sub", "UTC day · display names only", 13, Theme.peach)
	sub.Position = UDim2.fromOffset(0, 36)
	sub.Size = UDim2.new(1, 0, 0, 18)

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(0, 60)
	list.Size = UDim2.new(1, 0, 1, -60)
	list.Parent = root
	Theme.list(list, 6)

	local function paint(board: Types.StallBoard)
		for _, child in list:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		sub.Text = `{board.dayKey}  ·  UTC day  ·  Save: {board.persistMode}`
		if #board.entries == 0 then
			local empty = Theme.text(list, "Empty", config.empty, 15, Theme.muted)
			empty.Size = UDim2.new(1, 0, 0, 48)
			empty.TextWrapped = true
			return
		end
		for _, row in board.entries do
			local color = if row.isSelf
				then Theme.amber
				elseif row.rank == 1 then Theme.amber
				elseif row.rank == 2 then Theme.peach
				elseif row.rank == 3 then Theme.mint
				else Theme.cream
			local line = Theme.text(
				list,
				`R{row.rank}`,
				`#{row.rank}  {row.name}  ·  {row.detail}  ·  {row.score}`,
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
		update = function(board: Types.StallBoard)
			paint(board)
		end,
	}
end

return StallBoardPanel
