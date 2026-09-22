--!strict

-- Team voice over VoiceChatService + AudioDeviceInput allow-lists.
-- Lists are rewritten whenever a side changes and again for a few seconds
-- after death or respawn, because the engine can parent a fresh device
-- after the first apply (that new device would otherwise be heard by everyone).
-- Bots are not players and never enter a list. Hub / stalls follow
-- Config.Voice.OutsideMatch (Off = nobody hears you, Proximity = spatial).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(script.Parent.Parent.Config)
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local VoiceLogic = require(Shared:WaitForChild("VoiceLogic"))

local VoiceService = {}

local voiceChatService: any = nil
local availability: Types.VoiceAvailability = "Unavailable"
local detail = "VoiceChatService not initialized yet."
local playerEnabled: { [number]: boolean } = {}
local retryToken: { [number]: number } = {}
local hookedTeams: { [Team]: boolean } = {}
local boundPlayers: { [Player]: boolean } = {}

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
	local character = player.Character
	if character then
		local nested = character:FindFirstChildWhichIsA("AudioDeviceInput", true)
		if nested and nested:IsA("AudioDeviceInput") then
			return nested
		end
	end
	return nil
end

local function teamIdOf(player: Player): string?
	local team = player.Team
	if not team then
		return nil
	end
	if team.Name == Constants.Teams.BlueInstance then
		return Constants.Teams.Blue
	end
	if team.Name == Constants.Teams.RedInstance then
		return Constants.Teams.Red
	end
	return nil
end

local function seatsFor(player: Player): { VoiceLogic.Seat }
	local seats: { VoiceLogic.Seat } = {}
	local team = player.Team
	if not team then
		return seats
	end
	local teamId = teamIdOf(player)
	if teamId == nil then
		return seats
	end
	for _, mate in team:GetPlayers() do
		table.insert(seats, {
			userId = mate.UserId,
			team = teamId,
			isBot = false,
		})
	end
	return seats
end

local function planFor(player: Player): VoiceLogic.AccessPlan
	return VoiceLogic.accessPlan({
		mode = Config.Voice.Mode,
		outsideMatch = Config.Voice.OutsideMatch,
		selfUserId = player.UserId,
		selfTeam = teamIdOf(player),
		seats = seatsFor(player),
	})
end

local function writePlan(device: AudioDeviceInput, plan: VoiceLogic.AccessPlan)
	if plan.kind == "Proximity" then
		-- Empty deny list: nobody is blocked, so spatial voice stays open.
		device.AccessType = Enum.AccessModifierType.Deny
		device:SetUserIdAccessList({})
	else
		-- Allow + teammates, or Allow + empty (silent) when there is no side.
		device.AccessType = Enum.AccessModifierType.Allow
		device:SetUserIdAccessList(plan.userIds)
	end
end

local function broadcast()
	local event = Remotes.event("VoiceStatusChanged")
	for _, player in Players:GetPlayers() do
		event:FireClient(player, VoiceService.getStatus(player))
	end
end

local function applyTeamAccess(player: Player)
	local device = findAudioInput(player)
	if not device then
		return
	end

	local plan = planFor(player)
	local ok, err = pcall(function()
		writePlan(device, plan)
	end)
	if ok then
		return
	end

	detail = `Team voice stubbed: {err}`
	if Config.Voice.FallbackToProximity then
		local fallbackOk = pcall(function()
			device.AccessType = Enum.AccessModifierType.Deny
			device:SetUserIdAccessList({})
		end)
		if fallbackOk then
			if availability ~= "StudioBlocked" then
				availability = "Ready"
			end
			detail = "Team access lists unavailable; falling back to proximity voice."
		else
			availability = "Unavailable"
			detail = "Voice routing failed and proximity fallback failed. The match still runs."
		end
	else
		availability = "Unavailable"
	end
	broadcast()
end

local function reapplySoon(player: Player)
	local token = (retryToken[player.UserId] or 0) + 1
	retryToken[player.UserId] = token
	for _, delay in VoiceLogic.ReapplyDelays do
		task.delay(delay, function()
			if retryToken[player.UserId] ~= token or player.Parent == nil then
				return
			end
			applyTeamAccess(player)
		end)
	end
