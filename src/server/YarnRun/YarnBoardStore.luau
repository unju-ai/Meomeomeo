--!strict

-- Daily Yarn Run leaderboard. DataStore keyed by UTC day; memory fallback in Studio.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local YarnBoardLogic = require(Shared:WaitForChild("YarnBoardLogic"))
local YarnRunCatalog = require(Shared:WaitForChild("YarnRunCatalog"))

local STORE_NAME = "MeoYarnDaily_v1"

local YarnBoardStore = {}

local store: any = nil
local persistMode: Types.PersistMode = "Memory"
local memory: { [string]: { YarnBoardLogic.StoredEntry } } = {}
local lastSubmitAt: { [number]: number } = {}

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and result then
		store = result
		persistMode = "DataStore"
	end
end

local function keyOf(dayKey: string): string
	return `day:{dayKey}`
end

local function hydrate(value: any): { YarnBoardLogic.StoredEntry }
	local bag: { YarnBoardLogic.StoredEntry } = {}
	if typeof(value) ~= "table" then
		return bag
	end
	local rows = value
	if typeof(value.entries) == "table" then
		rows = value.entries
	end
	for _, row in rows do
		if typeof(row) == "table" and typeof(row.userId) == "number" and typeof(row.score) == "number" then
			table.insert(bag, {
				userId = row.userId,
				name = YarnBoardLogic.clipName(if typeof(row.name) == "string" then row.name else "Cat"),
				score = math.floor(row.score),
				meters = if typeof(row.meters) == "number" then math.floor(row.meters) else 0,
				championId = YarnRunCatalog.parseRunner(row.championId),
				at = if typeof(row.at) == "number" then row.at else 0,
			})
		end
	end
	return YarnBoardLogic.sort(bag)
end

local function serialize(entries: { YarnBoardLogic.StoredEntry }): any
	local rows = {}
	for _, row in entries do
		table.insert(rows, {
			userId = row.userId,
			name = row.name,
			score = row.score,
			meters = row.meters,
			championId = row.championId,
			at = row.at,
		})
	end
	return { entries = rows }
end

local function publicBoard(dayKey: string, entries: { YarnBoardLogic.StoredEntry }, selfUserId: number?): Types.YarnBoard
	local list: { Types.YarnBoardEntry } = {}
	for i, row in entries do
		table.insert(list, {
			rank = i,
			name = row.name,
			score = row.score,
			meters = row.meters,
			championId = row.championId,
			isSelf = selfUserId ~= nil and row.userId == selfUserId,
		})
	end
	return {
		dayKey = dayKey,
		persistMode = persistMode,
		entries = list,
		selfRank = if selfUserId then YarnBoardLogic.rankOf(entries, selfUserId) else nil,
	}
end

local function loadMemory(dayKey: string): { YarnBoardLogic.StoredEntry }
	local cached = memory[dayKey]
	if cached then
		return cached
	end
	if store then
		local ok, value = pcall(function()
			return store:GetAsync(keyOf(dayKey))
		end)
		if ok then
			local rows = hydrate(value)
			memory[dayKey] = rows
			return rows
		end
		if RunService:IsStudio() then
			persistMode = "Memory"
		end
	end
	memory[dayKey] = {}
	return memory[dayKey]
end

function YarnBoardStore.persistMode(): Types.PersistMode
	return persistMode
end

function YarnBoardStore.get(unix: number, selfUserId: number?): Types.YarnBoard
	local dayKey = YarnRunCatalog.dayKey(unix)
	return publicBoard(dayKey, loadMemory(dayKey), selfUserId)
end

function YarnBoardStore.rankOf(userId: number, unix: number): number?
	local dayKey = YarnRunCatalog.dayKey(unix)
	return YarnBoardLogic.rankOf(loadMemory(dayKey), userId)
end

function YarnBoardStore.submit(
	player: Player,
	score: number,
	meters: number,
	championId: string,
	unix: number
): Types.YarnBoardSubmit
	local dayKey = YarnRunCatalog.dayKey(unix)
	local incoming: YarnBoardLogic.StoredEntry = {
		userId = player.UserId,
		name = YarnBoardLogic.clipName(player.DisplayName),
		score = math.max(0, math.floor(score)),
		meters = math.max(0, math.floor(meters)),
		championId = YarnRunCatalog.parseRunner(championId),
		at = unix,
	}
	local now = os.clock()
	local last = lastSubmitAt[player.UserId] or 0
	local throttled = (now - last) < YarnBoardLogic.RateLimit

	local result = YarnBoardLogic.submit(loadMemory(dayKey), incoming)
	memory[dayKey] = result.entries

	if store and not throttled then
		lastSubmitAt[player.UserId] = now
		local ok, saved = pcall(function()
			return store:UpdateAsync(keyOf(dayKey), function(old)
				local rows = hydrate(old)
				for _, row in memory[dayKey] do
					rows = YarnBoardLogic.submit(rows, row).entries
				end
				return serialize(rows)
			end)
		end)
		if ok then
			memory[dayKey] = hydrate(saved)
		elseif RunService:IsStudio() then
			persistMode = "Memory"
		end
	end

	local entries = memory[dayKey]
	return {
		ok = true,
		improved = result.improved,
		rank = YarnBoardLogic.rankOf(entries, player.UserId),
		board = publicBoard(dayKey, entries, player.UserId),
	}
end

return YarnBoardStore
