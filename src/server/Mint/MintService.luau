--!strict

-- Roblox half of the Meo404 bridge.
-- ProcessReceipt grants a persistent entitlement. A hosted service mints on-chain later.
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

local DISCLAIMER =
	"Robux buys a Roblox Developer Product. That creates a claim entitlement — not a crypto transfer. A separate hosted service mints Meo404 after you link a wallet. No private keys in this place. Legal review required before a live Robux product."

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
		wallet = EntitlementStore.getLinkedWallet(player.UserId),
		productId = Config.Nft404.DeveloperProductId,
		productName = Config.Nft404.ProductName,
		studioMock = RunService:IsStudio() and Config.Nft404.AllowStudioMockPurchase,
		persistMode = EntitlementStore.getPersistMode(),
		persistNote = EntitlementStore.getPersistNote(),
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
		return { ok = false, error = "Need a 42-character 0x hex wallet (not the zero address)." }
	end
	-- TODO: verify ownership with a hosted SIWE (or similar) challenge.
	-- Roblox cannot prove chain signatures safely on its own.
	EntitlementStore.setLinkedWallet(player.UserId, trimmed)
	for _, row in EntitlementStore.listForUser(player.UserId) do
		if row.status ~= "Claimed" then
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
	local ent = EntitlementStore.grant({
		purchaseId = purchaseId,
		userId = userId,
		productId = productId,
		nonce = nonceFor(purchaseId, userId),
	})
	local player = Players:GetPlayerByUserId(userId)
	if player then
		local wallet = EntitlementStore.getLinkedWallet(userId)
		if wallet and ent.status ~= "Claimed" then
			EntitlementStore.setWallet(purchaseId, wallet)
		end
		push(player)
	end
	return true
end

-- Studio / QA: grant without Robux. Reusing purchaseId is idempotent.
function MintService.grantProduct(player: Player, purchaseId: unknown): Types.TradeResult
	if not RunService:IsStudio() or not Config.Nft404.AllowStudioMockPurchase then
		return { ok = false, error = "GrantProduct is Studio-only. Use a real Developer Product on a published place." }
	end
	local id: string
	if typeof(purchaseId) == "string" and purchaseId ~= "" then
		if not string.match(purchaseId, "^[%w%-%._]+$") then
			return { ok = false, error = "PurchaseId has invalid characters." }
		end
		id = purchaseId
	else
		local n = #EntitlementStore.listForUser(player.UserId) + 1
		id = `studio-{player.UserId}-{os.time()}-{n}`
	end
	MintService.grantFromReceipt(player.UserId, Config.Nft404.DeveloperProductId, id)
	return { ok = true }
end

-- Re-run grant for an existing or synthetic PurchaseId (ProcessReceipt retry / Studio QA).
function MintService.replayReceipt(player: Player, purchaseId: unknown): Types.TradeResult
	if not RunService:IsStudio() or not Config.Nft404.AllowStudioMockPurchase then
		return { ok = false, error = "ReplayReceipt is Studio-only." }
	end
	if typeof(purchaseId) ~= "string" or purchaseId == "" then
		return { ok = false, error = "PurchaseId required to replay a receipt." }
	end
	if not string.match(purchaseId, "^[%w%-%._]+$") then
		return { ok = false, error = "PurchaseId has invalid characters." }
	end
	local existing = EntitlementStore.get(purchaseId)
	if existing and existing.userId ~= player.UserId then
		return { ok = false, error = "That PurchaseId belongs to another user." }
	end
	MintService.grantFromReceipt(player.UserId, Config.Nft404.DeveloperProductId, purchaseId)
	return { ok = true }
end

function MintService.simulateStudioPurchase(player: Player): Types.TradeResult
	return MintService.grantProduct(player, nil)
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
		-- Idempotent: already minted. Client treats ok as success.
		return { ok = true }
	end
	local wallet = EntitlementStore.getLinkedWallet(player.UserId)
	if not wallet then
		return { ok = false, error = "Link a 0x wallet first (saved per Roblox user)." }
	end

	EntitlementStore.setWallet(purchaseId, wallet)
	local result = ClaimApi.submit(row, wallet)
	if result.ok and result.txHash then
		EntitlementStore.markClaimed(purchaseId, result.txHash)
		push(player)
		return { ok = true }
	end
	-- Stay retryable: Failed is visible in the panel, Claim still works next click.
	EntitlementStore.markFailed(purchaseId, result.error or "Claim API / mock failed")
	push(player)
	return { ok = false, error = result.error or "Claim API / mock failed" }
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

	-- Wallets and entitlements stay in DataStore / cache for the next session.
end

return MintService
