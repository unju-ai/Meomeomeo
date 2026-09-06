--!strict

-- In-memory entitlement ledger for the scaffold.
-- TODO: persist with DataStoreService (OrderedDataStore / key per PurchaseId)
--       or POST to the hosted claim API so ProcessReceipt retries survive
--       server hops. PurchaseId is the idempotency key.

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local EntitlementStore = {}

local byPurchaseId: { [string]: Types.Entitlement } = {}
local byUserId: { [number]: { string } } = {}

local function rememberUser(userId: number, purchaseId: string)
	local list = byUserId[userId]
	if not list then
		list = {}
		byUserId[userId] = list
	end
	if table.find(list, purchaseId) == nil then
		table.insert(list, purchaseId)
	end
end

function EntitlementStore.get(purchaseId: string): Types.Entitlement?
	return byPurchaseId[purchaseId]
end

function EntitlementStore.listForUser(userId: number): { Types.Entitlement }
	local ids = byUserId[userId] or {}
	local out = {}
	for _, id in ids do
		local row = byPurchaseId[id]
		if row then
			table.insert(out, row)
		end
	end
	return out
end

function EntitlementStore.grant(info: {
	purchaseId: string,
	userId: number,
	productId: number,
	nonce: string,
}): Types.Entitlement
	local existing = byPurchaseId[info.purchaseId]
	if existing then
		return existing
	end
	local row: Types.Entitlement = {
		purchaseId = info.purchaseId,
		userId = info.userId,
		productId = info.productId,
		nonce = info.nonce,
		createdAt = os.time(),
		status = "Granted",
		wallet = nil,
		txHash = nil,
		claimError = nil,
	}
	byPurchaseId[info.purchaseId] = row
	rememberUser(info.userId, info.purchaseId)
	return row
end

function EntitlementStore.setWallet(purchaseId: string, wallet: string)
	local row = byPurchaseId[purchaseId]
	if row then
		row.wallet = wallet
	end
end

function EntitlementStore.markClaimed(purchaseId: string, txHash: string)
	local row = byPurchaseId[purchaseId]
	if row then
		row.status = "Claimed"
		row.txHash = txHash
		row.claimError = nil
	end
end

function EntitlementStore.markFailed(purchaseId: string, err: string)
	local row = byPurchaseId[purchaseId]
	if row and row.status ~= "Claimed" then
		row.status = "Failed"
		row.claimError = err
	end
end

return EntitlementStore
