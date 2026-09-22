--!strict

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local ChampionKits = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionKits"))
local ChampionLooks = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionLooks"))
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local ChampionSelect = {}

local URGENT_SECONDS = 10
local ROLE_FILTERS = { "All", "Tank", "Bruiser", "Assassin", "Mage", "Marksman", "Support" }

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
	root.Size = UDim2.fromOffset(880, 580)
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

	local filters = Instance.new("Frame")
	filters.Name = "Filters"
	filters.BackgroundTransparency = 1
	filters.Position = UDim2.fromOffset(0, 58)
	filters.Size = UDim2.new(1, 0, 0, 28)
	filters.Parent = root
	Theme.list(filters, 6, Enum.FillDirection.Horizontal)

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, 92)
	grid.Size = UDim2.new(1, 0, 1, -102)
	grid.ScrollBarThickness = 6
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.CanvasSize = UDim2.fromOffset(0, 0)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = root

	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.CellSize = UDim2.new(0.333, -8, 0, 148)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local pickHandler: ((string) -> ())? = nil
	local cards: { [string]: TextButton } = {}
	local cardStrokes: { [string]: UIStroke } = {}
	local cardRoles: { [string]: string } = {}
	local roleFilter = "All"
	local filterButtons: { [string]: TextButton } = {}

	local function applyRoleFilter()
		for id, card in cards do
			local role = cardRoles[id]
			card.Visible = roleFilter == "All" or role == roleFilter
		end
		for role, button in filterButtons do
			local on = role == roleFilter
			button.BackgroundColor3 = if on then Theme.amber else Theme.panelAlt
			button.TextColor3 = if on then Theme.ink else Theme.cream
		end
	end

	for index, role in ROLE_FILTERS do
		local chip = Instance.new("TextButton")
		chip.Name = role
		chip.AutoButtonColor = true
		chip.BackgroundColor3 = if role == "All" then Theme.amber else Theme.panelAlt
		chip.Text = role
		chip.TextColor3 = if role == "All" then Theme.ink else Theme.cream
		chip.TextSize = 12
		chip.Font = Theme.fontBody
		chip.Size = UDim2.fromOffset(if role == "Marksman" then 78 else 68, 26)
		chip.LayoutOrder = index
		chip.Parent = filters
		Theme.corner(chip, 8)
		Theme.stroke(chip, Theme.strokeColor, 1, 0.45)
		chip.MouseButton1Click:Connect(function()
			roleFilter = role
			applyRoleFilter()
		end)
		filterButtons[role] = chip
	end

	for index, champ in ChampionCatalog.all() do
		local card = Instance.new("TextButton")
		card.Name = champ.id
		card.AutoButtonColor = true
		card.BackgroundColor3 = Theme.panelAlt
		card.Text = ""
		card.LayoutOrder = index
		card.Parent = grid
		Theme.corner(card, 14)
		local stroke = Theme.stroke(card, champ.color, 2, 0.1)
		Theme.pad(card, 10)

		local look = ChampionLooks.get(champ.id)
		local icon = Instance.new("Frame")
		icon.Name = "Look"
		icon.AnchorPoint = Vector2.new(1, 0)
		icon.Position = UDim2.fromScale(1, 0)
		icon.Size = UDim2.fromOffset(44, 38)
		icon.BackgroundColor3 = look.body
		icon.BorderSizePixel = 0
		icon.ZIndex = 2
		icon.Parent = card
		Theme.corner(icon, 10)
		Theme.stroke(icon, look.accent, 2, 0.15)
		for _, side in { -1, 1 } do
			local ear = Instance.new("Frame")
			ear.Name = if side < 0 then "EarL" else "EarR"
			ear.AnchorPoint = Vector2.new(0.5, 1)
			ear.Position = UDim2.fromScale(0.5 + side * 0.28, 0.18)
			ear.Size = UDim2.fromOffset(11, 13)
			ear.BackgroundColor3 = look.accent
			ear.BorderSizePixel = 0
			ear.Rotation = side * -20
			ear.ZIndex = 3
			ear.Parent = icon
			Theme.corner(ear, 3)
		end
		local strip = Instance.new("Frame")
		strip.Name = "Accent"
		strip.AnchorPoint = Vector2.new(0, 1)
		strip.Position = UDim2.fromScale(0, 1)
		strip.Size = UDim2.new(1, 0, 0, 6)
		strip.BackgroundColor3 = look.neon
		strip.BorderSizePixel = 0
		strip.ZIndex = 3
		strip.Parent = icon

		local name = Theme.text(card, "Name", champ.name, 18, Theme.cream, Theme.fontTitle)
		name.Size = UDim2.new(1, -52, 0, 22)

		local role = Theme.text(card, "Role", `{champ.role} · {look.label}`, 11, champ.color)
		role.Position = UDim2.fromOffset(0, 22)
		role.Size = UDim2.new(1, -52, 0, 16)

		local blurb = Theme.text(card, "Blurb", champ.blurb, 11, Theme.peach)
		blurb.Position = UDim2.fromOffset(0, 40)
		blurb.Size = UDim2.new(1, 0, 0, 36)
		blurb.TextYAlignment = Enum.TextYAlignment.Top

		local kitLine = ChampionKits.teaserLine(champ.id)
		local kit = Theme.text(card, "Kit", kitLine, 12, Theme.amber, Theme.fontBody)
		kit.Position = UDim2.fromOffset(0, 80)
		kit.Size = UDim2.new(1, 0, 0, 34)
		kit.TextYAlignment = Enum.TextYAlignment.Top
		kit.TextWrapped = true

		local status = Theme.text(card, "Status", "", 11, Theme.coral, Theme.fontTitle)
		status.AnchorPoint = Vector2.new(1, 1)
		status.Position = UDim2.fromScale(1, 1)
		status.Size = UDim2.fromOffset(72, 16)
		status.TextXAlignment = Enum.TextXAlignment.Right
		status.Visible = false

		card.MouseButton1Click:Connect(function()
			if card.Active == false then
				return
			end
			if pickHandler then
				pickHandler(champ.id)
			end
		end)
		cards[champ.id] = card
		cardStrokes[champ.id] = stroke
		cardRoles[champ.id] = champ.role
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
		end,
		update = function(snapshot: Types.MatchSnapshot, localUserId: number)
			local mine = snapshot.players[tostring(localUserId)]
			local remaining = if snapshot.phaseEndsAt then math.max(0, math.floor(snapshot.phaseEndsAt - workspace:GetServerTimeNow())) else 0
			local urgent = remaining > 0 and remaining <= URGENT_SECONDS
			title.Text = if snapshot.practice then `Practice draft · {remaining}s` else `Pick your cat · {remaining}s`
			title.TextColor3 = if urgent then Theme.coral else Theme.amber
			if mine then
				if snapshot.practice then
					local bots = 0
					for _, other in snapshot.players do
						if other.isBot then
							bots += 1
						end
					end
					hint.Text = `You are {mine.team}. Red is {bots} practice bots ({snapshot.botDifficulty or "Normal"}). Locked: {mine.championId or "none"}`
				else
					hint.Text = `You are {mine.team}. Locked: {mine.championId or "none"}`
				end
				if urgent then
					hint.Text = `{hint.Text} · Lock soon!`
				end
			end
			for id, card in cards do
				local stroke = cardStrokes[id]
				local status = card:FindFirstChild("Status") :: TextLabel?
				local taken = false
				for _, other in snapshot.players do
					if other.championId == id and mine and other.team == mine.team then
						taken = true
					end
				end
				local lockedMine = mine ~= nil and mine.championId == id
				local unavailable = taken and not lockedMine

				if lockedMine then
					card.BackgroundColor3 = Theme.ink
					card.BackgroundTransparency = 0
					card.AutoButtonColor = true
					card.Active = true
					if stroke then
						stroke.Color = Theme.amber
						stroke.Thickness = 4
						stroke.Transparency = 0.05
					end
					if status then
						status.Text = "LOCKED"
						status.TextColor3 = Theme.mint
						status.Visible = true
					end
				elseif unavailable then
					card.BackgroundColor3 = Theme.panelAlt
					card.BackgroundTransparency = 0.45
					card.AutoButtonColor = false
					card.Active = false
					if stroke then
						stroke.Color = Theme.muted
						stroke.Thickness = 2
						stroke.Transparency = 0.35
					end
					if status then
						status.Text = "TAKEN"
						status.TextColor3 = Theme.coral
						status.Visible = true
					end
				else
					card.BackgroundColor3 = Theme.panelAlt
					card.BackgroundTransparency = 0
					card.AutoButtonColor = true
					card.Active = true
					local champ = ChampionCatalog.get(id)
					if stroke then
						stroke.Color = if champ then champ.color else Theme.strokeColor
						stroke.Thickness = 2
						stroke.Transparency = 0.1
					end
					if status then
						status.Text = ""
						status.Visible = false
					end
				end
			end
			applyRoleFilter()
		end,
		onPick = function(fn)
			pickHandler = fn
		end,
	}
end

return ChampionSelect
