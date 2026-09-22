--!strict

-- Pure helpers for Cat Rift recall channel juice.
-- CombatService still owns the 7s channel, cancel-on-order, and fountain teleport.
-- The client only reads the existing recalling edge and the recall CombatFx emit.

local RecallJuice = {}

-- Display fallback when a snapshot omits recallEndsAt. Not the server timer.
RecallJuice.ChannelFallback = 7
-- Replication slack so a channel that reached its end reads as success.
RecallJuice.SuccessSlack = 0.25
RecallJuice.TickGap = 1.35
RecallJuice.WashSeconds = 0.42
RecallJuice.FlashSeconds = 0.28
RecallJuice.ShatterSeconds = 0.32
-- Keep the swirl a beat after the end time so the finish emit can replace it.
RecallJuice.HoldAfter = 0.5
RecallJuice.FinishGrace = 0.45
RecallJuice.SuppressAfter = 0.7
RecallJuice.SwirlSpeed = 1.65

-- interruptRecall emits origin = Vector3.zero. Fountain spawns are not at the origin.
RecallJuice.CancelOriginRadius = 1

-- Night-market amber / cream while channeling. Mint = home. Coral = broken.
RecallJuice.Cream = { 255, 243, 224 }
RecallJuice.Amber = { 255, 196, 74 }
RecallJuice.Mint = { 120, 196, 150 }
RecallJuice.Coral = { 255, 122, 98 }
RecallJuice.Ink = { 52, 36, 32 }

export type CueKind = "local" | "ally" | "enemy" | "none"
export type Outcome = "idle" | "channel" | "success" | "cancel"

-- Cat Rift fight only. Hub / Yarn Run / Koi / Party / Arcade stay quiet.
function RecallJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

-- 0 at the server start stamp, 1 at recallEndsAt. Does not pick the duration.
function RecallJuice.progress(startedAt: number?, endsAt: number?, now: number): number
	if startedAt == nil or endsAt == nil then
		return 0
	end
	local span = endsAt - startedAt
	if span <= 0 then
		return 0
	end
	return math.clamp((now - startedAt) / span, 0, 1)
end

-- Timestamp reading of the combat edge (prev.recallEndsAt vs server now).
function RecallJuice.stateOutcome(wasRecalling: boolean, recalling: boolean, endsAt: number?, now: number): Outcome
	if recalling then
		return "channel"
	end
	if not wasRecalling then
		return "idle"
	end
	if endsAt ~= nil and now + RecallJuice.SuccessSlack >= endsAt then
		return "success"
	end
	return "cancel"
end

function RecallJuice.originIsCancel(x: number, y: number, z: number): boolean
	local limit = RecallJuice.CancelOriginRadius
	return (x * x + y * y + z * z) < (limit * limit)
end

-- Emit-site reading. Start: duration > 0. Cancel: duration 0 at the zero sentinel.
-- Success: duration 0 at the fountain spawn (completeRecall).
function RecallJuice.fxOutcome(duration: number, x: number, y: number, z: number): Outcome
	if duration > 0 then
		return "channel"
	end
	if RecallJuice.originIsCancel(x, y, z) then
		return "cancel"
	end
	return "success"
end

function RecallJuice.cueKind(localUserId: number, targetUserId: number, sameTeam: boolean, inVision: boolean): CueKind
	if localUserId == targetUserId then
		return "local"
	end
	if sameTeam then
		return "ally"
	end
	if inVision then
		return "enemy"
	end
	return "none"
end

function RecallJuice.shouldPaint(cue: string): boolean
	return cue == "local" or cue == "ally" or cue == "enemy"
end

-- Allies stay visible (their bodies already do). Enemies only while fog-lit.
function RecallJuice.shouldReveal(cue: string, inVision: boolean): boolean
	if cue == "local" or cue == "ally" then
		return true
	end
	if cue == "enemy" then
		return inVision
	end
	return false
end

function RecallJuice.cancelBanner(): string
	return "RECALL CANCELED"
end

function RecallJuice.trackSpan(cue: string): number
	if cue == "local" then
		return 6.6
	end
	if cue == "ally" then
		return 5
	end
	return 4.4
end

-- Foot swirl grows from a small disc to the track as the channel fills.
function RecallJuice.fillSpan(cue: string, progress: number): number
	local full = RecallJuice.trackSpan(cue)
	local p = math.clamp(progress, 0, 1)
	return full * (0.18 + 0.82 * p)
end

function RecallJuice.trackTransparency(cue: string): number
	if cue == "local" then
		return 0.72
	end
	return 0.88
end

function RecallJuice.fillTransparency(cue: string, progress: number): number
	local p = math.clamp(progress, 0, 1)
	if cue == "local" then
		return 0.55 - p * 0.28
	end
	if cue == "ally" then
		return 0.78 - p * 0.06
	end
	return 0.84
end

function RecallJuice.tickDue(lastAt: number, now: number): boolean
	return (now - lastAt) >= RecallJuice.TickGap
end

-- One soft silhouette wash around the midpoint. Start wash is separate.
function RecallJuice.crossedWash(prev: number, next: number): boolean
	return prev < 0.5 and next >= 0.5
end

return RecallJuice
