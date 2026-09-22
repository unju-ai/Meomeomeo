-- Cat Rift AFK warning + reconnect flag. Run through tools/test-afk.py.

local function stage(phase, isBot, alive, connected, idle)
	return AfkLogic.stage({
		phase = phase,
		isBot = isBot,
		alive = alive,
		connected = connected,
		idle = idle,
	})
end

assert(AfkLogic.WarnSeconds == 45)
assert(AfkLogic.MarkSeconds == 90)
assert(AfkLogic.Toast == "Still there?")
assert(AfkLogic.Chip == "AFK")

assert(stage("InProgress", false, true, true, 44.9) == "present")
assert(stage("InProgress", false, true, true, 45) == "warn")
assert(stage("InProgress", false, true, true, 89.9) == "warn")
assert(stage("InProgress", false, true, true, 90) == "marked")
assert(stage("InProgress", false, true, true, 0) == "present", "input stamp resets the idle")

-- Bots ignored. Hub and other phases stay quiet.
assert(stage("InProgress", true, true, true, 120) == "quiet")
assert(stage("Lobby", false, true, true, 120) == "quiet")
assert(stage("ChampionSelect", false, true, true, 120) == "quiet")
assert(stage("Ended", false, true, true, 120) == "quiet")

-- Dead or disconnected: do not newly trip. The clock is frozen.
assert(stage("InProgress", false, false, true, 90) == "paused")
assert(stage("InProgress", false, true, false, 90) == "paused")

-- Acted at t=100, died at t=120 (20s idle). Still dead at t=200.
local deadIdle = AfkLogic.idleSeconds(200, 100, 0, false, 120)
assert(deadIdle == 20, "death does not eat the stamp")
assert(stage("InProgress", false, false, true, deadIdle) == "paused")
local credit = AfkLogic.creditAfterPause(0, 120, 200)
assert(credit == 80)
local afterRespawn = AfkLogic.idleSeconds(200, 100, credit, true, nil)
assert(afterRespawn == 20, "respawn keeps the pre-death idle")
assert(stage("InProgress", false, true, true, afterRespawn) == "present")

-- Fountain regen is not a walk. A recall channel is standing still.
-- The fountain teleport at the end of recall is a jump, not input.
assert(AfkLogic.sampleMove(0.2, 0, 0.25) == "still")
assert(AfkLogic.sampleMove(0, 0, 0.25) == "still")
assert(AfkLogic.sampleMove(4, 0, 0.25) == "walk")
assert(AfkLogic.sampleMove(10, 0, 0.25) == "still", "a short knock is not a walk")
assert(AfkLogic.sampleMove(80, 0, 0.25) == "jump")

-- Recent fountain stand (idle 10s) does not warn. 45s of no input does.
assert(stage("InProgress", false, true, true, 10) == "present")
assert(stage("InProgress", false, true, true, 45) == "warn")

-- Rejoin sets connected true and clears remake's missing teammate.
local seats = {
	RemakeLogic.seat(1, "Blue", false, nil, false),
	RemakeLogic.seat(2, "Blue", false, nil, true),
}
assert(RemakeLogic.allyMissing(seats, "Blue"))
local connected, flipped = AfkLogic.restoreConnected(false, false)
assert(connected == true and flipped == true)
seats[1].connected = connected
assert(not RemakeLogic.allyMissing(seats, "Blue"), "rejoin clears the missing teammate")
local again, againFlipped = AfkLogic.restoreConnected(false, true)
assert(again == true and againFlipped == false, "already connected is not a second flip")
local botConnected, botFlipped = AfkLogic.restoreConnected(true, true)
assert(botConnected == true and botFlipped == false)

assert(AfkLogic.whisper("Nib") == "Nib is away.")
assert(AfkLogic.whisper("") == "A teammate is away.")
assert(AfkLogic.wantsLocalToast("Moba", "InProgress", false))
assert(not AfkLogic.wantsLocalToast("Hub", "Lobby", false))
assert(not AfkLogic.wantsLocalToast("YarnRun", "InProgress", true))
assert(not AfkLogic.wantsLocalToast("Moba", "ChampionSelect", false))
assert(AfkLogic.wantsWhisper(true, false, false, true))
assert(not AfkLogic.wantsWhisper(true, true, false, true), "you already got the toast")
assert(not AfkLogic.wantsWhisper(false, false, false, true), "enemies stay quiet")
assert(not AfkLogic.wantsWhisper(true, false, true, true))

assert(ScoreboardPaint.catLabel("Whiskers", false, true, false) == "YOU · Whiskers")
assert(ScoreboardPaint.catLabel("Whiskers", false, true, false, true) == "YOU · Whiskers · AFK")
assert(ScoreboardPaint.catLabel("Nib", true, false, false, true) == "Nib (Bot)")
assert(ScoreboardPaint.catLabel("Whiskers", false, false, true, true) == "★ Whiskers · AFK")

print("afk smoke ok")
