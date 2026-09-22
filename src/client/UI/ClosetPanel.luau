--!strict

-- Hub closet: browse hats + trails, yarn-points buy, silhouette try-on preview.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Theme)
local CosmeticCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CosmeticCatalog"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local ClosetPanel = {}

export type ClosetApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	toggle: () -> (),
	update: (status: Types.ClosetStatus) -> (),
	flashPreview: (tint: Color3?) -> (),
	onEquip: ((id: string, slot: string) -> ()) -> (),
	onBuy: ((id: string) -> ()) -> (),
	onUnequip: ((slot: string) -> ()) -> (),
}

local function rarityColor(rarity: string): Color3
	return CosmeticCatalog.rarityTint(rarity :: any)
end

local function makeChip(parent: Instance, name: string, text: string, fill: Color3, ink: Color3?): TextLabel
	local chip = Instance.new("TextLabel")
	chip.Name = name
	chip.BackgroundColor3 = fill
	chip.BackgroundTransparency = 0.12
	chip.Text = text
	chip.TextColor3 = ink or Theme.ink
	chip.TextSize = 11
	chip.Font = Theme.fontMono
	chip.TextXAlignment = Enum.TextXAlignment.Center
	chip.Size = UDim2.fromOffset(52, 18)
	chip.Parent = parent
	Theme.corner(chip, 6)
	return chip
end

