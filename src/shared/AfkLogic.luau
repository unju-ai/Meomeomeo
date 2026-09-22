--!strict

-- Cat Rift idle warning. Pure rules — MatchService owns the clock, the
-- last-input stamp, and the snapshot fields. Bots are ignored. Hub modes
-- never call this. The fight keeps going: no replacement cat, no early end.
--
-- Dead time and a disconnect freeze the stamp. Fountain regen and a recall
-- channel do not count as movement: only a real walk does. A fountain snap,
-- a death snap, or a knock is a jump, not input.

local AfkLogic = {}

-- Local toast while alive and InProgress.
AfkLogic.WarnSeconds = 45
-- Teammate tag + kill-feed whisper. The player stays in the fight.
AfkLogic.MarkSeconds = 90

AfkLogic.Toast = "Still there?"
AfkLogic.Chip = "AFK"

-- Pad jitter (fountain regen) stays under this.
AfkLogic.WalkStuds = 0.75
-- A walking cat, including Pounce Boots. Studs per second.
AfkLogic.MinWalkSpeed = 2
AfkLogic.MaxWalkSpeed = 36
-- Recall finish, death fountain, or a knock: far and fast, not a walk.
AfkLogic.JumpStuds = 18
AfkLogic.JumpSpeed = 40

export type Stage = "quiet" | "present" | "warn" | "marked" | "paused"

export type StageQuery = {
	phase: string,
	isBot: boolean,
	alive: boolean,
	connected: boolean,
	idle: number,
}

export type MoveSample = "walk" | "still" | "jump"

function AfkLogic.idleSeconds(now: number, lastInputAt: number, credit: number, running: boolean, pauseBegan: number?): number
	local endAt = now
	if not running and typeof(pauseBegan) == "number" then
		endAt = pauseBegan
	end
	return math.max(0, endAt - lastInputAt - math.max(0, credit))
end

-- Add the frozen stretch back onto the credit so a respawn does not inherit it.
function AfkLogic.creditAfterPause(credit: number, pauseBegan: number?, now: number): number
	if typeof(pauseBegan) ~= "number" then
		return credit
	end
	return credit + math.max(0, now - pauseBegan)
end

function AfkLogic.stage(query: StageQuery): Stage
	if query.isBot or query.phase ~= "InProgress" then
		return "quiet"
	end
	if not query.alive or not query.connected then
		return "paused"
	end
	if query.idle >= AfkLogic.MarkSeconds then
		return "marked"
	end
	if query.idle >= AfkLogic.WarnSeconds then
		return "warn"
	end
	return "present"
end

-- dx/dz are the flat step since the last sample. dt is seconds.
function AfkLogic.sampleMove(dx: number, dz: number, dt: number): MoveSample
	local dist = math.sqrt(dx * dx + dz * dz)
	if dt <= 0 then
		return "still"
	end
	local speed = dist / dt
	if dist >= AfkLogic.JumpStuds and speed >= AfkLogic.JumpSpeed then
		return "jump"
	end
	if dist >= AfkLogic.WalkStuds and speed >= AfkLogic.MinWalkSpeed and speed <= AfkLogic.MaxWalkSpeed then
		return "walk"
	end
	return "still"
end

-- PlayerAdded / character restore for a human who already has a match seat.
-- Returns the connected flag to store, and whether it flipped (so remake's
-- missing-teammate check can recheck). Bots are not seats we reconnect.
function AfkLogic.restoreConnected(isBot: boolean, connected: boolean): (boolean, boolean)
	if isBot then
		return connected, false
	end
	return true, connected ~= true
end

function AfkLogic.whisper(name: string): string
	if name == "" then
		return "A teammate is away."
	end
	return `{name} is away.`
end

function AfkLogic.wantsLocalToast(mode: string, phase: string, mini: boolean): boolean
	return not mini and mode == "Moba" and phase == "InProgress"
end

-- Teammates only. The idle cat already got the toast. Bots never whisper.
function AfkLogic.wantsWhisper(sameTeam: boolean, isSelf: boolean, isBot: boolean, afk: boolean): boolean
	return sameTeam and not isSelf and not isBot and afk
end

return AfkLogic
