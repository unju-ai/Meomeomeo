--!strict

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local ChampionSelect = {}

export type SelectApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (snapshot: Types.MatchSnapshot, localUserId: number) -> (),
	onPick: ((championId: string) -> ()) -> (),
}

function ChampionSelect.create(parent: Instance): SelectApi
	local root = Instance.new("Frame")
	root.Name = "ChampionSelect"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(860, 540)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.Parent = parent
	Theme.corner(root, 20)
	Theme.stroke(root, Theme.amber, 3, 0.2)
	Theme.pad(root, 18)

	local title = Theme.text(root, "Title", "Pick your cat", 28, Theme.amber, Theme.fontTitle)
	title.Size = UDim2.new(1, 0, 0, 32)

	local hint = Theme.text(root, "Hint", "Lock in before the timer. Same-team dupes are blocked. Scroll for more cats.", 14, Theme.cream)
	hint.Position = UDim2.fromOffset(0, 34)
	hint.Size = UDim2.new(1, 0, 0, 20)

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, 64)
	grid.Size = UDim2.new(1, 0, 1, -74)
	grid.ScrollBarThickness = 6
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.CanvasSize = UDim2.fromOffset(0, 0)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = root

	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.CellSize = UDim2.new(0.333, -8, 0, 118)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local pickHandler: ((string) -> ())? = nil
	local cards: { [string]: TextButton } = {}

	for index, champ in ChampionCatalog.all() do
		local card = Instance.new("TextButton")
		card.Name = champ.id
		card.AutoButtonColor = true
		card.BackgroundColor3 = Theme.panelAlt
		card.Text = ""
		card.LayoutOrder = index
		card.Parent = grid
		Theme.corner(card, 14)
		Theme.stroke(card, champ.color, 2, 0.1)
		Theme.pad(card, 10)

		local name = Theme.text(card, "Name", champ.name, 18, Theme.cream, Theme.fontTitle)
		name.Size = UDim2.new(1, 0, 0, 22)

		local role = Theme.text(card, "Role", `{champ.role} · {champ.title}`, 11, champ.color)
		role.Position = UDim2.fromOffset(0, 22)
		role.Size = UDim2.new(1, 0, 0, 16)

		local blurb = Theme.text(card, "Blurb", champ.blurb, 12, Theme.peach)
		blurb.Position = UDim2.fromOffset(0, 40)
		blurb.Size = UDim2.new(1, 0, 1, -40)

		card.MouseButton1Click:Connect(function()
			if pickHandler then
				pickHandler(champ.id)
			end
		end)
		cards[champ.id] = card
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
		end,
		update = function(snapshot: Types.MatchSnapshot, localUserId: number)
			local mine = snapshot.players[tostring(localUserId)]
			local remaining = if snapshot.phaseEndsAt then math.max(0, math.floor(snapshot.phaseEndsAt - workspace:GetServerTimeNow())) else 0
			title.Text = if snapshot.practice then `Practice draft · {remaining}s` else `Pick your cat · {remaining}s`
			if mine then
				hint.Text = `You are {mine.team}. Locked: {mine.championId or "none"}`
			end
			for id, card in cards do
				local taken = false
				for _, other in snapshot.players do
					if other.championId == id and mine and other.team == mine.team then
						taken = true
					end
				end
				card.BackgroundColor3 = if mine and mine.championId == id then Theme.ink else Theme.panelAlt
				if taken and not (mine and mine.championId == id) then
					card.BackgroundTransparency = 0.25
				else
					card.BackgroundTransparency = 0
				end
			end
		end,
		onPick = function(fn)
			pickHandler = fn
		end,
	}
end

return ChampionSelect
