--!strict

-- Canal Levi, the one river epic. Not a dragon, not a baron, not a herald.
-- JungleService spawns the body. MatchService stores the team buff.
-- This module is the clock, the credit, and the minimap rule.

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

return RiverEpic