end

local function refreshAllTeamAccess()
	for _, player in Players:GetPlayers() do
		reapplySoon(player)
	end
end

local function bindCharacter(player: Player, character: Model)
	local function hookHumanoid(humanoid: Humanoid)
		humanoid.Died:Connect(function()
			-- Death can drop the mic device before the respawn character exists.
			reapplySoon(player)
		end)
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid:IsA("Humanoid") then
		hookHumanoid(humanoid)
	end
	character.ChildAdded:Connect(function(child)
		if child:IsA("Humanoid") then
			hookHumanoid(child)
		elseif child:IsA("AudioDeviceInput") then
			reapplySoon(player)
		end
	end)
	character.DescendantAdded:Connect(function(child)
		if child:IsA("AudioDeviceInput") then
			reapplySoon(player)
		end
	end)
end

local function bindPlayer(player: Player)
	if boundPlayers[player] then
		return
	end
	boundPlayers[player] = true
	-- Connect before any yield. Draft assigns Team while IsVoiceEnabled is still in flight.
	player:GetPropertyChangedSignal("Team"):Connect(function()
		refreshAllTeamAccess()
		broadcast()
	end)
	player.ChildAdded:Connect(function(child)
		if child:IsA("AudioDeviceInput") then
			reapplySoon(player)
		end
	end)
	player.DescendantAdded:Connect(function(child)
		if child:IsA("AudioDeviceInput") then
			reapplySoon(player)
		end
	end)
	player.CharacterAdded:Connect(function(character)
		bindCharacter(player, character)
		reapplySoon(player)
	end)
	if player.Character then
		bindCharacter(player, player.Character)
	end
	reapplySoon(player)
end

local function hookTeam(team: Team)
	if hookedTeams[team] then
		return
	end
	hookedTeams[team] = true
	team.PlayerAdded:Connect(function()
		refreshAllTeamAccess()
		broadcast()
	end)
	team.PlayerRemoved:Connect(function()
		refreshAllTeamAccess()
		broadcast()
	end)
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
		outsideMatch = Config.Voice.OutsideMatch,
	}
end

function VoiceService.init()
	local service = engineService()
	if not service then
		availability = "StudioBlocked"
		detail =
			"VoiceChatService is missing. Show Services, insert VoiceChatService, then enable Voice Chat under Experience Settings → Communication. Publish before expecting a live mic."
		broadcast()
		return
	end

	availability = "Ready"
	detail = if Config.Voice.Mode == "Team"
		then "Team voice: teammates only. Requires a published experience and eligible 13+ accounts."
		else "Proximity voice: nearby cats. Requires a published experience and eligible 13+ accounts."

	local function onPlayer(player: Player)
		bindPlayer(player)
		task.spawn(function()
			local ok, enabled = pcall(function()
				return service:IsVoiceEnabledForUserIdAsync(player.UserId)
			end)
			if player.Parent == nil then
				return
			end
			if ok then
				playerEnabled[player.UserId] = enabled == true
			else
				playerEnabled[player.UserId] = false
				availability = "StudioBlocked"
				detail =
					"IsVoiceEnabledForUserIdAsync failed. Solo Play cannot enable experience voice. Publish the place and use two eligible clients."
			end
			reapplySoon(player)
			Remotes.event("VoiceStatusChanged"):FireClient(player, VoiceService.getStatus(player))
		end)
	end

	for _, team in Teams:GetTeams() do
		if team:IsA("Team") then
			hookTeam(team)
		end
	end
	Teams.ChildAdded:Connect(function(child)
		if child:IsA("Team") then
			hookTeam(child)
			refreshAllTeamAccess()
			broadcast()
		end
	end)

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		boundPlayers[player] = nil
		playerEnabled[player.UserId] = nil
		retryToken[player.UserId] = (retryToken[player.UserId] or 0) + 1
		task.defer(function()
			refreshAllTeamAccess()
			broadcast()
		end)
	end)

	broadcast()
end

function VoiceService.onTeamsChanged()
	refreshAllTeamAccess()
	broadcast()
end

return VoiceService