function ClosetPanel.create(parent: Instance): ClosetApi
	local root = Instance.new("Frame")
	root.Name = "ClosetPanel"
	root.AnchorPoint = Vector2.new(0, 0.5)
	root.Position = UDim2.new(0.5, 250, 0.48, 0)
	root.Size = UDim2.fromOffset(400, 580)
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

	local riftHint = Theme.text(root, "RiftHint", "Rift · Run · Koi · Party · Arcade unlock chips", 11, Theme.muted, Theme.fontMono)
	riftHint.Position = UDim2.fromOffset(0, 74)
	riftHint.Size = UDim2.new(1, 0, 0, 16)

	local preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.BackgroundColor3 = Theme.panelAlt
	preview.Position = UDim2.fromOffset(0, 94)
	preview.Size = UDim2.new(1, 0, 0, 96)
	preview.Parent = root
	Theme.corner(preview, 14)
	local previewStroke = Theme.stroke(preview, Theme.peach, 2, 0.55)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundColor3 = Theme.cream
	body.Position = UDim2.fromOffset(24, 26)
	body.Size = UDim2.fromOffset(48, 52)
	body.Parent = preview
	Theme.corner(body, 16)

	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundColor3 = Theme.foam
	head.Position = UDim2.fromOffset(30, 14)
	head.Size = UDim2.fromOffset(36, 28)
	head.Parent = preview
	Theme.corner(head, 12)

	local earL = Instance.new("Frame")
	earL.Name = "EarL"
	earL.BackgroundColor3 = Theme.foam
	earL.Position = UDim2.fromOffset(32, 6)
	earL.Size = UDim2.fromOffset(10, 14)
	earL.Rotation = -18
	earL.Parent = preview
	Theme.corner(earL, 4)

	local earR = Instance.new("Frame")
	earR.Name = "EarR"
	earR.BackgroundColor3 = Theme.foam
	earR.Position = UDim2.fromOffset(54, 6)
	earR.Size = UDim2.fromOffset(10, 14)
	earR.Rotation = 18
	earR.Parent = preview
	Theme.corner(earR, 4)

	local hatBlob = Instance.new("Frame")
	hatBlob.Name = "Hat"
	hatBlob.BackgroundColor3 = Theme.amber
	hatBlob.Position = UDim2.fromOffset(34, 4)
	hatBlob.Size = UDim2.fromOffset(28, 12)
	hatBlob.Parent = preview
	Theme.corner(hatBlob, 6)

	local trailBlob = Instance.new("Frame")
	trailBlob.Name = "Trail"
	trailBlob.BackgroundColor3 = Theme.peach
	trailBlob.Position = UDim2.fromOffset(84, 32)
	trailBlob.Size = UDim2.fromOffset(40, 40)
	trailBlob.BackgroundTransparency = 0.25
	trailBlob.Parent = preview
	Theme.corner(trailBlob, 20)

	local previewLabel = Theme.text(preview, "Worn", "Cream Cap  ·  Yarn Puff", 12, Theme.cream, Theme.fontMono)
	previewLabel.Position = UDim2.fromOffset(136, 22)
	previewLabel.Size = UDim2.new(1, -148, 0, 36)

	local previewHint = Theme.text(preview, "TryOn", "Hover a row to try on", 11, Theme.muted, Theme.fontMono)
	previewHint.Position = UDim2.fromOffset(136, 58)
	previewHint.Size = UDim2.new(1, -148, 0, 18)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Items"
	list.BackgroundColor3 = Theme.panelAlt
	list.Position = UDim2.fromOffset(0, 200)
	list.Size = UDim2.new(1, 0, 1, -200)
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

	local lastStatus: Types.ClosetStatus? = nil
	local browseId: string? = nil
	local flashToken = 0

	close.MouseButton1Click:Connect(function()
		root.Visible = false
	end)

	local function applySilhouette(hatId: string?, trailId: string?, ghostHat: boolean, ghostTrail: boolean, label: string, hint: string)
		if hatId and hatId ~= "" then
			local def = CosmeticCatalog.get(hatId)
			hatBlob.Visible = true
			hatBlob.BackgroundColor3 = if def then def.color else Theme.amber
			hatBlob.BackgroundTransparency = if ghostHat then 0.45 else 0
		else
			hatBlob.Visible = false
			hatBlob.BackgroundTransparency = 0
		end
		if trailId and trailId ~= "" then
			local def = CosmeticCatalog.get(trailId)
			trailBlob.Visible = true
			trailBlob.BackgroundColor3 = if def then def.color else Theme.peach
			trailBlob.BackgroundTransparency = if ghostTrail then 0.55 else 0.22
		else
			trailBlob.Visible = false
			trailBlob.BackgroundTransparency = 0.25
		end
		previewLabel.Text = label
		previewHint.Text = hint
	end

	local function paintPreview(status: Types.ClosetStatus)
		local equippedHat: string? = status.hat
		local equippedTrail: string? = status.trail
		local hatName = "no hat"
		local trailName = "no trail"
		for _, row in status.items do
			if row.equipped and row.slot == "hat" then
				equippedHat = row.id
				hatName = row.name
			elseif row.equipped and row.slot == "trail" then
				equippedTrail = row.id
				trailName = row.name
			end
		end

		local browse = if browseId then CosmeticCatalog.get(browseId) else nil
		if browse then
			local browseRow: Types.CosmeticRow? = nil
			for _, row in status.items do
				if row.id == browse.id then
					browseRow = row
					break
				end
			end
			local ghost = browseRow == nil or browseRow.locked or not browseRow.owned
			local tryHat = equippedHat
			local tryTrail = equippedTrail
			local tryHatName = hatName
			local tryTrailName = trailName
			local ghostHat = false
			local ghostTrail = false
			if browse.slot == "hat" then
				tryHat = browse.id
				tryHatName = browse.name
				ghostHat = ghost
			else
				tryTrail = browse.id
				tryTrailName = browse.name
				ghostTrail = ghost
			end
			local mode = if ghost then "Try-on (locked)" else if browseRow and browseRow.equipped then "Equipped" else "Try-on"
			applySilhouette(tryHat, tryTrail, ghostHat, ghostTrail, `{tryHatName}\n{tryTrailName}`, mode)
			return
		end

		applySilhouette(equippedHat, equippedTrail, false, false, `{hatName}\n{trailName}`, "Hover a row to try on")
	end

	local function paint(status: Types.ClosetStatus)
		lastStatus = status
		disclaimer.Text = status.disclaimer
		local save = if status.persistMode == "DataStore" then "DataStore" else "Memory"
		persist.Text = `Save: {save}  ·  {status.yarn} closet yarn`
		paintPreview(status)

		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for i, row in status.items do
			local def = CosmeticCatalog.get(row.id)
			local tint = rarityColor(row.rarity)
			local sourceKind = if def then def.unlock.kind else "free"
			local source = CosmeticCatalog.unlockSource(sourceKind)
			local sourceTint = CosmeticCatalog.unlockSourceTint(sourceKind)
			local locked = row.locked and not row.owned
			local browsing = browseId == row.id

			local card = Instance.new("Frame")
			card.Name = row.id
			card.BackgroundColor3 = if locked then Color3.fromRGB(36, 26, 24) else Theme.panel
			card.BackgroundTransparency = if locked then 0.08 else 0
			card.Size = UDim2.new(1, -4, 0, 84)
			card.LayoutOrder = i
			card.Parent = list
			Theme.corner(card, 10)
			local strokeTransparency = if row.equipped then 0.05 elseif browsing then 0.18 elseif locked then 0.62 else 0.4
			local stroke = Theme.stroke(card, if row.equipped then Theme.mint else tint, if row.equipped then 3 else 2, strokeTransparency)
			Theme.pad(card, 8)

			local nameColor = if locked then Theme.muted else tint
			local name = Theme.text(card, "Name", if row.equipped then `✓  {row.name}` else row.name, 15, nameColor, Theme.fontTitle)
			name.Size = UDim2.new(1, -96, 0, 18)

			local chipRow = Instance.new("Frame")
			chipRow.Name = "Chips"
			chipRow.BackgroundTransparency = 1
			chipRow.Position = UDim2.fromOffset(0, 20)
			chipRow.Size = UDim2.new(1, -96, 0, 20)
			chipRow.Parent = card
			Theme.list(chipRow, 6, Enum.FillDirection.Horizontal)

			local rarityChip = makeChip(chipRow, "Rarity", CosmeticCatalog.rarityTag(row.rarity), tint, Theme.ink)
			rarityChip.LayoutOrder = 1
			rarityChip.Size = UDim2.fromOffset(46, 18)
			if locked then
				rarityChip.BackgroundTransparency = 0.35
			end

			local sourceChip = makeChip(chipRow, "Source", source, sourceTint, Theme.ink)
			sourceChip.LayoutOrder = 2
			sourceChip.Size = UDim2.fromOffset(58, 18)
			if locked then
				sourceChip.BackgroundTransparency = 0.35
			end

			if row.equipped then
				local worn = makeChip(chipRow, "Worn", "ON", Theme.mint, Theme.ink)
				worn.LayoutOrder = 3
				worn.Size = UDim2.fromOffset(32, 18)
			elseif locked then
				local lockChip = makeChip(chipRow, "Lock", "LOCK", Theme.muted, Theme.cream)
				lockChip.LayoutOrder = 3
				lockChip.Size = UDim2.fromOffset(40, 18)
				lockChip.BackgroundTransparency = 0.2
			elseif row.owned then
				local own = makeChip(chipRow, "Own", "OWN", Theme.cream, Theme.ink)
				own.LayoutOrder = 3
				own.Size = UDim2.fromOffset(36, 18)
			end

			local hintText = if row.owned then row.blurb else row.hint
			local hintColor = if locked then Theme.muted elseif row.owned then Theme.peach else sourceTint
			local hint = Theme.text(card, "Hint", hintText, 11, hintColor)
			hint.Position = UDim2.fromOffset(0, 44)
			hint.Size = UDim2.new(1, -96, 0, 30)

			local action: TextButton
			if row.owned then
				action = Theme.button(card, "Act", if row.equipped then "Worn ✓" else "Equip", if row.equipped then Theme.mint else Theme.amber)
			elseif row.cost > 0 then
				action = Theme.button(card, "Act", `{row.cost} yarn`, Theme.peach)
			else
				action = Theme.button(card, "Act", "Locked", Theme.muted)
				action.Active = false
				action.AutoButtonColor = false
				action.TextColor3 = Theme.cream
			end
			action.AnchorPoint = Vector2.new(1, 0.5)
			action.Position = UDim2.new(1, 0, 0.5, 0)
			action.Size = UDim2.fromOffset(86, 34)
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

			local function setBrowse(active: boolean)
				if active then
					browseId = id
					stroke.Transparency = 0.12
				elseif browseId == id then
					browseId = nil
					stroke.Transparency = strokeTransparency
				end
				if lastStatus then
					paintPreview(lastStatus)
				end
			end
			card.MouseEnter:Connect(function()
				setBrowse(true)
			end)
			card.MouseLeave:Connect(function()
				setBrowse(false)
			end)
		end
	end

	local function flashPreview(tint: Color3?)
		flashToken += 1
		local token = flashToken
		local color = tint or Theme.amber
		previewStroke.Color = color
		previewStroke.Transparency = 0.05
		previewStroke.Thickness = 3
		hatBlob.Size = UDim2.fromOffset(34, 16)
		trailBlob.Size = UDim2.fromOffset(48, 48)
		TweenService:Create(previewStroke, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 0.55,
			Thickness = 2,
		}):Play()
		TweenService:Create(hatBlob, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(28, 12),
		}):Play()
		TweenService:Create(trailBlob, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(40, 40),
		}):Play()
		task.delay(0.5, function()
			if token ~= flashToken then
				return
			end
			previewStroke.Color = Theme.peach
		end)
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if not visible then
				browseId = nil
			end
		end,
		toggle = function()
			root.Visible = not root.Visible
			if not root.Visible then
				browseId = nil
			end
		end,
		update = paint,
		flashPreview = flashPreview,
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
