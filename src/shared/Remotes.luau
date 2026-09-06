--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Constants)

export type RemoteName =
	"QueueMatch"
	| "LeaveQueue"
	| "StartPractice"
	| "SelectChampion"
	| "GetMatchSnapshot"
	| "UseAbility"
	| "GetVoiceStatus"
	| "ChatWithNpc"
	| "GetNpcs"
	| "GetMemeMarket"
	| "CheerTicker"
	| "GetMintStatus"
	| "LinkWallet"
	| "SimulateStudioPurchase"
	| "GrantProduct"
	| "ReplayReceipt"
	| "ClaimMeo404"
	| "BuyItem"
	| "GetShopStatus"
	| "IssueAttack"
	| "AttackMove"
	| "MinimapPing"
	| "StartRecall"
	| "LeaveMatch"
	| "PlayAgain"
	| "PlaceWard"
	| "UseLens"
	| "InviteParty"
	| "GetQueueStatus"
	| "MatchStateChanged"
	| "QueueUpdated"
	| "CombatUpdated"
	| "AnnouncerMessage"
	| "VoiceStatusChanged"
	| "MarketUpdated"
	| "MintStatusChanged"
	| "ShopUpdated"
	| "VisionUpdated"
	| "PingReceived"
	| "KillFeed"

local FUNCTION_NAMES = {
	"QueueMatch",
	"LeaveQueue",
	"StartPractice",
	"SelectChampion",
	"GetMatchSnapshot",
	"UseAbility",
	"GetVoiceStatus",
	"ChatWithNpc",
	"GetNpcs",
	"GetMemeMarket",
	"CheerTicker",
	"GetMintStatus",
	"LinkWallet",
	"SimulateStudioPurchase",
	"GrantProduct",
	"ReplayReceipt",
	"ClaimMeo404",
	"BuyItem",
	"GetShopStatus",
	"IssueAttack",
	"AttackMove",
	"MinimapPing",
	"StartRecall",
	"LeaveMatch",
	"PlayAgain",
	"PlaceWard",
	"UseLens",
	"InviteParty",
	"GetQueueStatus",
}

local EVENT_NAMES = {
	"MatchStateChanged",
	"CombatUpdated",
	"AnnouncerMessage",
	"VoiceStatusChanged",
	"MarketUpdated",
	"MintStatusChanged",
	"ShopUpdated",
	"VisionUpdated",
	"PingReceived",
	"KillFeed",
	"QueueUpdated",
}

local function getFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(Constants.RemotesFolderName)
	if existing and existing:IsA("Folder") then
		return existing
	end

	if RunService:IsClient() then
		return ReplicatedStorage:WaitForChild(Constants.RemotesFolderName) :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = Constants.RemotesFolderName
	folder.Parent = ReplicatedStorage
	return folder
end

local function ensure(className: "RemoteEvent" | "RemoteFunction", name: string): Instance
	local folder = getFolder()
	local child = folder:FindFirstChild(name)
	if child then
		return child
	end

	if RunService:IsClient() then
		return folder:WaitForChild(name)
	end

	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	return remote
end

local Remotes = {}

function Remotes.function_(name: string): RemoteFunction
	return ensure("RemoteFunction", name) :: RemoteFunction
end

function Remotes.event(name: string): RemoteEvent
	return ensure("RemoteEvent", name) :: RemoteEvent
end

function Remotes.initServer()
	for _, name in FUNCTION_NAMES do
		ensure("RemoteFunction", name)
	end
	for _, name in EVENT_NAMES do
		ensure("RemoteEvent", name)
	end
end

return Remotes
