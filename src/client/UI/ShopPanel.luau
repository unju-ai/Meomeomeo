--!strict

-- Cat Rift Pawmart (B): nine ItemCatalog rows with section tags, key chips, and buy tint.
-- Gold / fountain / owned state come from ShopStatus. Prices stay on ShopService.

local ItemCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local ShopPaint = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ShopPaint"))
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local ShopPanel = {}

export type ShopApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	toggle: () -> (),
	update: (status: Types.ShopStatus) -> (),
	onBuy: ((itemId: string) -> ()) -> (),
}

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function makeChip(parent: Instance, name: string, text: string, fill: Color3, ink: Color3?, width: number?): TextLabel
	local chip = Instance.new("TextLabel")
	chip.Name = name
	chip.BackgroundColor3 = fill
	chip.BackgroundTransparency = 0.12
	chip.Text = text
	chip.TextColor3 = ink or Theme.ink
	chip.TextSize = 11
	chip.Font = Theme.fontMono
	chip.TextXAlignment = Enum.TextXAlignment.Center
	chip.Size = UDim2.fromOffset(width or 52, 18)
	chip.Parent = parent
	Theme.corner(chip, 6)
	return chip
end

type CardBits = {
	button: TextButton,
	stroke: UIStroke,
	name: TextLabel,
	blurb: TextLabel,
	itemId: string,
}

