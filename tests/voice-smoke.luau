-- Team voice routing and HUD copy. No VoiceChatService, no Studio mic.
-- Run through tools/test-voice.py.

local function sameIds(a: { number }, b: { number }): boolean
	if #a ~= #b then
		return false
	end
	for index, value in a do
		if b[index] ~= value then
			return false
		end
	end
	return true
end

local practice = {
	{ userId = 10, team = "Blue", isBot = false },
	{ userId = -1, team = "Red", isBot = true },
	{ userId = -2, team = "Red", isBot = true },
	{ userId = -3, team = "Red", isBot = true },
}

local rivals = {
	{ userId = 10, team = "Blue", isBot = false },
	{ userId = 12, team = "Blue", isBot = false },
	{ userId = 12, team = "Blue", isBot = false },
	{ userId = 11, team = "Red", isBot = false },
	{ userId = 0, team = "Blue", isBot = false },
	{ userId = -8, team = "Blue", isBot = true },
	{ userId = 13, team = "Red", isBot = false },
}

assert(sameIds(VoiceLogic.peerUserIds(10, "Blue", practice), {}), "bots are not voice peers")
assert(sameIds(VoiceLogic.peerUserIds(10, "Blue", rivals), { 12 }), "only the other blue human")
assert(sameIds(VoiceLogic.peerUserIds(12, "Blue", rivals), { 10 }), "the list is symmetric")
assert(sameIds(VoiceLogic.peerUserIds(11, "Red", rivals), { 13 }), "red does not include blue")
assert(sameIds(VoiceLogic.peerUserIds(10, nil, rivals), {}), "no side means no peers")
assert(#VoiceLogic.peerUserIds(10, "Blue", rivals) == 1, "duplicate seats collapse")

local function plan(selfUserId: number, selfTeam: string?, seats, mode: string, outside: string)
	return VoiceLogic.accessPlan({
		mode = mode,
		outsideMatch = outside,
		selfUserId = selfUserId,
		selfTeam = selfTeam,
		seats = seats,
	})
end

local solo = plan(10, "Blue", practice, "Team", "Off")
assert(solo.kind == "TeamAllow" and #solo.userIds == 0, "practice is teammates-only with an empty list")

local blue = plan(10, "Blue", rivals, "Team", "Off")
local red = plan(11, "Red", rivals, "Team", "Off")
assert(sameIds(blue.userIds, { 12 }) and sameIds(red.userIds, { 13 }))
assert(blue.userIds[1] ~= 11 and red.userIds[1] ~= 10, "enemies stay off the allow list")

-- Champion select, the live match, and the end screen share one roster plan.
for _, _phase in { "ChampionSelect", "InProgress", "Ended" } do
	local again = plan(10, "Blue", rivals, "Team", "Off")
	assert(sameIds(again.userIds, blue.userIds), "phase does not stale the roster")
end

local quiet = plan(10, nil, rivals, "Team", "Off")
assert(quiet.kind == "Silent" and #quiet.userIds == 0, "hub Off is an empty allow list")
local hubNear = plan(10, nil, rivals, "Team", "Proximity")
assert(hubNear.kind == "Proximity" and #hubNear.userIds == 0, "hub Proximity does not keep a team list")
local stillTeam = plan(10, "Blue", rivals, "Team", "Proximity")
assert(stillTeam.kind == "TeamAllow" and sameIds(stillTeam.userIds, { 12 }), "a side beats OutsideMatch")
local spatial = plan(10, "Blue", rivals, "Proximity", "Off")
assert(spatial.kind == "Proximity" and #spatial.userIds == 0, "Proximity mode never writes a team list")

assert(VoiceLogic.shouldWatchUser(10, "Blue", 12, "Blue", false) == true)
assert(VoiceLogic.shouldWatchUser(10, "Blue", 11, "Red", false) == false, "no enemy meter")
assert(VoiceLogic.shouldWatchUser(10, "Blue", -2, "Red", true) == false, "no bot meter")
assert(VoiceLogic.shouldWatchUser(10, "Blue", 10, "Blue", false) == false, "local pill covers self")
assert(VoiceLogic.shouldWatchUser(10, nil, 12, "Blue", false) == false)

assert(VoiceLogic.isSpeaking(0.049, 0) == false)
assert(VoiceLogic.isSpeaking(VoiceLogic.SpeakingRms, 0) == true)
assert(VoiceLogic.isSpeaking(0, VoiceLogic.SpeakingRms) == true)
assert(VoiceLogic.isSpeaking(0 / 0, 1) == false, "a bad meter is silence")

local maxDelay = 0
local sawZero = false
for _, delay in VoiceLogic.ReapplyDelays do
	assert(delay >= 0)
	if delay == 0 then
		sawZero = true
	end
	if delay > maxDelay then
		maxDelay = delay
	end
end
assert(sawZero and maxDelay >= 2, "respawn retries cover a late AudioDeviceInput")

local function view(extra)
	return VoiceLogic.present({
		mode = extra.mode or "Team",
		availability = extra.availability or "Ready",
		outsideMatch = extra.outsideMatch or "Off",
		localEnabled = extra.localEnabled,
		muted = extra.muted == true,
		selfUserId = extra.selfUserId or 10,
		selfTeam = extra.selfTeam,
		seats = extra.seats,
		deviceReady = extra.deviceReady == true,
		signalAvailable = extra.signalAvailable == true,
		speaking = extra.speaking == true,
		serverDetail = extra.serverDetail,
	})
end

local studio = view({
	availability = "StudioBlocked",
	localEnabled = false,
	selfTeam = "Blue",
	seats = practice,
	deviceReady = false,
})
assert(string.find(studio.title, "Studio", 1, true) ~= nil)
assert(studio.youLine == "You: not eligible")
assert(studio.micLine == nil and studio.pulse == false)
assert(string.find(studio.detail, "Publish", 1, true) ~= nil)

local down = view({
	availability = "Unavailable",
	serverDetail = "Voice routing failed and proximity fallback failed. The match still runs.",
	localEnabled = false,
})
assert(string.find(down.title, "Unavailable", 1, true) ~= nil)
assert(down.detail == "Voice routing failed and proximity fallback failed. The match still runs.")
assert(down.youLine == "You: not eligible")

local bots = view({
	localEnabled = true,
	selfTeam = "Blue",
	seats = practice,
	deviceReady = true,
	signalAvailable = false,
	speaking = true,
})
assert(bots.youLine == "You: live")
assert(bots.peerCount == 0)
assert(bots.micLine == "Mic armed", "no analyzer means mic armed, not a fake speaking pulse")
assert(bots.pulse == false)
assert(string.find(bots.detail, "Bots are silent", 1, true) ~= nil)
assert(string.find(bots.detail, "enemy cats cannot hear you", 1, true) ~= nil)
assert(bots.tone == "ready")

local talking = view({
	localEnabled = true,
	selfTeam = "Blue",
	seats = rivals,
	deviceReady = true,
	signalAvailable = true,
	speaking = true,
})
assert(talking.micLine == "Speaking" and talking.pulse == true)
assert(talking.footer == "You: live · Speaking")
assert(talking.peerCount == 1)
assert(string.find(talking.detail, "Bots are not on voice", 1, true) ~= nil)

local hush = view({
	localEnabled = true,
	muted = true,
	selfTeam = "Blue",
	seats = rivals,
	deviceReady = true,
	signalAvailable = true,
	speaking = true,
})
assert(hush.youLine == "You: muted" and hush.micLine == nil and hush.pulse == false)
assert(hush.tone == "muted")

local ineligible = view({
	localEnabled = false,
	muted = true,
	selfTeam = "Blue",
	seats = rivals,
	deviceReady = true,
})
assert(ineligible.youLine == "You: not eligible", "not eligible wins over muted")
assert(ineligible.pulse == false)

local waiting = view({
	localEnabled = nil,
	selfTeam = "Blue",
	seats = rivals,
	deviceReady = true,
})
assert(waiting.youLine == "You: checking")
assert(string.find(waiting.youLine, "live", 1, true) == nil)

local hub = view({
	localEnabled = true,
	selfTeam = nil,
	seats = rivals,
	deviceReady = true,
	outsideMatch = "Off",
})
assert(string.find(hub.title, "Off", 1, true) ~= nil)
assert(hub.plan.kind == "Silent")
assert(hub.micLine == nil, "a quiet hub does not say the mic is armed")
assert(string.find(hub.detail, "hub and stalls", 1, true) ~= nil)

local near = view({
	mode = "Proximity",
	localEnabled = true,
	selfTeam = nil,
	deviceReady = true,
	outsideMatch = "Proximity",
})
assert(string.find(near.title, "Proximity", 1, true) ~= nil)
assert(near.youLine == "You: live")
assert(near.micLine == "Mic armed")
print("PASS: team voice allow-lists, bot silence, studio copy, mute and mic-armed states")
