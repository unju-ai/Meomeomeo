--!strict

-- Phase music beds. Separate SoundGroup from SFX so volumes stay independent.
-- Crossfades ~1s on phase change. Default master is quieter than SFX.

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local MusicIds = require(script.Parent.MusicIds)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Music = {}

local CROSSFADE = 1
local DEFAULT_MASTER = 0.35
local DUCK_MUL = 0.22

local group: SoundGroup
local folder: Folder
local master = DEFAULT_MASTER
local muted = false
local duckMul = 1
local duckGen = 0
local currentPhase: Types.MatchPhase? = nil
local current: Sound? = nil
local outgoing: Sound? = nil
local fadeConn: RBXScriptConnection? = nil

local function ensure()
	if group and folder then
		return
	end
	local existing = SoundService:FindFirstChild("MeoMusic")
	if existing and existing:IsA("SoundGroup") then
		group = existing
	else
		group = Instance.new("SoundGroup")
		group.Name = "MeoMusic"
		group.Parent = SoundService
	end
	local existingFolder = SoundService:FindFirstChild("MeoMusicPool")
	if existingFolder and existingFolder:IsA("Folder") then
		folder = existingFolder
	else
		folder = Instance.new("Folder")
		folder.Name = "MeoMusicPool"
		folder.Parent = SoundService
	end
	group.Volume = if muted then 0 else master * duckMul
end

local function applyMaster()
	ensure()
	group.Volume = if muted then 0 else master * duckMul
end

local function stopFade()
	if fadeConn then
		fadeConn:Disconnect()
		fadeConn = nil
	end
end

local function destroySound(sound: Sound?)
	if sound and sound.Parent then
		sound:Stop()
		sound:Destroy()
	end
end

local function bedDef(phase: Types.MatchPhase): MusicIds.BedDef?
	if phase == "Lobby" or phase == "ChampionSelect" or phase == "InProgress" or phase == "Ended" then
		return MusicIds[phase]
	end
	return nil
end

local function makeBed(phase: Types.MatchPhase): Sound?
	local def = bedDef(phase)
	if not def then
		return nil
	end
	ensure()
	local sound = Instance.new("Sound")
	sound.Name = `Bed_{phase}`
	sound.SoundId = def.id
	sound.Volume = 0
	sound.PlaybackSpeed = def.playbackSpeed
	sound.Looped = true
	sound.SoundGroup = group
	sound.Parent = folder
	return sound
end

local function crossfade(nextPhase: Types.MatchPhase)
	stopFade()
	local def = bedDef(nextPhase)
	local incoming = makeBed(nextPhase)
	if not def or not incoming then
		destroySound(current)
		current = nil
		return
	end
	local from = current
	outgoing = from
	current = incoming
	incoming:Play()

	local startVol = if from then from.Volume else 0
	local target = def.volume
	local started = os.clock()
	fadeConn = RunService.Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - started) / CROSSFADE, 0, 1)
		local s = t * t * (3 - 2 * t)
		incoming.Volume = target * s
		if from and from.Parent then
			from.Volume = startVol * (1 - s)
		end
		if t >= 1 then
			stopFade()
			if from == outgoing then
				destroySound(from)
				outgoing = nil
			end
		end
	end)
end

function Music.getVolume(): number
	return master
end

function Music.isMuted(): boolean
	return muted
end

function Music.setVolume(value: number)
	master = math.clamp(value, 0, 1)
	applyMaster()
end

function Music.setMuted(on: boolean)
	muted = on
	applyMaster()
end

function Music.setPhase(phase: Types.MatchPhase)
	if currentPhase == phase and current and current.Parent then
		return
	end
	currentPhase = phase
	crossfade(phase)
end

function Music.duck(seconds: number?)
	ensure()
	duckGen += 1
	local gen = duckGen
	duckMul = DUCK_MUL
	applyMaster()
	local waitFor = if typeof(seconds) == "number" and seconds > 0 then seconds else 1.6
	task.delay(waitFor, function()
		if duckGen == gen then
			duckMul = 1
			applyMaster()
		end
	end)
end

return Music
