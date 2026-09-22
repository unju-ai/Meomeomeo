--!strict

-- Pure helpers for Cat Rift death → fountain respawn juice.
-- CombatService still owns the timer, the teleport, and the full heal.
-- The client only reads alive / respawnAt (combat snapshot + match roster)
-- and paints. Not a second respawn clock.

local FountainRegenJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("FountainRegenJuice"))

local RespawnJuice = {}

-- Last seconds that pulse. Display only — the server deadline is unchanged.
RespawnJuice.PulseLead = 3
RespawnJuice.PulseSpeed = 7.5
RespawnJuice.PuffSeconds = 0.38
RespawnJuice.WashSeconds = 0.3
-- Let the fountain pivot replicate before the silhouette tint.
RespawnJuice.WashDelay = 0.12
-- One arrival cue per return. Recall success and fountain regen stay separate.
RespawnJuice.ArrivalGap = 1.1
RespawnJuice.BackSeconds = 0.7

-- Night-market cream / amber while down. Mint = fountain arrival.
RespawnJuice.Cream = { 255, 243, 224 }
RespawnJuice.Amber = { 255, 196, 74 }
RespawnJuice.Mint = { 120, 196, 150 }
RespawnJuice.Ink = { 52, 36, 32 }

export type CueKind = "local" | "ally" | "enemy" | "none"

-- Cat Rift fight only. Hub / Yarn Run / Koi / Party / Arcade stay quiet.
function RespawnJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

-- Local combat snapshot. Dead stays down even if the stamp is missing for a frame.
function RespawnJuice.localDown(alive: boolean, respawnAt: number?, now: number): boolean
	if not alive then
		return true
	end
	return RespawnJuice.downFromStamp(respawnAt, now)
end

-- Roster field used by the scoreboard. Future respawnAt means still down.
function RespawnJuice.downFromStamp(respawnAt: number?, now: number): boolean
	return typeof(respawnAt) == "number" and (respawnAt :: number) > now
end

function RespawnJuice.remaining(respawnAt: number?, now: number): number
	if typeof(respawnAt) ~= "number" then
		return 0
	end
	return math.max(0, (respawnAt :: number) - now)
end

-- Ceil so the chip hits 0 only at the server deadline.
function RespawnJuice.displaySeconds(seconds: number): number
	return math.max(0, math.ceil(seconds - 1e-6))
end

-- Under a minute: seconds-remaining. Longer: mm:ss (same shape as the match clock).
function RespawnJuice.chipRead(seconds: number): string
	local left = RespawnJuice.displaySeconds(seconds)
	if left >= 60 then
		local minutes = math.floor(left / 60)
		local secs = left % 60
		return string.format("%d:%02d", minutes, secs)
	end
	return `{left}s`
end

function RespawnJuice.caption(): string
	return "Respawn"
end

function RespawnJuice.hint(): string
	return "fountain"
end

function RespawnJuice.shouldPulse(seconds: number): boolean
	return RespawnJuice.displaySeconds(seconds) <= RespawnJuice.PulseLead
end

-- 0 while the chip is calm. 0–1 sine in the last three seconds.
function RespawnJuice.pulseAmount(seconds: number, now: number): number
	if not RespawnJuice.shouldPulse(seconds) then
		return 0
	end
	return 0.5 + 0.5 * math.sin(now * RespawnJuice.PulseSpeed)
end

-- Soft ink wash. Slightly deeper while the last seconds pulse.
function RespawnJuice.washTransparency(amount: number): number
	local pulse = math.clamp(amount, 0, 1)
	return 0.84 - 0.05 * pulse
end

-- Alive flipped false → true. Recall never clears alive, so it does not arrive here.
function RespawnJuice.justReturned(wasAlive: boolean?, alive: boolean): boolean
	return wasAlive == false and alive == true
end

-- Roster edge: a future stamp cleared (or reached). First sighting is not a return.
function RespawnJuice.stampReturned(wasDown: boolean, respawnAt: number?, now: number): boolean
	return wasDown and not RespawnJuice.downFromStamp(respawnAt, now)
end

-- The respawn heal is one server fill, not a kit heal.
-- Fountain pad ticks suppress on their own; this covers a body still off the pad.
function RespawnJuice.skipLoudHeal(returned: boolean): boolean
	return returned
end

function RespawnJuice.cueKind(localUserId: number, targetUserId: number, sameTeam: boolean, inVision: boolean): CueKind
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

function RespawnJuice.shouldPaint(cue: string): boolean
	return cue == "local" or cue == "ally" or cue == "enemy"
end

function RespawnJuice.wantsWash(cue: string): boolean
	return cue == "local" or cue == "ally"
end

function RespawnJuice.wantsBackLabel(cue: string): boolean
	return cue == "ally"
end

function RespawnJuice.backLabel(): string
	return "back"
end

function RespawnJuice.arrivalDue(lastAt: number, now: number): boolean
	return (now - lastAt) >= RespawnJuice.ArrivalGap
end

-- Prefer the live body when it is already on the fountain pad.
-- Otherwise the team pad, so a stale corpse does not eat the puff.
function RespawnJuice.arrivalXZ(team: string?, rootX: number?, rootZ: number?): (number?, number?)
	if team == "Red" then
		if rootX ~= nil and rootZ ~= nil and FountainRegenJuice.nearFountain("Red", rootX, rootZ) then
			return rootX, rootZ
		end
		return FountainRegenJuice.padX("Red"), FountainRegenJuice.PadZ
	end
	if team == "Blue" then
		if rootX ~= nil and rootZ ~= nil and FountainRegenJuice.nearFountain("Blue", rootX, rootZ) then
			return rootX, rootZ
		end
		return FountainRegenJuice.padX("Blue"), FountainRegenJuice.PadZ
	end
	if rootX ~= nil and rootZ ~= nil then
		return rootX, rootZ
	end
	return nil, nil
end

function RespawnJuice.puffScale(cue: string): number
	if cue == "local" then
		return 2.15
	end
	if cue == "ally" then
		return 1.15
	end
	return 0.8
end

function RespawnJuice.puffTransparency(cue: string): number
	if cue == "local" then
		return 0.48
	end
	if cue == "ally" then
		return 0.74
	end
	return 0.86
end

function RespawnJuice.ringSpan(cue: string): number
	if cue == "local" then
		return 5.4
	end
	if cue == "ally" then
		return 3.2
	end
	return 2.4
end

function RespawnJuice.ringTransparency(cue: string): number
	if cue == "local" then
		return 0.5
	end
	if cue == "ally" then
		return 0.8
	end
	return 0.9
end

function RespawnJuice.washAmount(cue: string): number
	if cue == "local" then
		return 0.36
	end
	if cue == "ally" then
		return 0.14
	end
	return 0
end

return RespawnJuice
