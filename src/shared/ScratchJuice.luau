--!strict

-- Pure helpers for Cat Rift auto-attack (scratch) juice.
-- Windup, range, interval, and damage stay in Config.AutoAttack / CombatService.
-- The client only paints. Not a second combat system.
-- Yarn Cleave keeps the wider cream arc in ActiveJuice.
-- Skillshot bolts stay on the projectile path.
-- Hub / Yarn Run / Koi / Party / Arcade stay quiet.

local ScratchJuice = {}

-- Display lengths. They do not change Config.AutoAttack.Windup or Interval.
ScratchJuice.WindupSeconds = 0.14
ScratchJuice.HitSeconds = 0.16
ScratchJuice.TickSeconds = 0.11

-- Night-market cream. The damage number stays on the float path.
ScratchJuice.Cream = { 255, 243, 224 }

export type Beat = "windup" | "hit"
export type CueKind = "local" | "ally" | "enemy" | "none"

-- Cat Rift fight only.
function ScratchJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

-- duration > 0: the server just started the existing windup (it used to return silent).
-- Missing or <= 0: the scratch already landed on the existing aa emit.
function ScratchJuice.beat(duration: number?): Beat
	if typeof(duration) == "number" and duration > 0 then
		return "windup"
	end
	return "hit"
end

-- Local always. Allies stay visible with their bodies. Enemies only while fog-lit.
function ScratchJuice.cueKind(localUserId: number, actorUserId: number, sameTeam: boolean, inVision: boolean): CueKind
	if localUserId == actorUserId then
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

function ScratchJuice.shouldPaint(cue: string): boolean
	return cue == "local" or cue == "ally" or cue == "enemy"
end

-- The local victim gets a tiny cream tick on the landing beat.
-- Damage numbers stay on kind = "float". Kittens, camps, and structures have no champion id.
function ScratchJuice.wantsTick(localUserId: number, targetUserId: number?): boolean
	return targetUserId ~= nil and localUserId == targetUserId
end

function ScratchJuice.wantsImpact(beat: string, localUserId: number, targetUserId: number?): boolean
	return beat == "hit" and ScratchJuice.wantsTick(localUserId, targetUserId)
end

-- This tick never draws +N. CombatFloat already did.
function ScratchJuice.paintsNumber(): boolean
	return false
end

-- One short claw toward the target. Not the landing arc, and not Cleave.
function ScratchJuice.windupCount(): number
	return 1
end

function ScratchJuice.windupSpan(): number
	return 0.12
end

function ScratchJuice.windupReach(cue: string): number
	if cue == "local" then
		return 1.85
	end
	if cue == "ally" then
		return 1.55
	end
	return 1.3
end

-- Long thin claw. The landing slab is the flat scratch.
function ScratchJuice.windupSlab(): (number, number, number)
	return 0.24, 0.36, 2.05
end

-- Narrow cream scratch. Cleave's local arc is 5 segments over a much wider span.
function ScratchJuice.arcCount(cue: string): number
	if cue == "local" then
		return 2
	end
	return 1
end

function ScratchJuice.arcSpan(cue: string): number
	if cue == "local" then
		return 0.72
	end
	return 0.46
end

function ScratchJuice.arcReach(cue: string): number
	if cue == "local" then
		return 3.15
	end
	if cue == "ally" then
		return 2.6
	end
	return 2.15
end

-- Shorter and thinner than Cleave's wide swipe slab (1.55, 0.2, 2.6).
function ScratchJuice.arcSlab(): (number, number, number)
	return 0.62, 0.12, 1.25
end

function ScratchJuice.tickScale(): number
	return 0.36
end

function ScratchJuice.tickTransparency(): number
	return 0.28
end

return ScratchJuice
