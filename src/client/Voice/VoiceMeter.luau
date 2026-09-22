--!strict

-- Local mic mute + best-effort speaking meter.
-- AudioAnalyzer.RmsLevel is client-only (the server property stays 0), so this
-- never replicates a speaking bit. Wires are created only for the local cat
-- and current teammates. Enemies and bots are not metered.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VoiceLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("VoiceLogic"))

local VoiceMeter = {}

export type Sample = {
	deviceReady: boolean,
	signalAvailable: boolean,
	speaking: boolean,
	muted: boolean,
}

local watched: { [number]: boolean } = {}
local analyzers: { [number]: Instance } = {}
local signalOk: { [number]: boolean } = {}
local sample: Sample = {
	deviceReady = false,
	signalAvailable = false,
	speaking = false,
	muted = false,
}
local wantMuted: boolean? = nil
local started = false
local localPlayer: Player? = nil
local bucketFolder: Folder? = nil
local listeners: { () -> () } = {}
local lastSignature = ""

local function emit()
	for _, listener in listeners do
		listener()
	end
end

local function bucket(): Instance?
	if bucketFolder and bucketFolder.Parent then
		return bucketFolder
	end
	local player = localPlayer
	if not player then
		return nil
	end
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "MeoVoiceMeters"
	folder.Parent = gui
	bucketFolder = folder
	return folder
end

local function findDevice(player: Player): AudioDeviceInput?
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

local function deviceReady(device: AudioDeviceInput): boolean
	local ok, ready = pcall(function()
		return device.IsReady
	end)
	if not ok then
		return true
	end
	return ready == true
end

local function destroyAnalyzer(userId: number)
	local analyzer = analyzers[userId]
	analyzers[userId] = nil
	signalOk[userId] = nil
	if analyzer then
		pcall(function()
			analyzer:Destroy()
		end)
	end
end

local function analyzerMatches(userId: number, device: AudioDeviceInput): boolean
	local analyzer = analyzers[userId]
	if analyzer == nil or analyzer.Parent == nil then
		return false
	end
	local wire = analyzer:FindFirstChild("MeoVoiceWire")
	if wire == nil or not wire:IsA("Wire") then
		return false
	end
	local ok, source = pcall(function()
		return (wire :: Wire).SourceInstance
	end)
	return ok and source == device
end

local function ensureAnalyzer(player: Player): boolean
	local device = findDevice(player)
	if not device then
		destroyAnalyzer(player.UserId)
		return false
	end
	if analyzerMatches(player.UserId, device) then
		return signalOk[player.UserId] == true
	end
	destroyAnalyzer(player.UserId)
	local parent = bucket()
	if not parent then
		return false
	end
	local created: Instance? = nil
	local ok = pcall(function()
		local analyzer = Instance.new("AudioAnalyzer")
		analyzer.Name = "MeoVoiceAnalyzer"
		analyzer.Parent = parent
		created = analyzer
		local wire = Instance.new("Wire")
		wire.Name = "MeoVoiceWire"
		wire.SourceInstance = device
		wire.TargetInstance = analyzer
		pcall(function()
			wire.SourceName = "Output"
			wire.TargetName = "Input"
		end)
		wire.Parent = analyzer
	end)
	if not ok or created == nil then
		if created then
			pcall(function()
				(created :: Instance):Destroy()
			end)
		end
		signalOk[player.UserId] = false
		return false
	end
	analyzers[player.UserId] = created
	signalOk[player.UserId] = true
	return true
end

local function readLevel(userId: number): (boolean, boolean)
	local analyzer = analyzers[userId]
	if analyzer == nil then
		return false, false
	end
	local ok, rms, peak = pcall(function()
		local meter = analyzer :: any
		return meter.RmsLevel, meter.PeakLevel
	end)
	if not ok or typeof(rms) ~= "number" or typeof(peak) ~= "number" then
		return false, false
	end
	return true, VoiceLogic.isSpeaking(rms, peak)
end

