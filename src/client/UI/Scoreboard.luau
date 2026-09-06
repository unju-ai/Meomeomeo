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

local function itemsText(ids: { string }): string
	if #ids == 0 then
		return "—"
	end
	local names = {}
	for _, id in ids do
		local item = ItemCatalog.get(id)
		table.insert(names, if item then item.name else id)
	end
	return table.concat(names, ", ")
end

function Scoreboard.create(parent: Instance): BoardApi
	local root = Instance.new("Frame")
	root.Name = "Scoreboard"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.46)
	root.Size = UDim2.fromOffset(720, 360)
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
	totals.ZIndex = 21

	local header = Theme.text(root, "Head", "Team   Cat                    Lv   K / D / A   CS    Gold   Items", 12, Theme.peach, Theme.fontMono)
	header.Position = UDim2.fromOffset(0, 46)
	header.Size = UDim2.new(1, 0, 0, 16)
	header.ZIndex = 21

	local list = Instance.new("ScrollingFrame")
	list.BackgroundColor3 = Theme.panelAlt
	list.Position = UDim2.fromOffset(0, 66)
	list.Size = UDim2.new(1, 0, 1, -66)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.ZIndex = 21
	list.Parent = root
	Theme.corner(list, 10)
	Theme.pad(list, 8)
	Theme.list(list, 4)

	local rows: { TextLabel } = {}

	local function rowAt(index: number): TextLabel
		local existing = rows[index]
		if existing then
			return existing
		end
		local row = Theme.text(list, `R{index}`, "", 13, Theme.cream, Theme.fontMono)
		row.Size = UDim2.new(1, -8, 0, 22)
		row.LayoutOrder = index
		row.ZIndex = 22
		rows[index] = row
		return row
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
				local row = rowAt(i)
				row.Visible = true
				local champ = if matchPlayer.championId then ChampionCatalog.get(matchPlayer.championId) else nil
				local name = champ and champ.name or matchPlayer.displayName
				if matchPlayer.isBot and not string.find(name, "%(Bot%)") then
					name = `{name} (Bot)`
				end
				local you = if matchPlayer.userId == localUserId then " *" else ""
				row.TextColor3 = if matchPlayer.team == "Blue" then Theme.blue else Theme.red
				row.Text = string.format(
					"%-5s  %-20s  %2d   %d / %d / %d   %3d   %4dg   %s%s",
					matchPlayer.team,
					string.sub(name, 1, 20),
					matchPlayer.level or 1,
					matchPlayer.kills,
					matchPlayer.deaths,
					matchPlayer.assists,
					matchPlayer.cs or 0,
					matchPlayer.gold,
					itemsText(matchPlayer.items),
					you
				)
			end
			for i = #ordered + 1, #rows do
				rows[i].Visible = false
			end
		end,
	}
end

return Scoreboard
