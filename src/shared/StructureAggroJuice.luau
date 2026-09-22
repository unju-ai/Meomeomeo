--!strict

-- Pure rules for Cat Rift structure-lock juice.
-- TowerService.pickTarget still owns who gets the bolt, the range, and the interval.
-- The server writes that champion id onto the structure. This module only decides
-- whether the client should paint a night-market danger cue from that id.
-- Hub / Yarn Run / Koi / Party / Arcade stay quiet.
-- Bounty floats, brush, Levi, and structure-fall FX are not this module.

local StructureAggroJuice = {}

-- Replicated display attribute. Nil when the structure's current pick is not a champion.
StructureAggroJuice.LockAttribute = "MeoLockUserId"

-- Night-market coral danger. Stalls add a warm lantern glare; the ground ring stays coral.
StructureAggroJuice.Coral = { 255, 118, 104 }
StructureAggroJuice.Lantern = { 255, 168, 72 }

-- Display only. These do not change tower range, damage, or shot interval.
StructureAggroJuice.GroundY = 1.15
-- Sits on the stall's paper lanterns (MapBuilder offset), not a new shot height.
StructureAggroJuice.LanternLift = 7.2
StructureAggroJuice.RingSpan = 8.4
StructureAggroJuice.AllyRingSpan = 6.4
StructureAggroJuice.FootSpan = 4.2
StructureAggroJuice.LanternSpan = 2.2
StructureAggroJuice.AllyLanternSpan = 1.5
StructureAggroJuice.FlashScale = 1.35
StructureAggroJuice.AllyFlashScale = 0.85
StructureAggroJuice.FlashSeconds = 0.28
StructureAggroJuice.FloatRise = 2.6

export type CueKind = "local" | "ally" | "none"
export type Look = "post" | "stall" | "core"
export type Rgb = { number }

function StructureAggroJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

function StructureAggroJuice.look(kind: string?, tier: string?): Look
	if kind == "Nexus" or tier == "Core" then
		return "core"
	end
	if tier == "Inner" then
		return "stall"
	end
	return "post"
end

-- You always read a structure that has picked you.
-- A teammate's lock is a faint cue, and only while that structure is in vision.
-- An enemy who is the pick stays unmarked.
function StructureAggroJuice.cueKind(
	localUserId: number,
	targetUserId: number?,
	sameTeam: boolean,
	structureLit: boolean
): CueKind
	if targetUserId == nil then
		return "none"
	end
	if localUserId == targetUserId then
		return "local"
	end
	if sameTeam and structureLit then
		return "ally"
	end
	return "none"
end

function StructureAggroJuice.shouldPaint(cue: CueKind): boolean
	return cue == "local" or cue == "ally"
end

function StructureAggroJuice.wantsStructureRing(cue: CueKind): boolean
	return StructureAggroJuice.shouldPaint(cue)
end

-- Thin coral foot ring is yours. Allies only get the faint structure cue.
function StructureAggroJuice.wantsFootRing(cue: CueKind): boolean
	return cue == "local"
end

function StructureAggroJuice.wantsLantern(cue: CueKind, look: Look): boolean
	return StructureAggroJuice.shouldPaint(cue) and look == "stall"
end

-- Existing towerShot already carries the bolt. This is the extra coral hit read.
function StructureAggroJuice.wantsShotFlash(cue: CueKind): boolean
	return StructureAggroJuice.shouldPaint(cue)
end

function StructureAggroJuice.ringSpan(cue: CueKind): number
	if cue == "ally" then
		return StructureAggroJuice.AllyRingSpan
	end
	return StructureAggroJuice.RingSpan
end

function StructureAggroJuice.ringTransparency(cue: CueKind): number
	if cue == "ally" then
		return 0.74
	end
	return 0.38
end

function StructureAggroJuice.footTransparency(): number
	return 0.58
end

function StructureAggroJuice.lanternSpan(cue: CueKind): number
	if cue == "ally" then
		return StructureAggroJuice.AllyLanternSpan
	end
	return StructureAggroJuice.LanternSpan
end

function StructureAggroJuice.lanternTransparency(cue: CueKind): number
	if cue == "ally" then
		return 0.78
	end
	return 0.42
end

function StructureAggroJuice.flashScale(cue: CueKind): number
	if cue == "ally" then
		return StructureAggroJuice.AllyFlashScale
	end
	return StructureAggroJuice.FlashScale
end

function StructureAggroJuice.flashTransparency(cue: CueKind): number
	if cue == "ally" then
		return 0.55
	end
	return 0.12
end

function StructureAggroJuice.ringRgb(): Rgb
	return StructureAggroJuice.Coral
end

function StructureAggroJuice.lanternRgb(): Rgb
	return StructureAggroJuice.Lantern
end

function StructureAggroJuice.flashRgb(): Rgb
	return StructureAggroJuice.Coral
end

return StructureAggroJuice
