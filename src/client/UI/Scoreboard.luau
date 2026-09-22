--!strict

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local ItemCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Scoreboard = {}

export type BoardApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (snapshot: Types.MatchSnapshot, localUserId: number) -> (),
}

-- Fixed columns so CS and gold stay readable. Gotham is not monospace.
local COLS = {
	{ name = "Team", width = 48 },
	{ name = "Cat", width = 156 },
	{ name = "Lv", width = 28 },
	{ name = "KDA", width = 76 },
	{ name = "CS", width = 48 },
	{ name = "Gold", width = 64 },
	{ name = "Items", width = 240 },
}

local function itemsText(ids: { string }): string
	if #ids == 0 then
		return "—"
	end
	local counts: { [string]: number } = {}
	local order: { string } = {}
	for _, id in ids do
		if not counts[id] then
			table.insert(order, id)
			counts[id] = 0
		end
		counts[id] += 1
	end
	local names = {}
	for _, id in order do
		local item = ItemCatalog.get(id)
		local label = if item then item.name else id
		local n = counts[id]
		table.insert(names, if n > 1 then `{label} ×{n}` else label)
	end
	return table.concat(names, ", ")
end

local function columnRow(parent: Instance, name: string, order: number): (Frame, { TextLabel })
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 22)
	row.LayoutOrder = order
	row.ZIndex = 22
	row.Parent = parent
	Theme.list(row, 4, Enum.FillDirection.Horizontal)

	local cells = {}
	for index, col in COLS do
		local cell = Theme.text(row, col.name, "", 13, Theme.cream, Theme.fontMono)
		cell.Size = UDim2.fromOffset(col.width, 22)
		cell.LayoutOrder = index
		cell.TextWrapped = false
		cell.TextTruncate = Enum.TextTruncate.AtEnd
		cell.ZIndex = 22
		table.insert(cells, cell)
	end
	return row, cells
end

function Scoreboard.create(parent: Instance): BoardApi
	local root = Instance.new("Frame")
	root.Name = "Scoreboard"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.46)
	root.Size = UDim2.fromOffset(760, 360)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.ZIndex = 20
	root.Parent = parent
	Theme.corner(root, 16)
	Theme.stroke(root, Theme.amber, 2, 0.2)
	Theme.pad(root, 12)

	local title = Theme.text(root, "Title", "Scoreboard  ·  hold Tab", 18, Theme.amber, Theme.fontTitle)
	title.Size = UDim2.new(1, 0, 0, 22)
	title.ZIndex = 21

	local totals = Theme.text(root, "Totals", "", 13, Theme.cream, Theme.fontMono)
	totals.Position = UDim2.fromOffset(0, 24)
	totals.Size = UDim2.new(1, 0, 0, 18)
	totals.TextWrapped = false
	totals.ZIndex = 21

	local list = Instance.new("ScrollingFrame")
	list.BackgroundColor3 = Theme.panelAlt
	list.Position = UDim2.fromOffset(0, 46)
	list.Size = UDim2.new(1, 0, 1, -46)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.ZIndex = 21
	list.Parent = root
	Theme.corner(list, 10)
	Theme.pad(list, 8)
	Theme.list(list, 4)

	local _, headerCells = columnRow(list, "Head", 0)
	for index, col in COLS do
		headerCells[index].Text = col.name
		headerCells[index].TextColor3 = Theme.peach
		headerCells[index].TextSize = 12
	end

	local rows: { Frame } = {}
	local cells: { { TextLabel } } = {}

	local function rowAt(index: number): { TextLabel }
		local existing = cells[index]
		if existing then
			rows[index].Visible = true
			return existing
		end
		local row, rowCells = columnRow(list, `R{index}`, index)
		rows[index] = row
		cells[index] = rowCells
		return rowCells
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
		end,
		update = function(snapshot: Types.MatchSnapshot, localUserId: number)
			local ordered: { Types.MatchPlayer } = {}
			for _, matchPlayer in snapshot.players do
				table.insert(ordered, matchPlayer)
			end
			table.sort(ordered, function(a, b)
				if a.team ~= b.team then
					return a.team < b.team
				end
				return a.gold > b.gold
			end)

			local blueK, redK, blueG, redG, blueCs, redCs = 0, 0, 0, 0, 0, 0
			for _, matchPlayer in ordered do
				if matchPlayer.team == "Blue" then
					blueK += matchPlayer.kills
					blueG += matchPlayer.gold
					blueCs += matchPlayer.cs or 0
				else
					redK += matchPlayer.kills
					redG += matchPlayer.gold
					redCs += matchPlayer.cs or 0
				end
			end
			totals.Text = `Blue  {blueK} kills · {blueCs} CS · {blueG}g     Red  {redK} kills · {redCs} CS · {redG}g`

			for i, matchPlayer in ordered do
				local rowCells = rowAt(i)
				local champ = if matchPlayer.championId then ChampionCatalog.get(matchPlayer.championId) else nil
				local name = champ and champ.name or matchPlayer.displayName
				if matchPlayer.isBot and not string.find(name, "%(Bot%)") then
					name = `{name} (Bot)`
				end
				if matchPlayer.userId == localUserId then
					name = `{name} *`
				end
				local color = if matchPlayer.team == "Blue" then Theme.blue else Theme.red
				local values = {
					matchPlayer.team,
					name,
					tostring(matchPlayer.level or 1),
					`{matchPlayer.kills}/{matchPlayer.deaths}/{matchPlayer.assists}`,
					tostring(matchPlayer.cs or 0),
					`{matchPlayer.gold}g`,
					itemsText(matchPlayer.items),
				}
				for index, cell in rowCells do
					cell.Text = values[index]
					cell.TextColor3 = color
				end
			end
			for i = #ordered + 1, #rows do
				rows[i].Visible = false
			end
		end,
	}
end

return Scoreboard
