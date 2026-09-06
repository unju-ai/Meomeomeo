--!strict

-- Per-player "first Practice tips dismissed" flag.
-- DataStore when available; memory cache always. Studio/API failure is fine.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local STORE_NAME = "MeoTutorial_v1"

local TutorialStore = {}

local store: any = nil
local persistMode: Types.PersistMode = "Memory"
local cache: { [number]: boolean } = {}

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
	return `user:{userId}:done`
end

function TutorialStore.persistMode(): Types.PersistMode
	return persistMode
end

function TutorialStore.isDone(userId: number): boolean
	if cache[userId] ~= nil then
		return cache[userId] == true
	end
	if store then
		local ok, value = pcall(function()
			return store:GetAsync(keyOf(userId))
		end)
		if ok then
			cache[userId] = value == true
			return cache[userId] == true
		end
		if RunService:IsStudio() then
			persistMode = "Memory"
		end
	end
	cache[userId] = false
	return false
end

function TutorialStore.markDone(userId: number)
	cache[userId] = true
	if not store then
		return
	end
	local ok = pcall(function()
		store:SetAsync(keyOf(userId), true)
	end)
	if not ok and RunService:IsStudio() then
		persistMode = "Memory"
	end
end

return TutorialStore
