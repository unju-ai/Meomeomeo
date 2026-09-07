--!strict

-- Per-player audio + lobby prefs.
-- DataStore when available; memory cache always. Studio without API Services stays in-memory.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Types = require(Shared:WaitForChild("Types"))

local STORE_NAME = "MeoSettings_v1"

local SettingsStore = {}

local store: any = nil
local persistMode: Types.PersistMode = "Memory"
local cache: { [number]: Types.PlayerPrefs } = {}

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
	return `user:{userId}:prefs`
end

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function parseDifficulty(value: any): Types.BotDifficulty
	if value == "Easy" or value == "Hard" then
		return value
	end
	return "Normal"
end

local function defaults(): Types.PlayerPrefs
	return {
		sfxVolume = 0.8,
		sfxMuted = false,
		musicVolume = 0.35,
		musicMuted = false,
		muteOthersEmotes = false,
		practiceDifficulty = "Normal",
		persistMode = persistMode,
	}
end

local function hydrate(value: any): Types.PlayerPrefs
	local row = defaults()
	if typeof(value) ~= "table" then
		return row
	end
	if typeof(value.sfxVolume) == "number" then
		row.sfxVolume = clamp01(value.sfxVolume)
	end
	if typeof(value.musicVolume) == "number" then
		row.musicVolume = clamp01(value.musicVolume)
	end
	row.sfxMuted = value.sfxMuted == true
	row.musicMuted = value.musicMuted == true
	row.muteOthersEmotes = value.muteOthersEmotes == true
	row.practiceDifficulty = parseDifficulty(value.practiceDifficulty)
	row.persistMode = persistMode
	return row
end

function SettingsStore.persistMode(): Types.PersistMode
	return persistMode
end

function SettingsStore.get(userId: number): Types.PlayerPrefs
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

function SettingsStore.set(userId: number, patch: any): Types.PlayerPrefs
	local current = SettingsStore.get(userId)
	if typeof(patch) ~= "table" then
		return current
	end
	-- Missing fields keep the current row so a difficulty-only save cannot unmute audio.
	local nextRow = hydrate({
		sfxVolume = if typeof(patch.sfxVolume) == "number" then patch.sfxVolume else current.sfxVolume,
		sfxMuted = if typeof(patch.sfxMuted) == "boolean" then patch.sfxMuted else current.sfxMuted,
		musicVolume = if typeof(patch.musicVolume) == "number" then patch.musicVolume else current.musicVolume,
		musicMuted = if typeof(patch.musicMuted) == "boolean" then patch.musicMuted else current.musicMuted,
		muteOthersEmotes = if typeof(patch.muteOthersEmotes) == "boolean"
			then patch.muteOthersEmotes
			else current.muteOthersEmotes,
		practiceDifficulty = if patch.practiceDifficulty ~= nil then patch.practiceDifficulty else current.practiceDifficulty,
	})
	cache[userId] = nextRow
	if store then
		local ok = pcall(function()
			store:SetAsync(keyOf(userId), {
				sfxVolume = nextRow.sfxVolume,
				sfxMuted = nextRow.sfxMuted,
				musicVolume = nextRow.musicVolume,
				musicMuted = nextRow.musicMuted,
				muteOthersEmotes = nextRow.muteOthersEmotes,
				practiceDifficulty = nextRow.practiceDifficulty,
			})
		end)
		if not ok and RunService:IsStudio() then
			persistMode = "Memory"
			nextRow.persistMode = persistMode
		end
	end
	return nextRow
end

function SettingsStore.applyAttributes(player: Player, prefs: Types.PlayerPrefs?)
	local row = prefs or SettingsStore.get(player.UserId)
	player:SetAttribute(Constants.Attributes.SfxVolume, row.sfxVolume)
	player:SetAttribute(Constants.Attributes.SfxMuted, row.sfxMuted)
	player:SetAttribute(Constants.Attributes.MusicVolume, row.musicVolume)
	player:SetAttribute(Constants.Attributes.MusicMuted, row.musicMuted)
	player:SetAttribute(Constants.Attributes.MuteOthersEmotes, row.muteOthersEmotes)
	player:SetAttribute(Constants.Attributes.PracticeDifficulty, row.practiceDifficulty)
end

function SettingsStore.clear(userId: number)
	cache[userId] = nil
end

return SettingsStore