local function setPlate(player: Player, speaking: boolean)
	local character = player.Character
	if not character then
		return
	end
	local plate = character:FindFirstChild("MeoNameplate", true)
	if plate == nil or not plate:IsA("BillboardGui") then
		return
	end
	local dot = plate:FindFirstChild("VoicePulse")
	if not speaking then
		if dot then
			dot:Destroy()
		end
		return
	end
	local frame = if dot and dot:IsA("Frame") then dot else nil
	if frame == nil then
		local created = Instance.new("Frame")
		created.Name = "VoicePulse"
		created.AnchorPoint = Vector2.new(0.5, 1)
		created.Position = UDim2.new(0.5, 0, 0, -2)
		created.BackgroundColor3 = Color3.fromRGB(120, 196, 150)
		created.BorderSizePixel = 0
		created.ZIndex = 3
		created.Parent = plate
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = created
		frame = created
	end
	local wave = 0.55 + 0.45 * math.sin(os.clock() * 8)
	local size = 8 + math.floor(6 * wave)
	frame.Size = UDim2.fromOffset(size, size)
	frame.Visible = true
end

local function poll()
	local player = localPlayer
	if not player then
		return
	end
	local device = findDevice(player)
	local ready = device ~= nil and deviceReady(device :: AudioDeviceInput)
	sample.deviceReady = ready
	if device and wantMuted ~= nil then
		pcall(function()
			if device.Muted ~= wantMuted then
				device.Muted = wantMuted :: boolean
			end
		end)
	end
	local muted = false
	if device then
		local ok, value = pcall(function()
			return device.Muted
		end)
		muted = ok and value == true
	end
	sample.muted = muted

	local signal = false
	local speaking = false
	if ready and not muted and ensureAnalyzer(player) then
		local heard, loud = readLevel(player.UserId)
		signal = heard
		speaking = heard and loud
	end
	sample.signalAvailable = signal
	sample.speaking = speaking

	local heardIds = {}
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local watch = watched[other.UserId] == true
		if not watch then
			destroyAnalyzer(other.UserId)
			setPlate(other, false)
		else
			local otherSpeaking = false
			if ensureAnalyzer(other) then
				local heard, loud = readLevel(other.UserId)
				otherSpeaking = heard and loud
			end
			if otherSpeaking then
				table.insert(heardIds, other.UserId)
			end
			setPlate(other, otherSpeaking)
		end
	end
	table.sort(heardIds)

	local signature = `{ready}|{signal}|{speaking}|{muted}|{table.concat(heardIds, ",")}`
	local pulsing = speaking or #heardIds > 0
	if signature ~= lastSignature or pulsing then
		lastSignature = signature
		emit()
	end
end

function VoiceMeter.sample(): Sample
	return sample
end

function VoiceMeter.onChanged(listener: () -> ())
	table.insert(listeners, listener)
end

function VoiceMeter.setWatch(userIds: { number })
	watched = {}
	for _, userId in userIds do
		if userId > 0 then
			watched[userId] = true
		end
	end
end

function VoiceMeter.setMuted(muted: boolean): boolean
	local player = localPlayer
	local device = if player then findDevice(player) else nil
	if device == nil or not deviceReady(device) then
		return false
	end
	wantMuted = muted
	local ok = pcall(function()
		device.Muted = muted
	end)
	if not ok then
		return false
	end
	local readOk, value = pcall(function()
		return device.Muted
	end)
	sample.muted = readOk and value == true
	sample.deviceReady = true
	emit()
	return sample.muted == muted
end

local function watchDevice(player: Player)
	player.ChildAdded:Connect(function(child)
		if child:IsA("AudioDeviceInput") then
			destroyAnalyzer(player.UserId)
		end
	end)
end

function VoiceMeter.start(player: Player)
	if started then
		return
	end
	started = true
	localPlayer = player
	for _, other in Players:GetPlayers() do
		watchDevice(other)
	end
	Players.PlayerAdded:Connect(function(other)
		watchDevice(other)
	end)
	RunService.Heartbeat:Connect(function()
		poll()
	end)
end

return VoiceMeter
