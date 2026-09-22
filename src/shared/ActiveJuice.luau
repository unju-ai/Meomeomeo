--!strict

-- Pure helpers for Cat Rift Pawmart active juice.
-- Whisker Lens reveal, Yarn Cleave damage, Stall Fang bonus, and Paper Charm
-- slow immunity stay in WardService / ItemKits / CombatService.
-- The client only paints. Not a second combat system.
-- Hub / Yarn Run / Koi / Party / Arcade stay quiet.

local ActiveJuice = {}

-- Display lengths. They do not change cooldowns, reveal time, or the charm window.
ActiveJuice.LensSeconds = 0.28
ActiveJuice.CleaveSeconds = 0.26
ActiveJuice.FangSeconds = 0.2
ActiveJuice.FangGap = 0.16
ActiveJuice.CharmPuffSeconds = 0.32
ActiveJuice.CharmPopSeconds = 0.22
ActiveJuice.WashSeconds = 0.18

-- Night-market cream / coral / pink. Ink is the bite edge.
ActiveJuice.Cream = { 255, 243, 224 }
ActiveJuice.Coral = { 255, 122, 98 }
ActiveJuice.Pink = { 255, 92, 196 }
ActiveJuice.Ink = { 52, 36, 32 }

export type Rgb = { number }
export type CueKind = "local" | "ally" | "enemy" | "none"
export type CharmBeat = "apply" | "close" | "none"

-- Cat Rift fight only.
function ActiveJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

-- Local always. Allies stay visible with their bodies. Enemies only while fog-lit.
function ActiveJuice.cueKind(localUserId: number, actorUserId: number, sameTeam: boolean, inVision: boolean): CueKind
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

-- Fang paints on the bitten body. Attacker and victim both read it as local.
-- The victim's team sees a faint bite (ally body). Everyone else needs fog.
function ActiveJuice.fangCue(
	localUserId: number,
	attackerUserId: number?,
	targetUserId: number?,
	targetTeam: string?,
	localTeam: string?,
	inVision: boolean
): CueKind
	if attackerUserId ~= nil and localUserId == attackerUserId then
		return "local"
	end
	if targetUserId ~= nil and localUserId == targetUserId then
		return "local"
	end
	if targetTeam ~= nil and localTeam ~= nil and targetTeam == localTeam then
		return "ally"
	end
	if inVision then
		return "enemy"
	end
	return "none"
end

function ActiveJuice.shouldPaint(cue: string): boolean
	return cue == "local" or cue == "ally" or cue == "enemy"
end

-- The execute float is the number. This is only the extra bite flash.
function ActiveJuice.isFangProc(floatKind: string?): boolean
	return floatKind == "execute"
end

-- duration > 0: the existing charm window just opened.
-- duration == 0: that window just ended. Not a damage bite.
function ActiveJuice.charmBeat(duration: number?): CharmBeat
	if typeof(duration) ~= "number" then
		return "none"
	end
	if duration > 0 then
		return "apply"
	end
	return "close"
end

-- One close emit when a live window clears because time reached it.
function ActiveJuice.charmClosed(prevUntil: number?, nextUntil: number?, now: number): boolean
	if prevUntil == nil or nextUntil ~= nil then
		return false
	end
	return now >= prevUntil
end

function ActiveJuice.scale(cue: string): number
	if cue == "local" then
		return 1
	end
	if cue == "ally" then
		return 0.82
	end
	return 0.68
end

function ActiveJuice.transparency(cue: string): number
	if cue == "local" then
		return 0.18
	end
	if cue == "ally" then
		return 0.4
	end
	return 0.55
end

-- Glance at the caster. Not the 32-stud reveal, and not a marker on a hidden ward.
function ActiveJuice.paintsLensRadius(): boolean
	return false
end

function ActiveJuice.marksHiddenWards(): boolean
	return false
end

function ActiveJuice.lensSweepReach(cue: string): number
	if cue == "local" then
		return 5.4
	end
	if cue == "ally" then
		return 4.4
	end
	return 3.6
end

-- Tight glance. The cleave arc is the wide one.
function ActiveJuice.lensCount(cue: string): number
	if cue == "local" then
		return 3
	end
	return 2
end

function ActiveJuice.lensSpan(cue: string): number
	if cue == "local" then
		return 1.15
	end
	return 0.85
end

function ActiveJuice.lensEyeLift(): number
	return 2.35
end

-- Wide cream swipe on the existing cleave circle. More than one segment, so it is not an auto-attack claw.
function ActiveJuice.arcCount(cue: string): number
	if cue == "local" then
		return 5
	end
	return 3
end

function ActiveJuice.arcSpan(cue: string): number
	if cue == "local" then
		return 3.4
	end
	return 2.6
end

function ActiveJuice.swipeReach(radius: number, cue: string): number
	local mul = 0.7
	if cue == "local" then
		mul = 0.86
	elseif cue == "ally" then
		mul = 0.78
	end
	if radius < 0 then
		return 0
	end
	return radius * mul
end

function ActiveJuice.charmPuffScale(cue: string): number
	return 2.15 * ActiveJuice.scale(cue)
end

function ActiveJuice.charmPopScale(cue: string): number
	return 1.05 * ActiveJuice.scale(cue)
end

function ActiveJuice.wantsWash(cue: string): boolean
	return cue == "local"
end

function ActiveJuice.washAmount(cue: string): number
	if cue == "local" then
		return 0.55
	end
	return 0
end

return ActiveJuice
