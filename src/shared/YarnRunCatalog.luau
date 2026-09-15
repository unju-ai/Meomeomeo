--!strict

-- Shared Yarn Run layout. Server simulates; client paints the same seed.

local Types = require(script.Parent.Types)

export type SegmentKind = "empty" | "dog" | "sign" | "yarn" | "roomba" | "dogYarn" | "signYarn"

export type ObstacleKind = "dog" | "sign" | "yarn" | "roomba"

export type Obstacle = {
	kind: ObstacleKind,
	lane: number,
	z: number,
}

export type Segment = {
	index: number,
	kind: SegmentKind,
	obstacles: { Obstacle },
}

local YarnRunCatalog = {
	SegmentLength = 40,
	LaneXs = { -10, 0, 10 },
	BaseSpeed = 30,
	SpeedPerSecond = 0.42,
	MaxSpeed = 74,
	JumpHeight = 7.2,
	JumpSeconds = 0.52,
	SlideSeconds = 0.42,
	HitWindow = 2.4,
	StartGrace = 2,
	Runners = { "NyanRocket", "Shadowpounce", "ChairmanMeow" } :: { Types.YarnRunnerId },
}

local KINDS: { SegmentKind } = { "empty", "dog", "sign", "yarn", "roomba", "dogYarn", "signYarn" }

local function unit(seed: number, salt: number): number
	local n = (math.floor(seed) * 1103515245 + salt * 12345) % 2147483648
	return n / 2147483648
end

function YarnRunCatalog.laneX(lane: number): number
	local xs = YarnRunCatalog.LaneXs
	local index = math.clamp(math.floor(lane), 0, 2) + 1
	return xs[index]
end

function YarnRunCatalog.parseRunner(value: unknown): Types.YarnRunnerId
	if value == "Shadowpounce" or value == "ChairmanMeow" then
		return value
	end
	return "NyanRocket"
end

function YarnRunCatalog.kindAt(seed: number, index: number): SegmentKind
	if index < YarnRunCatalog.StartGrace then
		return "empty"
	end
	local r = unit(seed, index * 17 + 3)
	if r < 0.1 then
		return "empty"
	elseif r < 0.3 then
		return "dog"
	elseif r < 0.46 then
		return "sign"
	elseif r < 0.68 then
		return "yarn"
	elseif r < 0.78 then
		return "roomba"
	elseif r < 0.89 then
		return "dogYarn"
	end
	return "signYarn"
end

function YarnRunCatalog.segment(seed: number, index: number): Segment
	local kind = YarnRunCatalog.kindAt(seed, index)
	local lane = math.floor(unit(seed, index * 31 + 9) * 3)
	local other = (lane + 1 + math.floor(unit(seed, index * 51 + 2) * 2)) % 3
	local baseZ = index * YarnRunCatalog.SegmentLength
	local obstacles: { Obstacle } = {}
	if kind == "dog" or kind == "dogYarn" then
		table.insert(obstacles, { kind = "dog", lane = lane, z = baseZ + 22 })
	end
	if kind == "sign" or kind == "signYarn" then
		table.insert(obstacles, { kind = "sign", lane = lane, z = baseZ + 22 })
	end
	if kind == "yarn" or kind == "dogYarn" or kind == "signYarn" then
		table.insert(obstacles, { kind = "yarn", lane = if kind == "yarn" then lane else other, z = baseZ + 16 })
	end
	if kind == "roomba" then
		table.insert(obstacles, { kind = "roomba", lane = lane, z = baseZ + 20 })
	end
	return {
		index = index,
		kind = kind,
		obstacles = obstacles,
	}
end

function YarnRunCatalog.obstaclesAround(seed: number, z: number, behind: number?, ahead: number?): { Obstacle }
	local bag: { Obstacle } = {}
	local start = math.max(0, math.floor((z - (behind or 20)) / YarnRunCatalog.SegmentLength))
	local last = math.floor((z + (ahead or 50)) / YarnRunCatalog.SegmentLength)
	for index = start, last do
		for _, obstacle in YarnRunCatalog.segment(seed, index).obstacles do
			table.insert(bag, obstacle)
		end
	end
	return bag
end

function YarnRunCatalog.isRunner(id: string): boolean
	for _, runner in YarnRunCatalog.Runners do
		if runner == id then
			return true
		end
	end
	return false
end

-- Silence unused (kinds table documents the set).
local _ = KINDS

return YarnRunCatalog
