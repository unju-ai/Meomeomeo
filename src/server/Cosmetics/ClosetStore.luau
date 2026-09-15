--!strict

-- Per-player closet: owned drip + equipped hat/trail + closet yarn.
-- DataStore when available; memory cache always. Studio without API Services stays in-memory.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CosmeticCatalog = require(Shared:WaitForChild("CosmeticCatalog"))
local Types = require(Shared:WaitForChild("Types"))

local STORE_NAME = "MeoCloset_v1"

export type Record = {
	owned: { string },
	hat: string?,
	trail: string?,
	yarn: number,
	persistMode: Types.PersistMode,
}

local ClosetStore = {}

local store: any = nil
local persistMode: Types.PersistMode = "Memory"
local cache: { [number]: Record } = {}

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and result then
		store = result
		persistMode = "DataStore"
	end
end

local function keyOf(userId: number): string
	return `user:{userId}:closet`
end

local function clampYarn(value: number): number
	return math.clamp(math.floor(value + 0.5), 0, 9999)
end

local function sanitizeEquip(id: string?, slot: CosmeticCatalog.Slot, owned: { [string]: boolean }): string?
	local def = CosmeticCatalog.get(id)
	if not def or def.slot ~= slot or not owned[def.id] then
		return nil
	end
	return def.id
end

local function defaults(): Record
	local starters = CosmeticCatalog.starters()
	local hat: string? = nil
	local trail: string? = nil
	for _, id in starters do
		local def = CosmeticCatalog.get(id)
		if def and def.slot == "hat" and hat == nil then
			hat = id
		elseif def and def.slot == "trail" and trail == nil then
			trail = id
		end
	end
	return {
		owned = starters,
		hat = hat,
		trail = trail,
		yarn = CosmeticCatalog.StartYarn,
		persistMode = persistMode,
	}
end

local function hydrate(value: any): Record
	local row = defaults()
	if typeof(value) ~= "table" then
		return row
	end
	local ownedIn: { string } = {}
	if typeof(value.owned) == "table" then
		for _, id in value.owned do
			if typeof(id) == "string" then
				table.insert(ownedIn, id)
			end
		end
	end
	row.owned = CosmeticCatalog.ownedList(ownedIn)
	local ownedSet = CosmeticCatalog.ownedSet(row.owned)
	row.hat = sanitizeEquip(value.hat, "hat", ownedSet)
	row.trail = sanitizeEquip(value.trail, "trail", ownedSet)
	if typeof(value.yarn) == "number" then
		row.yarn = clampYarn(value.yarn)
	end
	row.persistMode = persistMode
	return row
end

local function persist(userId: number, row: Record)
	if not store then
		return
	end
	local ok = pcall(function()
		store:SetAsync(keyOf(userId), {
			owned = row.owned,
			hat = row.hat,
			trail = row.trail,
			yarn = row.yarn,
		})
	end)
	if not ok and RunService:IsStudio() then
		persistMode = "Memory"
		row.persistMode = persistMode
	end
end

function ClosetStore.persistMode(): Types.PersistMode
	return persistMode
end

function ClosetStore.get(userId: number): Record
	local cached = cache[userId]
	if cached then
		cached.persistMode = persistMode
		return cached
	end
	if store then
		local ok, value = pcall(function()
			return store:GetAsync(keyOf(userId))
		end)
		if ok then
			local row = hydrate(value)
			cache[userId] = row
			return row
		end
		if RunService:IsStudio() then
			persistMode = "Memory"
		end
	end
	local row = defaults()
	cache[userId] = row
	return row
end

function ClosetStore.grant(userId: number, id: string): boolean
	local def = CosmeticCatalog.get(id)
	if not def then
		return false
	end
	local row = ClosetStore.get(userId)
	for _, owned in row.owned do
		if owned == id then
			return false
		end
	end
	table.insert(row.owned, id)
	row.owned = CosmeticCatalog.ownedList(row.owned)
	persist(userId, row)
	return true
end

function ClosetStore.equip(userId: number, id: string?): (boolean, string?)
	local row = ClosetStore.get(userId)
	if id == nil or id == "" then
		return false, "Unequip needs a slot."
	end
	local def = CosmeticCatalog.get(id)
	if not def then
		return false, "Unknown drip."
	end
	local owned = CosmeticCatalog.ownedSet(row.owned)
	if not owned[def.id] then
		return false, "Not in the closet."
	end
	if def.slot == "hat" then
		row.hat = if row.hat == def.id then nil else def.id
	else
		row.trail = if row.trail == def.id then nil else def.id
	end
	persist(userId, row)
	return true, nil
end

function ClosetStore.unequipSlot(userId: number, slot: CosmeticCatalog.Slot)
	local row = ClosetStore.get(userId)
	if slot == "hat" then
		row.hat = nil
	else
		row.trail = nil
	end
	persist(userId, row)
end

function ClosetStore.buy(userId: number, id: string): (boolean, string?)
	local def = CosmeticCatalog.get(id)
	if not def then
		return false, "Unknown drip."
	end
	local row = ClosetStore.get(userId)
	local owned = CosmeticCatalog.ownedSet(row.owned)
	if owned[def.id] then
		return false, "Already owned."
	end
	if not CosmeticCatalog.canBuy(def, row.yarn, false) then
		if CosmeticCatalog.yarnCost(def) <= 0 then
			return false, "Not for sale — unlock it in a stall."
		end
		return false, "Not enough closet yarn."
	end
	row.yarn = clampYarn(row.yarn - CosmeticCatalog.yarnCost(def))
	table.insert(row.owned, def.id)
	row.owned = CosmeticCatalog.ownedList(row.owned)
	if def.slot == "hat" then
		row.hat = def.id
	else
		row.trail = def.id
	end
	persist(userId, row)
	return true, nil
end

function ClosetStore.clear(userId: number)
	cache[userId] = nil
end

return ClosetStore
