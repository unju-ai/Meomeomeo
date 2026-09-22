--!strict

-- Pure rules for Cat Rift lane-kitten wave telegraphs.
-- MinionService still owns the waits (Config.Minions.FirstWaveDelay, then
-- each lane's kittens with KittenStep between them, then WaveInterval).
-- This module only decides which spawn mouths may glow, and when.
-- It does not change counts, gold, or pathing.
-- Jungle camps stay on CampRespawnJuice. Hub / Yarn Run / Koi / Party / Arcade stay quiet.

local VisionLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("VisionLogic"))

local WaveJuice = {}

-- Night-market cream and lantern. Display only.
WaveJuice.Cream = { 255, 243, 224 }
WaveJuice.Lantern = { 255, 176, 72 }

-- Mirrors Config.Minions and MinionService's between-kitten wait.
-- Prediction only. The service stamps the values it is actually waiting.
WaveJuice.FirstWaveDelay = 6
WaveJuice.WaveInterval = 22
WaveJuice.PerLane = 3
WaveJuice.KittenStep = 0.35

-- Soft glow before a lane's first kitten. Inside the 2–3s read, short of the whole cadence.
WaveJuice.LeadSeconds = 2.5
-- Brief cream hush as that first kitten steps out. Later kittens in the lane do not repeat it.
WaveJuice.ArrivalSeconds = 0.6

-- Same mouths MinionService.spawnOne uses (x = ±148, lane Z, y = 2.2).
WaveJuice.SpawnX = 148
WaveJuice.SpawnY = 2.2

export type Schedule = {
	firstDelay: number,
	waveInterval: number,
	perLane: number,
	kittenStep: number,
}

export type Mouth = {
	id: string,
	team: string,
	lane: string,
	x: number,
	y: number,
	z: number,
}

export type Cue = {
	id: string,
	team: string,
	lane: string,
	x: number,
	y: number,
	z: number,
	kind: "telegraph" | "arrival",
	-- 0 at the start of the window, 1 at the end.
	alpha: number,
	-- Seconds after the wave anchor when this lane's first kitten leaves.
	depart: number,
}

type LaneDef = { name: string, z: number }
type TeamDef = { name: string, sign: number }

-- Constants.Lanes order. Top leaves first, then mid, then bot.
local LANES: { LaneDef } = {
	{ name = "Top", z = -80 },
	{ name = "Mid", z = 0 },
	{ name = "Bot", z = 80 },
}

local TEAMS: { TeamDef } = {
	{ name = "Blue", sign = -1 },
	{ name = "Red", sign = 1 },
}

function WaveJuice.defaultSchedule(): Schedule
	return {
		firstDelay = WaveJuice.FirstWaveDelay,
		waveInterval = WaveJuice.WaveInterval,
		perLane = WaveJuice.PerLane,
		kittenStep = WaveJuice.KittenStep,
	}
end

function WaveJuice.laneCount(): number
	return #LANES
end

-- Time from one wave's first kitten to the next wave's first kitten.
-- Includes every between-kitten wait in the spawn loop, then WaveInterval.
function WaveJuice.cycle(schedule: Schedule): number
	return WaveJuice.laneCount() * schedule.perLane * schedule.kittenStep + schedule.waveInterval
end

-- waveIndex and laneIndex are 0-based. Lane 0 is Top.
function WaveJuice.departElapsed(waveIndex: number, laneIndex: number, schedule: Schedule): number
	local laneWait = laneIndex * schedule.perLane * schedule.kittenStep
	return schedule.firstDelay + waveIndex * WaveJuice.cycle(schedule) + laneWait
end

function WaveJuice.mouths(): { Mouth }
	local list: { Mouth } = {}
	for _, team in TEAMS do
		for _, lane in LANES do
			table.insert(list, {
				id = `{team.name}-{lane.name}`,
				team = team.name,
				lane = lane.name,
				x = team.sign * WaveJuice.SpawnX,
				y = WaveJuice.SpawnY,
				z = lane.z,
			})
		end
	end
	return list
