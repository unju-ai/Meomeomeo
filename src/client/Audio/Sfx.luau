--!strict

-- Lightweight SFX player. Parent sounds under SoundService (not 3D).
-- Master volume + mute live on a SoundGroup. AA hits are debounced.

local SoundService = game:GetService("SoundService")

local SoundIds = require(script.Parent.SoundIds)

local Sfx = {}

local DEBOUNCE: { [string]: number } = {
	AutoHit = 0.14,
	AbilityCast = 0.08,
	Announcer = 0.35,
	Heal = 0.7,
	LevelUp = 0.8,
	Kill = 0.12,
	EmoteMeow = 0.2,
	EmoteHiss = 0.2,
	EmotePurr = 0.2,
	EmoteFlex = 0.2,
	EmoteDance = 0.2,
	EmoteLaugh = 0.2,
	EmoteCry = 0.2,
	EmoteGG = 0.2,
	PingSoft = 0.18,
	PingWarn = 0.18,
}

local group: SoundGroup
local folder: Folder
local master = 0.8
local muted = false
local lastPlayed: { [string]: number } = {}
local loops: { [string]: Sound } = {}

local function ensure()
	if group and folder then
		return
	end
	local existing = SoundService:FindFirstChild("MeoSfx")
	if existing and existing:IsA("SoundGroup") then
		group = existing
	else
		group = Instance.new("SoundGroup")
		group.Name = "MeoSfx"
		group.Parent = SoundService
	end
	local existingFolder = SoundService:FindFirstChild("MeoSfxPool")
	if existingFolder and existingFolder:IsA("Folder") then
		folder = existingFolder
	else
		folder = Instance.new("Folder")
		folder.Name = "MeoSfxPool"
		folder.Parent = SoundService
	end
	group.Volume = if muted then 0 else master
end

local function applyMaster()
	ensure()
	group.Volume = if muted then 0 else master
end

function Sfx.getVolume(): number
	return master
end

function Sfx.isMuted(): boolean
	return muted
end

function Sfx.setVolume(value: number)
	master = math.clamp(value, 0, 1)
	applyMaster()
end

function Sfx.setMuted(on: boolean)
	muted = on
	applyMaster()
end

function Sfx.play(cue: SoundIds.Cue)
	ensure()
	if muted or master <= 0.01 then
		return
	end
	local waitFor = DEBOUNCE[cue]
	local now = os.clock()
	if waitFor and lastPlayed[cue] and now - lastPlayed[cue] < waitFor then
		return
	end
	lastPlayed[cue] = now

	local def = SoundIds[cue]
	if not def then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = cue
	sound.SoundId = def.id
	sound.Volume = def.volume
	sound.PlaybackSpeed = def.playbackSpeed
	sound.RollOffMaxDistance = 80
	sound.SoundGroup = group
	sound.Parent = folder
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(5, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

function Sfx.startLoop(cue: SoundIds.Cue)
	ensure()
	if loops[cue] then
		return
	end
	local def = SoundIds[cue]
	if not def then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = cue .. "Loop"
	sound.SoundId = def.id
	sound.Volume = def.volume
	sound.PlaybackSpeed = def.playbackSpeed
	sound.Looped = true
	sound.SoundGroup = group
	sound.Parent = folder
	sound:Play()
	loops[cue] = sound
end

function Sfx.stopLoop(cue: SoundIds.Cue)
	local sound = loops[cue]
	if not sound then
		return
	end
	loops[cue] = nil
	sound:Stop()
	sound:Destroy()
end

function Sfx.cueForFeed(kind: string): SoundIds.Cue?
	if kind == "kill" then
		return "Kill"
	elseif kind == "tower" then
		return "TowerDown"
	elseif kind == "nexus" then
		return "NexusDown"
	elseif kind == "level" then
		return "LevelUp"
	elseif kind == "announce" then
		return "Announcer"
	end
	return nil
end

-- Skip stingers that already have a kill-feed cue so we do not double-play.
function Sfx.cueForAnnouncer(text: string): SoundIds.Cue?
	local lower = string.lower(text)
	if string.find(lower, "deleted", 1, true) or string.find(lower, "face-planted", 1, true) then
		return nil
	end
	if string.find(lower, "melted", 1, true) then
		return nil
	end
	if string.find(lower, "hit level", 1, true) then
		return nil
	end
	if string.find(lower, "victory", 1, true) then
		return "MatchFound"
	end
	if string.find(lower, "defeat", 1, true) then
		return "Announcer"
	end
	return "Announcer"
end

return Sfx
