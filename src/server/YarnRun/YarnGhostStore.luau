--!strict

-- Personal-best Yarn Run path. DataStore when available; memory fallback in Studio.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local YarnRunCatalog = require(Shared:WaitForChild("YarnRunCatalog"))

local STORE_NAME = "MeoYarnGhost_v1"

local YarnGhostStore = {}

local store: any = nil
local persistMode: Types.PersistMode = "Memory"
local cache: { [number]: YarnRunCatalog.YarnBest } = {}

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
	return `user:{userId}:ghost`
end

local function hydrate(value: any): YarnRunCatalog.YarnBest?
	if typeof(value) ~= "table" then
		return nil
	end
	if typeof(value.score) ~= "number" or value.score <= 0 then
		return nil
	end
	local samples: { YarnRunCatalog.GhostSample } = {}
	if typeof(value.samples) == "table" then
		for _, row in value.samples do
			local sample = YarnRunCatalog.readSample(row)
			if sample then
				table.insert(samples, sample)
			end
		end
	end
	return {
		score = math.floor(value.score),
		meters = if typeof(value.meters) == "number" then math.max(0, math.floor(value.meters)) else 0,
		combo = if typeof(value.combo) == "number" then math.max(0, math.floor(value.combo)) else 0,
		samples = YarnRunCatalog.capSamples(samples),
	}
end

local function persist(userId: number, row: YarnRunCatalog.YarnBest)
	if not store then
		return
	end
	local ok = pcall(function()
		store:SetAsync(keyOf(userId), {
			score = row.score,
			meters = row.meters,
			combo = row.combo,
			samples = row.samples,
		})
	end)
	if not ok and RunService:IsStudio() then
		persistMode = "Memory"
	end
end

function YarnGhostStore.persistMode(): Types.PersistMode
	return persistMode
end

function YarnGhostStore.get(userId: number): YarnRunCatalog.YarnBest?
	local cached = cache[userId]
	if cached then
		return cached
	end
	if store then
		local ok, value = pcall(function()
			return store:GetAsync(keyOf(userId))
		end)
		if ok then
			local row = hydrate(value)
			if row then
				cache[userId] = row
				return row
			end
			return nil
		end
		if RunService:IsStudio() then
			persistMode = "Memory"
		end
	end
	return nil
end

function YarnGhostStore.save(userId: number, record: YarnRunCatalog.YarnBest): boolean
	if record.score <= 0 then
		return false
	end
	local nextRow: YarnRunCatalog.YarnBest = {
		score = math.floor(record.score),
		meters = math.max(0, math.floor(record.meters)),
		combo = math.max(0, math.floor(record.combo)),
		samples = YarnRunCatalog.capSamples(record.samples),
	}
	local prev = YarnGhostStore.get(userId)
	if prev and prev.score >= nextRow.score then
		return false
	end
	cache[userId] = nextRow
	persist(userId, nextRow)
	return true
end

function YarnGhostStore.clear(userId: number)
	cache[userId] = nil
end

return YarnGhostStore