end

-- Cat Rift fight only. A fountain glow during draft or the hub does not play.
function WaveJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

-- Match fog memory. Lit now, or already explored this match. Unexplored stays dark.
function WaveJuice.mouthKnown(fogBits: { number }?, exploredBits: { number }?, x: number, z: number): boolean
	local index = VisionLogic.indexOf(x, z)
	if typeof(fogBits) == "table" and VisionLogic.bitOn(fogBits, index) then
		return true
	end
	if typeof(exploredBits) == "table" and VisionLogic.bitOn(exploredBits, index) then
		return true
	end
	return false
end

-- One cue per mouth: the lead into that lane's first kitten, then a short arrival.
-- The other kittens in the same lane are the existing stagger, not extra telegraphs.
function WaveJuice.cues(elapsed: number, schedule: Schedule): { Cue }
	local out: { Cue } = {}
	if elapsed ~= elapsed or elapsed < 0 or schedule.perLane < 1 or schedule.kittenStep < 0 then
		return out
	end
	local lead = WaveJuice.LeadSeconds
	local arrival = WaveJuice.ArrivalSeconds
	if lead <= 0 or arrival < 0 then
		return out
	end
	local cycle = WaveJuice.cycle(schedule)
	if cycle <= 1e-4 then
		return out
	end
	local maxLane = (WaveJuice.laneCount() - 1) * schedule.perLane * schedule.kittenStep
	local minDepart = elapsed - arrival
	local maxDepart = elapsed + lead
	local wLo = math.floor((minDepart - schedule.firstDelay - maxLane) / cycle)
	local wHi = math.floor((maxDepart - schedule.firstDelay) / cycle)
	if wLo < 0 then
		wLo = 0
	end
	if wHi < wLo then
		return out
	end
	if wHi > wLo + 2 then
		wHi = wLo + 2
	end

	for waveIndex = wLo, wHi do
		for laneSlot, lane in LANES do
			-- departElapsed lane index is 0-based. The array itself is 1-based.
			local depart = WaveJuice.departElapsed(waveIndex, laneSlot - 1, schedule)
			local kind: ("telegraph" | "arrival")? = nil
			local alpha = 0
			if elapsed >= depart - lead and elapsed < depart then
				kind = "telegraph"
				alpha = (elapsed - (depart - lead)) / lead
			elseif elapsed >= depart and elapsed < depart + arrival then
				kind = "arrival"
				alpha = (elapsed - depart) / arrival
			end
			if kind ~= nil then
				local paintedKind = kind :: "telegraph" | "arrival"
				for _, team in TEAMS do
					table.insert(out, {
						id = `{team.name}-{lane.name}`,
						team = team.name,
						lane = lane.name,
						x = team.sign * WaveJuice.SpawnX,
						y = WaveJuice.SpawnY,
						z = lane.z,
						kind = paintedKind,
						alpha = math.clamp(alpha, 0, 1),
						depart = depart,
					})
				end
			end
		end
	end
	return out
end

function WaveJuice.visible(rows: { Cue }, fogBits: { number }?, exploredBits: { number }?): { Cue }
	local out: { Cue } = {}
	for _, row in rows do
		if WaveJuice.mouthKnown(fogBits, exploredBits, row.x, row.z) then
			table.insert(out, row)
		end
	end
	return out
end

-- Minimap blink. Higher means fainter. Arrival fades out; the lead softly pulses.
function WaveJuice.blinkTransparency(kind: string, alpha: number): number
	if kind == "arrival" then
		return math.clamp(0.15 + alpha * 0.7, 0, 1)
	end
	local pulse = 0.5 + 0.5 * math.sin(alpha * math.pi * 5)
	return math.clamp(0.15 + (1 - pulse) * 0.6, 0, 1)
end

return WaveJuice
