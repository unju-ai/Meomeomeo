--!strict

local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local MintPanel = {}

export type MintApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	toggle: () -> (),
	update: (status: Types.MintStatus) -> (),
	onBuy: (() -> ()) -> (),
	onLink: ((address: string) -> ()) -> (),
	onClaim: ((purchaseId: string) -> ()) -> (),
}

function MintPanel.create(parent: Instance): MintApi
	local root = Instance.new("Frame")
	root.Name = "MintPanel"
	root.AnchorPoint = Vector2.new(0, 0.5)
	root.Position = UDim2.new(0.5, 250, 0.48, 0)
	root.Size = UDim2.fromOffset(340, 430)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.Parent = parent
	Theme.corner(root, 20)
	Theme.stroke(root, Theme.amber, 3, 0.15)
	Theme.pad(root, 14)

	local title = Theme.text(root, "Title", "Mint Meo 404", 22, Theme.amber, Theme.fontTitle)
	title.Size = UDim2.new(1, -32, 0, 26)

	local close = Theme.button(root, "Close", "✕", Theme.coral)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, 0)
	close.Size = UDim2.fromOffset(28, 28)
	close.TextSize = 14

	local disclaimer = Theme.text(
		root,
		"Disclaimer",
		"Robux buys a Roblox product and a claim slip — not on-chain value. A hosted minter delivers the ERC-404 later.",
		12,
		Theme.peach,
		Theme.fontBody
	)
	disclaimer.Position = UDim2.fromOffset(0, 32)
	disclaimer.Size = UDim2.new(1, 0, 0, 52)

	local walletLabel = Theme.text(root, "WalletLbl", "Linked wallet: none", 12, Theme.cream)
	walletLabel.Position = UDim2.fromOffset(0, 88)
	walletLabel.Size = UDim2.new(1, 0, 0, 18)

	local walletBox = Instance.new("TextBox")
	walletBox.Name = "Wallet"
	walletBox.Position = UDim2.fromOffset(0, 108)
	walletBox.Size = UDim2.new(1, -88, 0, 32)
	walletBox.BackgroundColor3 = Theme.foam
	walletBox.TextColor3 = Theme.ink
	walletBox.PlaceholderText = "0x…"
	walletBox.Text = ""
	walletBox.TextSize = 13
	walletBox.Font = Theme.fontMono
	walletBox.ClearTextOnFocus = false
	walletBox.Parent = root
	Theme.corner(walletBox, 10)

	local linkBtn = Theme.button(root, "Link", "Link", Theme.mint)
	linkBtn.Position = UDim2.new(1, -80, 0, 108)
	linkBtn.Size = UDim2.fromOffset(80, 32)
	linkBtn.TextSize = 14

	local buyBtn = Theme.button(root, "Buy", "Buy with Robux", Theme.amber)
	buyBtn.Position = UDim2.fromOffset(0, 148)
	buyBtn.Size = UDim2.new(1, 0, 0, 36)
	buyBtn.TextSize = 16

	local hint = Theme.text(root, "Hint", "Entitlements (one purchase → one mint)", 12, Theme.peach)
	hint.Position = UDim2.fromOffset(0, 190)
	hint.Size = UDim2.new(1, 0, 0, 16)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Claims"
	list.BackgroundColor3 = Theme.panelAlt
	list.Position = UDim2.fromOffset(0, 210)
	list.Size = UDim2.new(1, 0, 1, -210)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = root
	Theme.corner(list, 10)
	Theme.pad(list, 8)
	Theme.list(list, 8)

	local buyHandler: (() -> ())? = nil
	local linkHandler: ((string) -> ())? = nil
	local claimHandler: ((string) -> ())? = nil

	close.MouseButton1Click:Connect(function()
		root.Visible = false
	end)
	buyBtn.MouseButton1Click:Connect(function()
		if buyHandler then
			buyHandler()
		end
	end)
	linkBtn.MouseButton1Click:Connect(function()
		if linkHandler then
			linkHandler(walletBox.Text)
		end
	end)

	local function clearList()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function rowFor(ent: Types.Entitlement)
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Theme.ink
		row.Size = UDim2.new(1, -4, 0, 72)
		row.Parent = list
		Theme.corner(row, 10)
		Theme.pad(row, 8)

		local statusColor = if ent.status == "Claimed"
			then Theme.good
			elseif ent.status == "Failed" then Theme.bad
			else Theme.amber
		local line = Theme.text(row, "S", `{ent.status} · {string.sub(ent.purchaseId, 1, 18)}`, 12, statusColor, Theme.fontMono)
		line.Size = UDim2.new(1, 0, 0, 16)

		local extra = Theme.text(row, "X", ent.txHash or ent.claimError or "Ready to claim", 11, Theme.cream)
		extra.Position = UDim2.fromOffset(0, 16)
		extra.Size = UDim2.new(1, 0, 0, 16)

		if ent.status ~= "Claimed" then
			local claim = Theme.button(row, "Claim", "Claim 404", Theme.coral)
			claim.Position = UDim2.new(1, -96, 1, -28)
			claim.Size = UDim2.fromOffset(96, 26)
			claim.TextSize = 13
			claim.MouseButton1Click:Connect(function()
				if claimHandler then
					claimHandler(ent.purchaseId)
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
		update = function(status: Types.MintStatus)
			disclaimer.Text = status.disclaimer
			walletLabel.Text = if status.wallet then `Linked wallet: {status.wallet}` else "Linked wallet: none"
			if status.wallet then
				walletBox.Text = status.wallet
			end
			buyBtn.Text = if status.studioMock and status.productId == 0
				then "Studio: grant mock entitlement"
				else `Buy {status.productName}`
			clearList()
			if #status.entitlements == 0 then
				local empty = Theme.text(list, "Empty", "No purchases yet.", 12, Theme.muted)
				empty.Size = UDim2.new(1, 0, 0, 20)
			else
				for _, ent in status.entitlements do
					rowFor(ent)
				end
			end
		end,
		onBuy = function(fn)
			buyHandler = fn
		end,
		onLink = function(fn)
			linkHandler = fn
		end,
		onClaim = function(fn)
			claimHandler = fn
		end,
	}
end

return MintPanel
