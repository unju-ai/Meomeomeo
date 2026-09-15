--!strict

-- Daily + weekly Yarn Run boards. Roblox display names only.

local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local YarnRunCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("YarnRunCatalog"))

local YarnBoardPanel = {}

export type BoardApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	isOpen: () -> boolean,
	update: (boards: Types.YarnBoards) -> (),
	updateDaily: (board: Types.YarnBoard) -> (),
}

function YarnBoardPanel.create(parent: Instance): BoardApi
	local root = Instance.new("Frame")
	root.Name = "YarnBoard"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(460, 500)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.ZIndex = 40
	root.Parent = parent
	Theme.corner(root, 20)
	Theme.stroke(root, Theme.amber, 3, 0.12)
	Theme.pad(root, 16)

	local title = Theme.text(root, "Title", "Yarn Board", 24, Theme.amber, Theme.fontTitle)
	title.Size = UDim2.new(1, -40, 0, 28)

	local close = Theme.button(root, "Close", "✕", Theme.coral)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, 0)
	close.Size = UDim2.fromOffset(32, 32)
	close.TextSize = 16
	close.ZIndex = 41

	local dailyBtn = Theme.button(root, "Daily", "Daily", Theme.amber)
	dailyBtn.Position = UDim2.fromOffset(0, 32)
	dailyBtn.Size = UDim2.new(0.48, 0, 0, 32)
	dailyBtn.TextSize = 15
	dailyBtn.ZIndex = 41

	local weeklyBtn = Theme.button(root, "Weekly", "Weekly", Theme.peach)
	weeklyBtn.Position = UDim2.new(0.52, 0, 0, 32)
	weeklyBtn.Size = UDim2.new(0.48, 0, 0, 32)
	weeklyBtn.TextSize = 15
	weeklyBtn.ZIndex = 41

	local sub = Theme.text(root, "Sub", "UTC day · display names · hide in Audio", 13, Theme.peach)
	sub.Position = UDim2.fromOffset(0, 68)
	sub.Size = UDim2.new(1, 0, 0, 18)

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(0, 90)
	list.Size = UDim2.new(1, 0, 1, -90)
	list.Parent = root
	Theme.list(list, 6)

	local period: Types.YarnBoardPeriod = "daily"
	local latest: Types.YarnBoards? = nil

	local function paintList(board: Types.YarnBoard)
		for _, child in list:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local scope = if board.period == "weekly" then "UTC week" else "UTC day"
		sub.Text = `{board.dayKey}  ·  {scope}  ·  Save: {board.persistMode}`
		if #board.entries == 0 then
			local empty = Theme.text(
				list,
				"Empty",
				if board.period == "weekly"
					then "No dashes logged this week. Be the first Yarn Lord."
					else "No dashes logged today. Be the first Yarn Lord.",
				15,
				Theme.muted
			)
			empty.Size = UDim2.new(1, 0, 0, 40)
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

	local function paint()
		dailyBtn.BackgroundColor3 = if period == "daily" then Theme.amber else Theme.peach
		weeklyBtn.BackgroundColor3 = if period == "weekly" then Theme.amber else Theme.peach
		title.Text = if period == "weekly" then "Weekly Yarn" else "Daily Yarn"
		if not latest then
			return
		end
		paintList(if period == "weekly" then latest.weekly else latest.daily)
	end

	close.MouseButton1Click:Connect(function()
		root.Visible = false
	end)
	dailyBtn.MouseButton1Click:Connect(function()
		period = "daily"
		paint()
	end)
	weeklyBtn.MouseButton1Click:Connect(function()
		period = "weekly"
		paint()
	end)

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
		end,
		isOpen = function()
			return root.Visible
		end,
		update = function(boards: Types.YarnBoards)
			latest = boards
			paint()
		end,
		updateDaily = function(board: Types.YarnBoard)
			if not latest then
				latest = {
					daily = board,
					weekly = board,
				}
			else
				latest = {
					daily = board,
					weekly = latest.weekly,
				}
			end
			paint()
		end,
	}
end

return YarnBoardPanel
