--!strict

-- Daily + weekly Yarn Run boards. DataStore keyed by UTC day / Monday week; memory fallback in Studio.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local YarnBoardLogic = require(Shared:WaitForChild("YarnBoardLogic"))
local YarnRunCatalog = require(Shared:WaitForChild("YarnRunCatalog"))

local DAILY_STORE = "MeoYarnDaily_v1"
local WEEKLY_STORE = "MeoYarnWeekly_v1"

local YarnBoardStore = {}

local persistMode: Types.PersistMode = "Memory"
local dailyStore: any = nil
local weeklyStore: any = nil
local dailyMem: { [string]: { YarnBoardLogic.StoredEntry } } = {}
local weeklyMem: { [string]: { YarnBoardLogic.StoredEntry } } = {}
local lastSubmitAt: { [number]: number } = {}

local function connect(name: string): any
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if ok and result then
		persistMode = "DataStore"
		return result
	end
	return nil
end

dailyStore = connect(DAILY_STORE)
weeklyStore = connect(WEEKLY_STORE)

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

local function publicBoard(
	period: Types.YarnBoardPeriod,
	label: string,
	entries: { YarnBoardLogic.StoredEntry },
	selfUserId: number?
): Types.YarnBoard
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
		period = period,
		dayKey = label,
		persistMode = persistMode,
		entries = list,
		selfRank = if selfUserId then YarnBoardLogic.rankOf(entries, selfUserId) else nil,
	}
end

local function loadMemory(
	bucket: { [string]: { YarnBoardLogic.StoredEntry } },
	store: any,
	key: string
): { YarnBoardLogic.StoredEntry }
	local cached = bucket[key]
	if cached then
		return cached
	end
	if store then
		local ok, value = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			local rows = hydrate(value)
			bucket[key] = rows
			return rows
		end
		if RunService:IsStudio() then
			persistMode = "Memory"
		end
	end
	bucket[key] = {}
	return bucket[key]
end

local function writeBucket(
	bucket: { [string]: { YarnBoardLogic.StoredEntry } },
	store: any,
	key: string,
	incoming: YarnBoardLogic.StoredEntry,
	throttled: boolean
): ({ YarnBoardLogic.StoredEntry }, boolean)
	local result = YarnBoardLogic.submit(loadMemory(bucket, store, key), incoming)
	bucket[key] = result.entries
	if store and not throttled then
		local ok, saved = pcall(function()
			return store:UpdateAsync(key, function(old)
				local rows = hydrate(old)
				for _, row in bucket[key] do
					rows = YarnBoardLogic.submit(rows, row).entries
				end
				return serialize(rows)
			end)
		end)
		if ok then
			bucket[key] = hydrate(saved)
		elseif RunService:IsStudio() then
			persistMode = "Memory"
		end
	end
	return bucket[key], result.improved
end

function YarnBoardStore.persistMode(): Types.PersistMode
	return persistMode
end

function YarnBoardStore.get(unix: number, selfUserId: number?): Types.YarnBoard
	local dayKey = YarnRunCatalog.dayKey(unix)
	return publicBoard("daily", dayKey, loadMemory(dailyMem, dailyStore, `day:{dayKey}`), selfUserId)
end

function YarnBoardStore.getWeekly(unix: number, selfUserId: number?): Types.YarnBoard
	local weekKey = YarnRunCatalog.weekKey(unix)
	return publicBoard("weekly", YarnRunCatalog.weekLabel(unix), loadMemory(weeklyMem, weeklyStore, `week:{weekKey}`), selfUserId)
end

function YarnBoardStore.getBoards(unix: number, selfUserId: number?): Types.YarnBoards
	return {
		daily = YarnBoardStore.get(unix, selfUserId),
		weekly = YarnBoardStore.getWeekly(unix, selfUserId),
	}
end

function YarnBoardStore.rankOf(userId: number, unix: number): number?
	local dayKey = YarnRunCatalog.dayKey(unix)
	return YarnBoardLogic.rankOf(loadMemory(dailyMem, dailyStore, `day:{dayKey}`), userId)
end

function YarnBoardStore.weeklyRankOf(userId: number, unix: number): number?
	local weekKey = YarnRunCatalog.weekKey(unix)
	return YarnBoardLogic.rankOf(loadMemory(weeklyMem, weeklyStore, `week:{weekKey}`), userId)
end

function YarnBoardStore.submit(
	player: Player,
	score: number,
	meters: number,
	championId: string,
	unix: number
): Types.YarnBoardPost
	local incoming: YarnBoardLogic.StoredEntry = {
		userId = player.UserId,
		name = YarnBoardLogic.clipName(player.DisplayName),
		score = math.max(0, math.floor(score)),
		meters = math.max(0, math.floor(meters)),
		championId = YarnRunCatalog.parseRunner(championId),
		at = unix,
	}
	local nowClock = os.clock()
	local last = lastSubmitAt[player.UserId] or 0
	local throttled = (nowClock - last) < YarnBoardLogic.RateLimit
	if not throttled then
		lastSubmitAt[player.UserId] = nowClock
	end

	local dayKey = YarnRunCatalog.dayKey(unix)
	local weekKey = YarnRunCatalog.weekKey(unix)
	local dailyRows, dailyImproved = writeBucket(dailyMem, dailyStore, `day:{dayKey}`, incoming, throttled)
	local weeklyRows, weeklyImproved = writeBucket(weeklyMem, weeklyStore, `week:{weekKey}`, incoming, throttled)
	local dailyBoard = publicBoard("daily", dayKey, dailyRows, player.UserId)
	local weeklyBoard = publicBoard("weekly", YarnRunCatalog.weekLabel(unix), weeklyRows, player.UserId)
	local dailyRank = YarnBoardLogic.rankOf(dailyRows, player.UserId)
	local weeklyRank = YarnBoardLogic.rankOf(weeklyRows, player.UserId)
	return {
		daily = {
			ok = true,
			improved = dailyImproved,
			rank = dailyRank,
			board = dailyBoard,
		},
		weekly = {
			ok = true,
			improved = weeklyImproved,
			rank = weeklyRank,
			board = weeklyBoard,
		},
		boards = {
			daily = dailyBoard,
			weekly = weeklyBoard,
		},
	}
end

return YarnBoardStore
