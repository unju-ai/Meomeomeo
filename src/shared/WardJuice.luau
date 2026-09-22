--!strict

-- Pure helpers for Cat Rift ward place / lifetime juice.
-- WardService still owns range, duration, stacks, health, and vision.
-- The client paints from the replicated part (owner, placedAt, expiresAt)
-- and the existing vision ward id list. No second timer and no fog leak.

local WardJuice = {}

-- Puff only if the part was planted this recently (server clock).
-- Late vision of an older ward shows the silhouette without a fake place puff.
WardJuice.PlaceWindow = 1.25
-- Clock slack so a stamp a hair ahead of the client still counts as fresh.
WardJuice.PlaceSlack = 0.35
-- Last seconds before the server expiry pulse. Display only — not a new duration.
WardJuice.FadeLead = 12
WardJuice.PuffSeconds = 0.4
WardJuice.PopSeconds = 0.34
WardJuice.ToastSeconds = 1.15
WardJuice.BobSpeed = 2.4
WardJuice.BobLift = 0.38

-- Night-market cream / amber. Pink matches the control yarn ball.
WardJuice.Cream = { 255, 243, 224 }
WardJuice.Amber = { 255, 196, 74 }
WardJuice.Pink = { 255, 92, 196 }
WardJuice.Ink = { 52, 36, 32 }

export type Rgb = { number }
export type CueKind = "local" | "ally" | "enemy" | "none"

-- Cat Rift fight only. Hub / Yarn Run / Koi / Party / Arcade stay quiet.
function WardJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

-- Same gate as the ward mesh: allies always, enemies only if vision already listed them.
function WardJuice.revealed(sameTeam: boolean, inVisionList: boolean): boolean
	return sameTeam or inVisionList
end

function WardJuice.cueKind(localUserId: number, ownerUserId: number?, sameTeam: boolean, inVisionList: boolean): CueKind
	if not WardJuice.revealed(sameTeam, inVisionList) then
		return "none"
	end
	if ownerUserId ~= nil and localUserId == ownerUserId then
		return "local"
	end
	if sameTeam then
		return "ally"
	end
	return "enemy"
end

function WardJuice.shouldPaint(cue: string): boolean
	return cue == "local" or cue == "ally" or cue == "enemy"
end

function WardJuice.plantLine(kind: string): string
	if kind == "control" then
		return "Control Yarn planted"
	end
	return "Ward planted"
end

function WardJuice.wantsToast(cue: string): boolean
	return cue == "local"
end

function WardJuice.placeFresh(placedAt: number?, now: number): boolean
	if placedAt == nil then
		return false
	end
	local age = now - placedAt
	return age >= -WardJuice.PlaceSlack and age <= WardJuice.PlaceWindow
end

function WardJuice.shouldPuff(cue: string, placedAt: number?, now: number, already: boolean): boolean
	if already or not WardJuice.shouldPaint(cue) then
		return false
	end
	return WardJuice.placeFresh(placedAt, now)
end

-- Pop only a ward we were already painting. A hidden expire must not mark fog.
function WardJuice.shouldPop(wasShown: boolean): boolean
	return wasShown
end

function WardJuice.fading(expiresAt: number?, now: number): boolean
	if expiresAt == nil then
		return false
	end
	local left = expiresAt - now
	return left > 0 and left <= WardJuice.FadeLead
end

function WardJuice.expired(expiresAt: number?, now: number): boolean
	if expiresAt == nil then
		return false
	end
	return now >= expiresAt
end

-- 0 while steady. Rises through the fade window with a soft pulse.
-- If the stamp has passed but the part is still replicated (server sweep is 0.4s),
-- hold the peak so the silhouette does not snap solid before the pop.
function WardJuice.fadeAlpha(expiresAt: number?, now: number): number
	if expiresAt == nil then
		return 0
	end
	local left = expiresAt - now
	if left > WardJuice.FadeLead then
		return 0
	end
	local t = if left <= 0 then 1 else 1 - (left / WardJuice.FadeLead)
	local pulse = 0.5 + 0.5 * math.sin(now * 8)
	return math.clamp(0.08 + t * 0.28 + pulse * 0.12 * t, 0, 0.55)
end

function WardJuice.bodyTransparency(cue: string, expiresAt: number?, now: number): number
	local base = 0.42
	if cue == "local" then
		base = 0.12
	elseif cue == "ally" then
		base = 0.22
	end
	return math.clamp(base + WardJuice.fadeAlpha(expiresAt, now), 0, 0.9)
end

function WardJuice.pulseScale(expiresAt: number?, now: number): number
	if not WardJuice.fading(expiresAt, now) then
		return 1
	end
	return 1 + 0.08 * math.sin(now * 8)
end

function WardJuice.bobOffset(now: number): number
	return math.sin(now * WardJuice.BobSpeed) * WardJuice.BobLift
end

function WardJuice.scale(cue: string): number
	if cue == "local" then
		return 1
	end
	if cue == "ally" then
		return 0.9
	end
	return 0.72
end

-- Pole, lantern, yarn. Allies read cream/amber. Revealed enemies stay pink.
function WardJuice.palette(cue: string, kind: string): (Rgb, Rgb, Rgb)
	if cue == "enemy" then
		return WardJuice.Pink, WardJuice.Pink, WardJuice.Cream
	end
	if kind == "control" then
		return WardJuice.Cream, WardJuice.Amber, WardJuice.Cream
	end
	return WardJuice.Cream, WardJuice.Cream, WardJuice.Amber
end

-- Extra minimap transparency near expire. Caller must already be painting a visible ward.
function WardJuice.minimapTransparency(base: number, expiresAt: number?, now: number): number
	return math.clamp(base + WardJuice.fadeAlpha(expiresAt, now) * 0.85, 0, 0.72)
end

return WardJuice
