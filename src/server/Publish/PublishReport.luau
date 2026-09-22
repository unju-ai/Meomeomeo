--!strict

-- Boot checklist for the hub Live panel. Reads Config flags and probes
-- VoiceChatService plus one DataStore GetAsync. Does not write Config,
-- does not print PlaceIds or product ids, and does not block Play.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Parent.Config)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local PublishChecklist = require(Shared:WaitForChild("PublishChecklist"))

local PublishReport = {}

local cached: PublishChecklist.Report? = nil

local function voiceServicePresent(): boolean
	local ok, service = pcall(function()
		return game:GetService("VoiceChatService")
	end)
	return ok and service ~= nil
end

local function dataStoreReachable(): boolean
	local ok = pcall(function()
		local store = DataStoreService:GetDataStore("MeoPublishProbe_v1")
		-- Read only. A miss returns nil when the API is on; Studio without
		-- API Services throws, which this pcall treats as not reachable.
		store:GetAsync("__ready")
	end)
	return ok == true
end

local function facts(): PublishChecklist.Facts
	return {
		matchPlaceSet = Config.Match.MatchPlaceId > 0,
		lobbyPlaceSet = Config.Match.LobbyPlaceId > 0,
		developerProductSet = Config.Nft404.DeveloperProductId > 0,
		voiceServicePresent = voiceServicePresent(),
		dataStoreReachable = dataStoreReachable(),
		economyEnabled = Config.Economy.Enabled == true,
	}
end

local function publishAttribute(summary: string)
	ReplicatedStorage:SetAttribute(Constants.Attributes.PublishSummary, summary)
end

function PublishReport.refresh(): PublishChecklist.Report
	local report = PublishChecklist.report(facts())
	cached = report
	publishAttribute(report.summary)
	return report
end

function PublishReport.get(): PublishChecklist.Report
	if cached then
		return cached
	end
	return PublishReport.refresh()
end

function PublishReport.init(): string
	local report = PublishReport.refresh()
	return report.summary
end

return PublishReport
