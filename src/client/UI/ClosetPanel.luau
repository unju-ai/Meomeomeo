--!strict

-- Hub closet: browse hats + trails, yarn-points buy, silhouette preview.

local Theme = require(script.Parent.Parent.Theme)
local CosmeticCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CosmeticCatalog"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local ClosetPanel = {}

export type ClosetApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	toggle: () -> (),
	update: (status: Types.ClosetStatus) -> (),
	onEquip: ((id: string, slot: string) -> ()) -> (),
	onBuy: ((id: string) -> ()) -> (),
	onUnequip: ((slot: string) -> ()) -> (),
}

local function rarityColor(rarity: string): Color3
	if rarity == "Epic" then
		return Theme.coral
	elseif rarity == "Rare" then
		return Theme.amber
	elseif rarity == "Uncommon" then
		return Theme.peach
	end
	return Theme.cream
end

function ClosetPanel.create(parent: Instance): ClosetApi
	local root = Instance.new("Frame")
	root.Name = "ClosetPanel"
	root.AnchorPoint = Vector2.new(0, 0.5)
	root.Position = UDim2.new(0.5, 250, 0.48, 0)
	root.Size = UDim2.fromOffset(380, 560)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.ZIndex = 15
	root.Parent = parent
	Theme.corner(root, 20)
	Theme.stroke(root, Theme.peach, 3, 0.15)
	Theme.pad(root, 14)

	local title = Theme.text(root, "Title", "Closet", 22, Theme.amber, Theme.fontTitle)
	title.Size = UDim2.new(1, -32, 0, 26)

	local close = Theme.button(root, "Close", "✕", Theme.coral)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, 0)
	close.Size = UDim2.fromOffset(28, 28)
	close.TextSize = 14

	local disclaimer = Theme.text(root, "Disclaimer", CosmeticCatalog.Disclaimer, 11, Theme.peach)
	disclaimer.Position = UDim2.fromOffset(0, 30)
	disclaimer.Size = UDim2.new(1, 0, 0, 28)

	local persist = Theme.text(root, "Persist", "Save: memory  ·  40 yarn", 11, Theme.muted, Theme.fontMono)
	persist.Position = UDim2.fromOffset(0, 58)
	persist.Size = UDim2.new(1, 0, 0, 16)

	local riftHint = Theme.text(root, "RiftHint", "Rift: win · post or stall · 5 scratches", 11, Theme.muted, Theme.fontMono)
	riftHint.Position = UDim2.fromOffset(0, 74)
	riftHint.Size = UDim2.new(1, 0, 0, 16)

	local preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.BackgroundColor3 = Theme.panelAlt
	preview.Position = UDim2.fromOffset(0, 94)
	preview.Size = UDim2.new(1, 0, 0, 88)
	preview.Parent = root
	Theme.corner(preview, 14)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundColor3 = Theme.cream
	body.Position = UDim2.fromOffset(24, 22)
	body.Size = UDim2.fromOffset(48, 52)
	body.Parent = preview
	Theme.corner(body, 16)

	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundColor3 = Theme.foam
	head.Position = UDim2.fromOffset(30, 10)
	head.Size = UDim2.fromOffset(36, 28)
	head.Parent = preview
	Theme.corner(head, 12)

	local earL = Instance.new("Frame")
	earL.Name = "EarL"
	earL.BackgroundColor3 = Theme.foam
	earL.Position = UDim2.fromOffset(32, 2)
	earL.Size = UDim2.fromOffset(10, 14)
	earL.Rotation = -18
	earL.Parent = preview
	Theme.corner(earL, 4)

	local earR = Instance.new("Frame")
	earR.Name = "EarR"
	earR.BackgroundColor3 = Theme.foam
	earR.Position = UDim2.fromOffset(54, 2)
	earR.Size = UDim2.fromOffset(10, 14)
	earR.Rotation = 18
	earR.Parent = preview
	Theme.corner(earR, 4)

	local hatBlob = Instance.new("Frame")
	hatBlob.Name = "Hat"
	hatBlob.BackgroundColor3 = Theme.amber
	hatBlob.Position = UDim2.fromOffset(34, 0)
	hatBlob.Size = UDim2.fromOffset(28, 12)
	hatBlob.Parent = preview
	Theme.corner(hatBlob, 6)

	local trailBlob = Instance.new("Frame")
	trailBlob.Name = "Trail"
	trailBlob.BackgroundColor3 = Theme.peach
	trailBlob.Position = UDim2.fromOffset(84, 28)
	trailBlob.Size = UDim2.fromOffset(40, 40)
	trailBlob.BackgroundTransparency = 0.25
	trailBlob.Parent = preview
	Theme.corner(trailBlob, 20)

	local previewLabel = Theme.text(preview, "Worn", "Cream Cap  ·  Yarn Puff", 12, Theme.cream, Theme.fontMono)
	previewLabel.Position = UDim2.fromOffset(136, 28)
	previewLabel.Size = UDim2.new(1, -148, 0, 36)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Items"
	list.BackgroundColor3 = Theme.panelAlt
	list.Position = UDim2.fromOffset(0, 190)
	list.Size = UDim2.new(1, 0, 1, -190)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = root
	Theme.corner(list, 12)
	Theme.pad(list, 8)
	Theme.list(list, 6)

	local equipHandler: ((string, string) -> ())? = nil
	local buyHandler: ((string) -> ())? = nil
	local unequipHandler: ((string) -> ())? = nil

	close.MouseButton1Click:Connect(function()
		root.Visible = false
	end)

	local function paint(status: Types.ClosetStatus)
		disclaimer.Text = status.disclaimer
		local save = if status.persistMode == "DataStore" then "DataStore" else "Memory"
		persist.Text = `Save: {save}  ·  {status.yarn} closet yarn`
		local hatName = "no hat"
		local trailName = "no trail"
		for _, row in status.items do
			local def = CosmeticCatalog.get(row.id)
			if row.equipped and row.slot == "hat" then
				hatName = row.name
				hatBlob.BackgroundColor3 = if def then def.color else rarityColor(row.rarity)
				hatBlob.Visible = true
			elseif row.equipped and row.slot == "trail" then
				trailName = row.name
				trailBlob.BackgroundColor3 = if def then def.color else rarityColor(row.rarity)
				trailBlob.Visible = true
			end
		end
		if hatName == "no hat" then
			hatBlob.Visible = false
		end
		if trailName == "no trail" then
			trailBlob.Visible = false
		end
		previewLabel.Text = `{hatName}\n{trailName}`

		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for i, row in status.items do
			local card = Instance.new("Frame")
			card.Name = row.id
			card.BackgroundColor3 = Theme.panel
			card.Size = UDim2.new(1, -4, 0, 72)
			card.LayoutOrder = i
			card.Parent = list
			Theme.corner(card, 10)
			Theme.stroke(card, rarityColor(row.rarity), 2, if row.equipped then 0.1 else 0.45)
			Theme.pad(card, 8)

			local name = Theme.text(card, "Name", row.name, 15, rarityColor(row.rarity), Theme.fontTitle)
			name.Size = UDim2.new(1, -88, 0, 18)

			local meta = Theme.text(card, "Meta", `{row.slot}  ·  {row.rarity}`, 11, Theme.muted, Theme.fontMono)
			meta.Position = UDim2.fromOffset(0, 18)
			meta.Size = UDim2.new(1, -88, 0, 14)

			local hint = Theme.text(card, "Hint", if row.owned then row.blurb else row.hint, 11, Theme.peach)
			hint.Position = UDim2.fromOffset(0, 34)
			hint.Size = UDim2.new(1, -88, 0, 28)

			local action: TextButton
			if row.owned then
				action = Theme.button(card, "Act", if row.equipped then "Worn" else "Equip", if row.equipped then Theme.mint else Theme.amber)
			elseif row.cost > 0 then
				action = Theme.button(card, "Act", `{row.cost} yarn`, Theme.peach)
			else
				action = Theme.button(card, "Act", "Locked", Theme.muted)
				action.Active = false
				action.AutoButtonColor = false
			end
			action.AnchorPoint = Vector2.new(1, 0.5)
			action.Position = UDim2.new(1, 0, 0.5, 0)
			action.Size = UDim2.fromOffset(78, 32)
			action.TextSize = 13
			local id = row.id
			local slot = row.slot
			local owned = row.owned
			local equipped = row.equipped
			local cost = row.cost
			action.MouseButton1Click:Connect(function()
				if owned then
					if equipped then
						if unequipHandler then
							unequipHandler(slot)
						end
					elseif equipHandler then
						equipHandler(id, slot)
					end
				elseif cost > 0 and buyHandler then
					buyHandler(id)
				end
			end)
		end
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
		end,
		toggle = function()
			root.Visible = not root.Visible
		end,
		update = paint,
		onEquip = function(fn)
			equipHandler = fn
		end,
		onBuy = function(fn)
			buyHandler = fn
		end,
		onUnequip = function(fn)
			unequipHandler = fn
		end,
	}
end

return ClosetPanel
