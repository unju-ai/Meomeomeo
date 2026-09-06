--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(script.Parent.Parent.Config)
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local VoiceService = {}

local voiceChatService: any = nil
local availability: Types.VoiceAvailability = "Unavailable"
local detail = "VoiceChatService not initialized yet."
local playerEnabled: { [number]: boolean } = {}

local function engineService(): any?
	if voiceChatService then
		return voiceChatService
	end
	local ok, service = pcall(function()
		return game:GetService("VoiceChatService")
	end)
	if ok then
		voiceChatService = service
		return service
	end
	return nil
end

local function findAudioInput(player: Player): AudioDeviceInput?
	local child = player:FindFirstChildWhichIsA("AudioDeviceInput")
	if child and child:IsA("AudioDeviceInput") then
		return child
	end
	return nil
end

local function teammateUserIds(player: Player): { number }
	local ids = {}
	local team = player.Team
	if not team then
		return ids
	end
	for _, mate in team:GetPlayers() do
		table.insert(ids, mate.UserId)
	end
	return ids
end

local function applyTeamAccess(player: Player)
	if Config.Voice.Mode ~= "Team" then
		return
	end

	local device = findAudioInput(player)
	if not device then
		return
	end

	local ok, err = pcall(function()
		device.AccessType = Enum.AccessModifierType.Allow
		device:SetUserIdAccessList(teammateUserIds(player))
	end)
	if not ok then
		detail = `Team voice stubbed: {err}`
		if Config.Voice.FallbackToProximity then
			availability = "Ready"
			detail = "Team access lists unavailable; falling back to proximity voice."
		else
			availability = "Unavailable"
		end
	end
end

local function refreshAllTeamAccess()
	for _, player in Players:GetPlayers() do
		applyTeamAccess(player)
	end
end

local function broadcast()
	local payload: Types.VoiceStatus = VoiceService.getStatus()
	Remotes.event("VoiceStatusChanged"):FireAllClients(payload)
end

function VoiceService.getStatus(forPlayer: Player?): Types.VoiceStatus
	local localEnabled = nil
	if forPlayer then
		localEnabled = playerEnabled[forPlayer.UserId]
	end
	return {
		mode = Config.Voice.Mode,
		availability = availability,
		detail = detail,
		localEnabled = localEnabled,
	}
end

function VoiceService.init()
	local service = engineService()
	if not service then
		availability = "StudioBlocked"
		detail =
			"VoiceChatService is missing. In Studio: Explorer → Show Services → insert VoiceChatService, then enable Voice Chat under File → Experience Settings → Communication."
		broadcast()
		return
	end

	-- UseAudioApi + EnableDefaultVoice are set in default.project.json.
	-- Experience-level "Enable Voice Chat" cannot be flipped from scripts.
	availability = "Ready"
	detail = if Config.Voice.Mode == "Team"
		then "Team voice: teammates only (Audio API access lists). Requires published experience + eligible 13+ accounts."
		else "Proximity voice: default spatial chat. Requires published experience + eligible 13+ accounts."

	local function onPlayer(player: Player)
		task.spawn(function()
			local ok, enabled = pcall(function()
				return service:IsVoiceEnabledForUserIdAsync(player.UserId)
			end)
			if ok then
				playerEnabled[player.UserId] = enabled == true
				if enabled ~= true then
					-- Player-level ineligibility does not disable the module for everyone.
					detail =
						"Some players are not voice-eligible (age / settings / Studio playtest). Team routing still applies for eligible users."
				end
			else
				playerEnabled[player.UserId] = false
				availability = "StudioBlocked"
				detail =
					"IsVoiceEnabledForUserIdAsync failed (common in Solo Play). Use Team Test or a published place. Voice module is stubbed safely."
			end

			player.CharacterAdded:Connect(function()
				task.defer(function()
					applyTeamAccess(player)
				end)
			end)
			player:GetPropertyChangedSignal("Team"):Connect(function()
				refreshAllTeamAccess()
			end)
			applyTeamAccess(player)
			Remotes.event("VoiceStatusChanged"):FireClient(player, VoiceService.getStatus(player))
		end)
	end

	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		playerEnabled[player.UserId] = nil
	end)

	for _, team in Teams:GetTeams() do
		team.PlayerAdded:Connect(function()
			refreshAllTeamAccess()
		end)
		team.PlayerRemoved:Connect(function()
			refreshAllTeamAccess()
		end)
	end

	-- Default voice may parent AudioDeviceInput a moment after join.
	Players.PlayerAdded:Connect(function(player)
		player.ChildAdded:Connect(function(child)
			if child:IsA("AudioDeviceInput") then
				applyTeamAccess(player)
			end
		end)
	end)

	broadcast()
end

function VoiceService.onTeamsChanged()
	refreshAllTeamAccess()
	broadcast()
end

return VoiceService