function ShopPanel.create(parent: Instance): ShopApi
	local root = Instance.new("Frame")
	root.Name = "ShopPanel"
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.new(0, 16, 1, -150)
	root.Size = UDim2.fromOffset(360, 520)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.Parent = parent
	Theme.corner(root, 16)
	Theme.stroke(root, Theme.amber, 2, 0.2)
	Theme.pad(root, 12)

	local title = Theme.text(root, "Title", "Pawmart", 22, Theme.amber, Theme.fontTitle)
	title.Size = UDim2.new(1, -36, 0, 24)

	local close = Theme.button(root, "Close", "✕", Theme.coral)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, 0)
	close.Size = UDim2.fromOffset(28, 28)
	close.TextSize = 14

	local gold = Theme.text(root, "Gold", ShopPaint.goldLine(0), 16, Theme.amber, Theme.fontTitle)
	gold.Position = UDim2.fromOffset(0, 28)
	gold.Size = UDim2.new(0.45, 0, 0, 20)
	gold.TextWrapped = false

	local fountain = Theme.text(root, "Fountain", ShopPaint.fountainLine(true), 12, Theme.cream, Theme.fontMono)
	fountain.Position = UDim2.new(0.45, 0, 0, 30)
	fountain.Size = UDim2.new(0.55, 0, 0, 18)
	fountain.TextXAlignment = Enum.TextXAlignment.Right
	fountain.TextWrapped = false

	local warn = Theme.text(root, "Warn", "", 12, Theme.warn, Theme.fontBody)
	warn.Position = UDim2.fromOffset(0, 50)
	warn.Size = UDim2.new(1, 0, 0, 16)
	warn.Visible = false
	warn.TextWrapped = false

	local hint = Theme.text(root, "Hint", ShopPaint.hintLine(), 11, Theme.peach)
	hint.Position = UDim2.fromOffset(0, 68)
	hint.Size = UDim2.new(1, 0, 0, 28)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundColor3 = Theme.panelAlt
	list.Position = UDim2.fromOffset(0, 100)
	list.Size = UDim2.new(1, 0, 1, -100)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = root
	Theme.corner(list, 10)
	Theme.pad(list, 8)
	Theme.list(list, 8)

	local buyHandler: ((string) -> ())? = nil
	local cards: { [string]: CardBits } = {}
	local layoutOrder = 0

	local function nextOrder(): number
		layoutOrder += 1
		return layoutOrder
	end

	for _, section in ShopPaint.sectionOrder() do
		local header = Instance.new("Frame")
		header.Name = `Section_{section}`
		header.BackgroundColor3 = Theme.ink
		header.BackgroundTransparency = 0.35
		header.Size = UDim2.new(1, -4, 0, 22)
		header.LayoutOrder = nextOrder()
		header.Parent = list
		Theme.corner(header, 6)
		Theme.stroke(header, rgb(ShopPaint.sectionFill(section)), 1, 0.45)

		local headerLabel = Theme.text(header, "Title", ShopPaint.sectionTitle(section), 12, Theme.cream, Theme.fontMono)
		headerLabel.Position = UDim2.fromOffset(8, 0)
		headerLabel.Size = UDim2.new(1, -12, 1, 0)
		headerLabel.TextWrapped = false

		for _, item in ItemCatalog.all() do
			if ShopPaint.sectionOf(item.id) ~= section then
				continue
			end

			local card = Instance.new("TextButton")
			card.Name = item.id
			card.AutoButtonColor = true
			card.BackgroundColor3 = Theme.ink
			card.Text = ""
			card.LayoutOrder = nextOrder()
			card.Size = UDim2.new(1, -4, 0, 72)
			card.Parent = list
			Theme.corner(card, 10)
			Theme.pad(card, 8)
			local stroke = Theme.stroke(card, Theme.amber, 1, 0.45)

			local chipRow = Instance.new("Frame")
			chipRow.Name = "Chips"
			chipRow.BackgroundTransparency = 1
			chipRow.Position = UDim2.fromOffset(0, 0)
			chipRow.Size = UDim2.new(1, 0, 0, 18)
			chipRow.Parent = card
			Theme.list(chipRow, 6, Enum.FillDirection.Horizontal)

			makeChip(
				chipRow,
				"Tag",
				ShopPaint.sectionTag(section),
				rgb(ShopPaint.sectionFill(section)),
				Theme.ink,
				if section == "Actives" then 58 else 52
			)

			local key = ShopPaint.keybind(item.id)
			if key then
				makeChip(chipRow, "Key", key, Theme.cream, Theme.ink, 22)
			end

			local maxStack = ItemCatalog.maxStack(item.id)
			local name = Theme.text(
				card,
				"N",
				ShopPaint.nameLine(item.name, item.cost, 0, maxStack, "buyable"),
				14,
				Theme.cream,
				Theme.fontTitle
			)
			name.Position = UDim2.fromOffset(0, 22)
			name.Size = UDim2.new(1, 0, 0, 18)
			name.TextWrapped = false

			local blurb = Theme.text(card, "B", item.blurb, 11, Theme.peach)
			blurb.Position = UDim2.fromOffset(0, 40)
			blurb.Size = UDim2.new(1, 0, 0, 24)

			card.MouseButton1Click:Connect(function()
				if not card.Active then
					return
				end
				if buyHandler then
					buyHandler(item.id)
				end
			end)

			cards[item.id] = {
				button = card,
				stroke = stroke,
				name = name,
				blurb = blurb,
				itemId = item.id,
			}
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
		toggle = function()
			root.Visible = not root.Visible
		end,
		update = function(status: Types.ShopStatus)
			gold.Text = ShopPaint.goldLine(status.gold)
			gold.TextColor3 = Theme.amber
			fountain.Text = ShopPaint.fountainLine(status.atFountain)
			fountain.TextColor3 = if status.atFountain then Theme.cream else Theme.warn
			warn.Visible = not status.atFountain
			warn.Text = if status.atFountain then "" else "Shop open — buy only at your fountain"
			hint.Text = ShopPaint.hintLine()

			local ownedCount: { [string]: number } = {}
			for _, id in status.owned do
				ownedCount[id] = (ownedCount[id] or 0) + 1
			end

			for id, bits in cards do
				local item = ItemCatalog.get(id)
				if not item then
					continue
				end
				local n = ownedCount[id] or 0
				local maxStack = ItemCatalog.maxStack(id)
				local kind = ShopPaint.cardKind(status.gold, status.atFountain, n, maxStack, item.cost)
				local paint = ShopPaint.cardPaint(kind)
				bits.button.BackgroundColor3 = rgb(paint.fill)
				bits.button.BackgroundTransparency = paint.fillAlpha
				bits.button.Active = paint.active
				bits.button.AutoButtonColor = paint.active
				bits.stroke.Color = rgb(paint.stroke)
				bits.stroke.Transparency = paint.strokeAlpha
				bits.name.Text = ShopPaint.nameLine(item.name, item.cost, n, maxStack, kind)
				bits.name.TextColor3 = rgb(paint.text)
				bits.name.TextTransparency = paint.textAlpha
				bits.blurb.TextTransparency = paint.textAlpha * 0.5
			end
		end,
		onBuy = function(fn)
			buyHandler = fn
		end,
	}
end

return ShopPanel
