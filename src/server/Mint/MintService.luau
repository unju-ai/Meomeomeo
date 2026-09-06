--!strict

-- Roblox half of the Meo404 bridge.
-- ProcessReceipt grants an entitlement. A hosted service mints on-chain later.
-- This is NOT a Robux → crypto swap. See README.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Parent.Config)
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local ClaimApi = require(script.Parent.ClaimApi)
local EntitlementStore = require(script.Parent.EntitlementStore)

local MintService = {}

local wallets: { [number]: string } = {}

local DISCLAIMER =
	"Robux buys a Roblox Developer Product. That creates a claim entitlement — not a crypto transfer. A separate hosted service mints Meo404 after you link a wallet. Legal review required before production."

local function isHexAddress(value: string): boolean
	if #value ~= 42 then
		return false
	end
	if string.sub(value, 1, 2) ~= "0x" and string.sub(value, 1, 2) ~= "0X" then
		return false
	end
	local body = string.sub(value, 3)
	return string.match(body, "^[0-9a-fA-F]+$") ~= nil and string.lower(body) ~= string.rep("0", 40)
end

local function nonceFor(purchaseId: string, userId: number): string
	return `{userId}-{purchaseId}`
end

local function snapshot(player: Player): Types.MintStatus
	return {
		wallet = wallets[player.UserId],
		productId = Config.Nft404.DeveloperProductId,
		productName = Config.Nft404.ProductName,
		studioMock = RunService:IsStudio() and Config.Nft404.AllowStudioMockPurchase,
		entitlements = EntitlementStore.listForUser(player.UserId),
		disclaimer = DISCLAIMER,
	}
end

local function push(player: Player)
	Remotes.event("MintStatusChanged"):FireClient(player, snapshot(player))
end

function MintService.getStatus(player: Player): Types.MintStatus
	return snapshot(player)
end

function MintService.linkWallet(player: Player, address: unknown): Types.TradeResult
	if typeof(address) ~= "string" then
		return { ok = false, error = "Wallet must be a 0x address string." }
	end
	local trimmed = string.gsub(address, "%s+", "")
	if not isHexAddress(trimmed) then
		return { ok = false, error = "Need a 42-character 0x wallet (not the zero address)." }
	end
	-- TODO: verify ownership with a hosted SIWE (or similar) challenge.
	-- Roblox cannot prove chain signatures safely on its own.
	wallets[player.UserId] = trimmed
	for _, row in EntitlementStore.listForUser(player.UserId) do
		if row.status == "Granted" then
			EntitlementStore.setWallet(row.purchaseId, trimmed)
		end
	end
	push(player)
	return { ok = true }
end

function MintService.grantFromReceipt(userId: number, productId: number, purchaseId: string): boolean
	if productId ~= Config.Nft404.DeveloperProductId and not (Config.Nft404.AllowStudioMockPurchase and productId == -1) then
		return false
	end
	EntitlementStore.grant({
		purchaseId = purchaseId,
		userId = userId,
		productId = productId,
		nonce = nonceFor(purchaseId, userId),
	})
	local player = Players:GetPlayerByUserId(userId)
	if player then
		local wallet = wallets[userId]
		if wallet then
			EntitlementStore.setWallet(purchaseId, wallet)
		end
		push(player)
	end
	return true
end

function MintService.simulateStudioPurchase(player: Player): Types.TradeResult
	if not RunService:IsStudio() or not Config.Nft404.AllowStudioMockPurchase then
		return { ok = false, error = "Studio mock purchase is disabled. Use a real Developer Product." }
	end
	local purchaseId = `studio-{player.UserId}-{os.time()}-{#EntitlementStore.listForUser(player.UserId) + 1}`
	MintService.grantFromReceipt(player.UserId, Config.Nft404.DeveloperProductId, purchaseId)
	return { ok = true }
end

function MintService.claim(player: Player, purchaseId: unknown): Types.TradeResult
	if typeof(purchaseId) ~= "string" then
		return { ok = false, error = "Missing purchaseId." }
	end
	local row = EntitlementStore.get(purchaseId)
	if not row or row.userId ~= player.UserId then
		return { ok = false, error = "No entitlement for that purchase." }
	end
	if row.status == "Claimed" then
		return { ok = false, error = "Already claimed. One purchase → one mint." }
	end
	local wallet = wallets[player.UserId]
	if not wallet then
		return { ok = false, error = "Link a wallet first." }
	end

	EntitlementStore.setWallet(purchaseId, wallet)
	local result = ClaimApi.submit(row, wallet)
	if result.ok and result.txHash then
		EntitlementStore.markClaimed(purchaseId, result.txHash)
		push(player)
		return { ok = true }
	end
	EntitlementStore.markFailed(purchaseId, result.error or "Claim failed")
	push(player)
	return { ok = false, error = result.error or "Claim failed" }
end

function MintService.init()
	MarketplaceService.ProcessReceipt = function(receipt)
		local productId = receipt.ProductId
		local expected = Config.Nft404.DeveloperProductId
		if expected == 0 then
			-- Product id not configured yet; still record so Studio wiring can be tested.
			if not (RunService:IsStudio() and Config.Nft404.AllowStudioMockPurchase) then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
		elseif productId ~= expected then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local ok = pcall(function()
			MintService.grantFromReceipt(receipt.PlayerId, productId, receipt.PurchaseId)
		end)
		if not ok then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	Players.PlayerRemoving:Connect(function(player)
		wallets[player.UserId] = nil
	end)
end

return MintService
