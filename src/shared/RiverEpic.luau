--!strict

-- Canal Levi, the one river epic. Not a dragon, not a baron, not a herald.
-- JungleService spawns the body. MatchService stores the team buff and the deadlines.
-- The HUD paints mm:ss from those server times. This module does not read the clock.

local RiverEpic = {}

RiverEpic.Id = "CanalLevi"
RiverEpic.Name = "Canal Levi"
-- Center canal, between mid and the south river crab. Off both lane corridors.
RiverEpic.X = 0
RiverEpic.Z = 24
RiverEpic.Y = 4.8
-- Practice is untimed. 3:00 is the short end of a mid-match wake so a playtest can reach it.
RiverEpic.SpawnSeconds = 180
-- One return. The second take is the last.
RiverEpic.RespawnSeconds = 90
RiverEpic.Lives = 2
RiverEpic.Health = 1100
RiverEpic.Damage = 28
RiverEpic.Gold = 140
RiverEpic.Xp = 100
RiverEpic.Leash = 52
RiverEpic.Speed = 11
-- Match-lifetime. A second take does not stack. Autos and abilities only.
RiverEpic.DamageAmp = 1.08
RiverEpic.BuffChip = "Canal Levi · +8% damage"

export type Phase = "waiting" | "alive" | "returning" | "spent"

export type Clock = {
	phase: Phase,
	spawnsUsed: number,
	respawnAt: number?,
}

export type Marker = "body" | "pit" | "down" | "none"

export type HudTone = "wait" | "up" | "spent"

export type HudRead = {
	clock: string,
	objective: string,
	tone: HudTone,
}

function RiverEpic.blank(): Clock
	return {
		phase = "waiting",
		spawnsUsed = 0,
		respawnAt = nil,
	}
end

-- `alive` is the living body. Spawn is requested once; the caller creates the part.
function RiverEpic.step(clock: Clock, elapsed: number, alive: boolean): (Clock, boolean)
	if alive or clock.phase == "alive" then
		return clock, false
	end
	if clock.phase == "waiting" and elapsed >= RiverEpic.SpawnSeconds then
		return {
			phase = "alive",
			spawnsUsed = clock.spawnsUsed + 1,
			respawnAt = nil,
		}, true
	end
	if clock.phase == "returning" and clock.respawnAt ~= nil and elapsed >= clock.respawnAt then
		return {
			phase = "alive",
			spawnsUsed = clock.spawnsUsed + 1,
			respawnAt = nil,
		}, true
	end
	return clock, false
end

function RiverEpic.killed(clock: Clock, elapsed: number): Clock
	if clock.phase ~= "alive" then
		return clock
	end
	if clock.spawnsUsed < RiverEpic.Lives then
		return {
			phase = "returning",
			spawnsUsed = clock.spawnsUsed,
			respawnAt = elapsed + RiverEpic.RespawnSeconds,
		}
	end
	return {
		phase = "spent",
		spawnsUsed = clock.spawnsUsed,
		respawnAt = nil,
	}
end

-- Last-hit team keeps the buff for the rest of the match. The other side can earn its own.
-- A second take on the same side stays one buff.
function RiverEpic.grant(blue: boolean, red: boolean, team: string): (boolean, boolean)
	if team == "Blue" then
		return true, red
	end
	if team == "Red" then
		return blue, true
	end
	return blue, red
end

function RiverEpic.outgoingMul(buffed: boolean): number
	if buffed then
		return RiverEpic.DamageAmp
	end
	return 1
end

function RiverEpic.scale(amount: number, buffed: boolean): number
	return amount * RiverEpic.outgoingMul(buffed)
end

-- The living body is fog. The pit is map knowledge once the epic has woken,
-- including the one respawn window. Nothing before the first wake, nothing after it is spent.
function RiverEpic.marker(phase: string, inVision: boolean): Marker
	if phase == "alive" and inVision then
		return "body"
	end
	if phase == "alive" then
		return "pit"
	end
	if phase == "returning" then
		return "down"
	end
	return "none"
end

-- Hard mid only, and only when they are not already committed to a camp.
function RiverEpic.wantsHardPath(difficulty: string, jungler: boolean, holding: boolean): boolean
	return difficulty == "Hard" and jungler == true and holding ~= true
end

local function mmss(total: number): string
	local minutes = math.floor(total / 60)
	local secs = total % 60
	return string.format("%d:%02d", minutes, secs)
end

-- Match elapsed. Floors, so the first second stays 0:00.
function RiverEpic.formatClock(seconds: number): string
	return mmss(math.max(0, math.floor(seconds + 1e-6)))
end

-- Countdown. Ceils, so the line reaches 0:00 only at the deadline.
function RiverEpic.formatCountdown(seconds: number): string
	return mmss(math.max(0, math.ceil(seconds - 1e-6)))
end

function RiverEpic.elapsed(now: number, startedAt: number?): number
	if startedAt == nil then
		return 0
	end
	return math.max(0, now - startedAt)
end

function RiverEpic.secondsLeft(now: number, nextAt: number?): number?
	if nextAt == nil then
		return nil
	end
	return math.max(0, nextAt - now)
end

-- Absolute server time of the next body. Nil while it is up, spent, or before the fight starts.
-- `respawnAt` is match-elapsed seconds from RiverEpic.killed, not a wall clock.
function RiverEpic.dueAt(startedAt: number?, phase: string, respawnAt: number?): number?
	if startedAt == nil then
		return nil
	end
	if phase == "waiting" then
		return startedAt + RiverEpic.SpawnSeconds
	end
	if phase == "returning" and respawnAt ~= nil then
		return startedAt + respawnAt
	end
	return nil
end

function RiverEpic.objectiveTone(phase: string): HudTone
	if phase == "alive" then
		return "up"
	end
	if phase == "spent" then
		return "spent"
	end
	return "wait"
end

-- `secondsLeft` is the server remainder. Nil means the deadline has not been published yet.
function RiverEpic.objectiveLine(phase: string, secondsLeft: number?): string
	if phase == "alive" then
		return "Levi UP"
	end
	if phase == "spent" then
		return "Levi taken"
	end
	if phase == "waiting" or phase == "returning" then
		if secondsLeft == nil then
			return "Levi"
		end
		return `Levi {RiverEpic.formatCountdown(secondsLeft)}`
	end
	return ""
end

-- Paint inputs are the snapshot fields. The client does not decide when Levi wakes.
function RiverEpic.hudRead(now: number, startedAt: number?, phase: string?, nextAt: number?): HudRead
	local clock = RiverEpic.formatClock(RiverEpic.elapsed(now, startedAt))
	if phase == nil then
		return {
			clock = clock,
			objective = "",
			tone = "wait",
		}
	end
	return {
		clock = clock,
		objective = RiverEpic.objectiveLine(phase, RiverEpic.secondsLeft(now, nextAt)),
		tone = RiverEpic.objectiveTone(phase),
	}
end

-- Your own buff keeps BuffChip. The other side is named on that same line.
function RiverEpic.purseLine(team: string, blue: boolean, red: boolean): string?
	local mine = (team == "Blue" and blue) or (team == "Red" and red)
	if mine then
		local otherName = if team == "Blue" then "Red" else "Blue"
		local other = if team == "Blue" then red else blue
		if other then
			return `{RiverEpic.BuffChip} · {otherName} too`
		end
		return RiverEpic.BuffChip
	end
	if blue and red then
		return "Blue + Red hold Levi"
	end
	if blue then
		return "Blue holds Levi"
	end
	if red then
		return "Red holds Levi"
	end
	return nil
end

return RiverEpic
