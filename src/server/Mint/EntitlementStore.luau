--!strict

-- Persistent Meo404 entitlements + per-user wallets.
-- DataStoreService when available; in-memory cache always; Studio/API failure falls back to memory.
--
-- Store name: Meo404_v1
--   ent:{purchaseId}           → Types.Entitlement
--   user:{userId}:ents         → { ids: { purchaseId, ... } }
--   user:{userId}:wallet       → "0x…"
--
-- Grant is idempotent by PurchaseId (ProcessReceipt retries / receipt replay).

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local STORE_NAME = "Meo404_v1"

local EntitlementStore = {}

local store: any = nil
local persistMode: "DataStore" | "Memory" = "Memory"
local persistNote = "In-memory only (DataStore not bound). Studio playtests still work."

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and result then
		store = result
		persistMode = "DataStore"
		if RunService:IsStudio() then
			persistNote = "DataStore Meo404_v1 bound (Studio). Enable API access so writes survive the session."
		else
			persistNote = "DataStore Meo404_v1 — entitlements and wallets persist across sessions."
		end
	end
end

type Cache = {
	byPurchaseId: { [string]: Types.Entitlement },
	byUserId: { [number]: { string } },
	wallets: { [number]: string },
	userIndexLoaded: { [number]: boolean },
	walletLoaded: { [number]: boolean },
}

local cache: Cache = {
	byPurchaseId = {},
	byUserId = {},
	wallets = {},
	userIndexLoaded = {},
	walletLoaded = {},
}

local function cloneEnt(ent: Types.Entitlement): Types.Entitlement
	return {
		purchaseId = ent.purchaseId,
		userId = ent.userId,
		productId = ent.productId,
		nonce = ent.nonce,
		createdAt = ent.createdAt,
		status = ent.status,
		wallet = ent.wallet,
		txHash = ent.txHash,
		claimError = ent.claimError,
	}
end

local function hydrateEnt(value: any): Types.Entitlement?
	if typeof(value) ~= "table" then
		return nil
	end
	if typeof(value.purchaseId) ~= "string" or typeof(value.userId) ~= "number" then
		return nil
	end
	local status = value.status
	if status ~= "Granted" and status ~= "Claimed" and status ~= "Failed" then
		status = "Granted"
	end
	return {
		purchaseId = value.purchaseId,
		userId = value.userId,
		productId = if typeof(value.productId) == "number" then value.productId else 0,
		nonce = if typeof(value.nonce) == "string" then value.nonce else `{value.userId}-{value.purchaseId}`,
		createdAt = if typeof(value.createdAt) == "number" then value.createdAt else os.time(),
		status = status,
		wallet = if typeof(value.wallet) == "string" then value.wallet else nil,
		txHash = if typeof(value.txHash) == "string" then value.txHash else nil,
		claimError = if typeof(value.claimError) == "string" then value.claimError else nil,
	}
end

local function dsGet(key: string): (any, boolean)
	if not store then
		return nil, false
	end
	local ok, value = pcall(function()
		return store:GetAsync(key)
	end)
	if ok then
		return value, true
	end
	persistNote = "DataStore GetAsync failed — using memory cache (enable Studio API Services to persist)."
	return nil, false
end

local function dsSet(key: string, value: any): boolean
	if not store then
		return false
	end
	local ok = pcall(function()
		store:SetAsync(key, value)
	end)
	if not ok then
		persistNote = "DataStore SetAsync failed — this write stayed in memory only."
	end
	return ok
end

local function rememberUser(userId: number, purchaseId: string)
	local list = cache.byUserId[userId]
	if not list then
		list = {}
		cache.byUserId[userId] = list
	end
	if table.find(list, purchaseId) == nil then
		table.insert(list, purchaseId)
	end
end

local function persistEnt(ent: Types.Entitlement)
	dsSet("ent:" .. ent.purchaseId, cloneEnt(ent))
end

local function persistUserIndex(userId: number)
	local ids = cache.byUserId[userId] or {}
	dsSet("user:" .. tostring(userId) .. ":ents", { ids = ids })
end

function EntitlementStore.getPersistMode(): "DataStore" | "Memory"
	return persistMode
end

function EntitlementStore.getPersistNote(): string
	return persistNote
end

function EntitlementStore.getLinkedWallet(userId: number): string?
	if cache.walletLoaded[userId] then
		return cache.wallets[userId]
	end
	local value, reached = dsGet("user:" .. tostring(userId) .. ":wallet")
	cache.walletLoaded[userId] = true
	if reached and typeof(value) == "string" and value ~= "" then
		cache.wallets[userId] = value
		return value
	end
	return cache.wallets[userId]
end

function EntitlementStore.setLinkedWallet(userId: number, address: string)
	cache.wallets[userId] = address
	cache.walletLoaded[userId] = true
	dsSet("user:" .. tostring(userId) .. ":wallet", address)
end

function EntitlementStore.get(purchaseId: string): Types.Entitlement?
	local cached = cache.byPurchaseId[purchaseId]
	if cached then
		return cached
	end
	local value, reached = dsGet("ent:" .. purchaseId)
	if not reached then
		return nil
	end
	local row = hydrateEnt(value)
	if not row then
		return nil
	end
	cache.byPurchaseId[purchaseId] = row
	rememberUser(row.userId, purchaseId)
	return row
end

function EntitlementStore.listForUser(userId: number): { Types.Entitlement }
	if not cache.userIndexLoaded[userId] then
		local value, reached = dsGet("user:" .. tostring(userId) .. ":ents")
		if reached and typeof(value) == "table" and typeof(value.ids) == "table" then
			for _, purchaseId in value.ids do
				if typeof(purchaseId) == "string" then
					EntitlementStore.get(purchaseId)
				end
			end
		end
		cache.userIndexLoaded[userId] = true
		cache.byUserId[userId] = cache.byUserId[userId] or {}
	end
	local ids = cache.byUserId[userId] or {}
	local out = {}
	for _, id in ids do
		local row = cache.byPurchaseId[id]
		if row then
			table.insert(out, cloneEnt(row))
		end
	end
	table.sort(out, function(a, b)
		return a.createdAt > b.createdAt
	end)
	return out
end

function EntitlementStore.grant(info: {
	purchaseId: string,
	userId: number,
	productId: number,
	nonce: string,
}): Types.Entitlement
	local existing = EntitlementStore.get(info.purchaseId)
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
	cache.byPurchaseId[info.purchaseId] = row
	rememberUser(info.userId, info.purchaseId)
	persistEnt(row)
	persistUserIndex(info.userId)
	return row
end

function EntitlementStore.setWallet(purchaseId: string, wallet: string)
	local row = EntitlementStore.get(purchaseId)
	if not row then
		return
	end
	row.wallet = wallet
	persistEnt(row)
end

function EntitlementStore.markClaimed(purchaseId: string, txHash: string)
	local row = EntitlementStore.get(purchaseId)
	if not row then
		return
	end
	row.status = "Claimed"
	row.txHash = txHash
	row.claimError = nil
	persistEnt(row)
end

function EntitlementStore.markFailed(purchaseId: string, err: string)
	local row = EntitlementStore.get(purchaseId)
	if not row or row.status == "Claimed" then
		return
	end
	row.status = "Failed"
	row.claimError = err
	persistEnt(row)
end

return EntitlementStore
