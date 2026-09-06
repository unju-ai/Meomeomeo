--!strict

local ItemCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
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

function ShopPanel.create(parent: Instance): ShopApi
	local root = Instance.new("Frame")
	root.Name = "ShopPanel"
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.new(0, 16, 1, -150)
	root.Size = UDim2.fromOffset(320, 380)
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

	local gold = Theme.text(root, "Gold", "0g · at fountain", 13, Theme.cream)
	gold.Position = UDim2.fromOffset(0, 28)
	gold.Size = UDim2.new(1, 0, 0, 18)

	local hint = Theme.text(root, "Hint", "Buy with match gold. B toggles. Fountain only. Whisker Lens = key 5.", 12, Theme.peach)
	hint.Position = UDim2.fromOffset(0, 48)
	hint.Size = UDim2.new(1, 0, 0, 28)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundColor3 = Theme.panelAlt
	list.Position = UDim2.fromOffset(0, 80)
	list.Size = UDim2.new(1, 0, 1, -80)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = root
	Theme.corner(list, 10)
	Theme.pad(list, 8)
	Theme.list(list, 8)

	local buyHandler: ((string) -> ())? = nil
	local cards: { [string]: TextButton } = {}

	for index, item in ItemCatalog.all() do
		local card = Instance.new("TextButton")
		card.Name = item.id
		card.AutoButtonColor = true
		card.BackgroundColor3 = Theme.ink
		card.Text = ""
		card.LayoutOrder = index
		card.Size = UDim2.new(1, -4, 0, 58)
		card.Parent = list
		Theme.corner(card, 10)
		Theme.pad(card, 8)

		local name = Theme.text(card, "N", `{item.name}  ·  {item.cost}g`, 14, Theme.cream, Theme.fontTitle)
		name.Size = UDim2.new(1, 0, 0, 18)
		local blurb = Theme.text(card, "B", item.blurb, 12, Theme.peach)
		blurb.Position = UDim2.fromOffset(0, 20)
		blurb.Size = UDim2.new(1, 0, 1, -20)

		card.MouseButton1Click:Connect(function()
			if buyHandler then
				buyHandler(item.id)
			end
		end)
		cards[item.id] = card
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
			gold.Text = `{status.gold}g · {if status.atFountain then "at fountain" else "leave fountain to close the register"}`
			local owned = {}
			for _, id in status.owned do
				owned[id] = true
			end
			for id, card in cards do
				card.BackgroundColor3 = if owned[id] then Theme.panelAlt else Theme.ink
				local name = card:FindFirstChild("N")
				if name and name:IsA("TextLabel") then
					local item = ItemCatalog.get(id)
					if item then
						name.Text = if owned[id] then `{item.name}  ·  owned` else `{item.name}  ·  {item.cost}g`
					end
				end
			end
		end,
		onBuy = function(fn)
			buyHandler = fn
		end,
	}
end

return ShopPanel
