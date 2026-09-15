--!strict

-- UTC daily Koi Pond board (best single catch). DataStore + Studio memory fallback.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local KoiCatalog = require(Shared:WaitForChild("KoiCatalog"))
local StallBoardLogic = require(Shared:WaitForChild("StallBoardLogic"))
local Types = require(Shared:WaitForChild("Types"))

local SettingsStore = require(script.Parent.Parent.Settings.SettingsStore)

local STORE_NAME = "MeoKoiDaily_v1"

local KoiBoardStore = {}

local persistMode: Types.PersistMode = "Memory"
local store: any = nil
local memory: { [string]: { StallBoardLogic.StoredEntry } } = {}
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

local function hiddenOf(userId: number, storedAnon: boolean?): boolean
	local prefs = SettingsStore.peek(userId)
	if prefs then
		return prefs.hideBoardName == true
	end
	return storedAnon == true
end

local function hydrate(value: any): { StallBoardLogic.StoredEntry }
	local bag: { StallBoardLogic.StoredEntry } = {}
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
				name = StallBoardLogic.clipName(if typeof(row.name) == "string" then row.name else "Cat"),
				score = math.max(0, math.floor(row.score)),
				detail = StallBoardLogic.clipDetail(if typeof(row.detail) == "string" then row.detail else "Catch"),
				at = if typeof(row.at) == "number" then row.at else 0,
				anon = row.anon == true,
			})
		end
	end
	return StallBoardLogic.sort(bag)
end

local function serialize(entries: { StallBoardLogic.StoredEntry }): any
	local rows = {}
	for _, row in entries do
		table.insert(rows, {
			userId = row.userId,
			name = row.name,
			score = row.score,
			detail = row.detail,
			at = row.at,
			anon = row.anon == true,
		})
	end
	return { entries = rows }
end

local function publicBoard(label: string, entries: { StallBoardLogic.StoredEntry }, selfUserId: number?): Types.StallBoard
	local list: { Types.StallBoardEntry } = {}
	for i, row in entries do
		table.insert(list, {
			rank = i,
			name = StallBoardLogic.visibleName(row.name, hiddenOf(row.userId, row.anon)),
			score = row.score,
			detail = row.detail,
			isSelf = selfUserId ~= nil and row.userId == selfUserId,
		})
	end
	return {
		dayKey = label,
		persistMode = persistMode,
		entries = list,
		selfRank = if selfUserId then StallBoardLogic.rankOf(entries, selfUserId) else nil,
	}
end

local function loadMemory(key: string): { StallBoardLogic.StoredEntry }
	local cached = memory[key]
	if cached then
		return cached
	end
	if store then
		local ok, value = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			local rows = hydrate(value)
			memory[key] = rows
			return rows
		end
		if RunService:IsStudio() then
			persistMode = "Memory"
		end
	end
	memory[key] = {}
	return memory[key]
end

local function writeBucket(
	key: string,
	incoming: StallBoardLogic.StoredEntry,
	throttled: boolean
): ({ StallBoardLogic.StoredEntry }, boolean)
	local result = StallBoardLogic.submit(loadMemory(key), incoming)
	memory[key] = result.entries
	if store and not throttled then
		local ok, saved = pcall(function()
			return store:UpdateAsync(key, function(old)
				local rows = hydrate(old)
				for _, row in memory[key] do
					rows = StallBoardLogic.submit(rows, row).entries
				end
				return serialize(rows)
			end)
		end)
		if ok then
			memory[key] = hydrate(saved)
		elseif RunService:IsStudio() then
			persistMode = "Memory"
		end
	end
	return memory[key], result.improved
end

function KoiBoardStore.persistMode(): Types.PersistMode
	return persistMode
end

function KoiBoardStore.get(unix: number, selfUserId: number?): Types.StallBoard
	local dayKey = KoiCatalog.dayKey(unix)
	return publicBoard(dayKey, loadMemory(`day:{dayKey}`), selfUserId)
end

function KoiBoardStore.rankOf(userId: number, unix: number): number?
	local dayKey = KoiCatalog.dayKey(unix)
	return StallBoardLogic.rankOf(loadMemory(`day:{dayKey}`), userId)
end

function KoiBoardStore.submit(player: Player, score: number, detail: string, unix: number): Types.StallBoardPost
	local prefs = SettingsStore.get(player.UserId)
	local incoming: StallBoardLogic.StoredEntry = {
		userId = player.UserId,
		name = StallBoardLogic.clipName(player.DisplayName),
		score = math.max(0, math.floor(score)),
		detail = StallBoardLogic.clipDetail(detail),
		at = unix,
		anon = prefs.hideBoardName == true,
	}
	local nowClock = os.clock()
	local last = lastSubmitAt[player.UserId] or 0
	local throttled = (nowClock - last) < StallBoardLogic.RateLimit
	if not throttled then
		lastSubmitAt[player.UserId] = nowClock
	end
	local dayKey = KoiCatalog.dayKey(unix)
	local rows, improved = writeBucket(`day:{dayKey}`, incoming, throttled)
	local board = publicBoard(dayKey, rows, player.UserId)
	return {
		ok = true,
		improved = improved,
		rank = StallBoardLogic.rankOf(rows, player.UserId),
		board = board,
	}
end

return KoiBoardStore
