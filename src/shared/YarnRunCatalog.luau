--!strict

-- Shared Yarn Run layout. Server simulates; client paints the same seed.
-- Daily UTC seed keeps stream layouts identical for a calendar day.

local Types = require(script.Parent.Types)

export type SegmentKind =
	"empty"
	| "dog"
	| "sign"
	| "yarn"
	| "roomba"
	| "dogYarn"
	| "signYarn"
	| "zigzag"
	| "tunnel"
	| "gap"
	| "fountain"
	| "bridge"
	| "billboard"
	| "power"

export type ObstacleKind = "dog" | "sign" | "yarn" | "roomba" | "wall" | "speed" | "magnet" | "shield" | "double"

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

export type GhostSample = {
	t: number,
	lane: number,
	y: number,
	z: number,
}

export type YarnBest = {
	score: number,
	meters: number,
	combo: number,
	samples: { GhostSample },
}

export type PowerId = "speed" | "magnet" | "shield" | "double"

local POWERS: { PowerId } = { "speed", "magnet", "shield", "double" }

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
	SpeedBurstSeconds = 2.8,
	SpeedBurstMul = 1.72,
	RoombaMul = 1.45,
	MagnetSeconds = 4.2,
	DoubleSeconds = 5.5,
	GhostHz = 8,
	GhostCap = 480,
	Runners = { "NyanRocket", "Shadowpounce", "ChairmanMeow" } :: { Types.YarnRunnerId },
}

local function unit(seed: number, salt: number): number
	local n = (math.floor(seed) * 1103515245 + salt * 12345) % 2147483648
	return n / 2147483648
end

function YarnRunCatalog.laneX(lane: number): number
	local xs = YarnRunCatalog.LaneXs
	local index = math.clamp(math.floor(lane), 0, 2) + 1
	return xs[index]
end

function YarnRunCatalog.runnerTag(id: string): string
	if id == "Shadowpounce" then
		return "Shad"
	elseif id == "ChairmanMeow" then
		return "Chai"
	end
	return "Nyan"
end

function YarnRunCatalog.utcDay(unix: number): number
	return math.floor(unix / 86400)
end

function YarnRunCatalog.dailySeed(unix: number): number
	return YarnRunCatalog.utcDay(unix) * 7919 + 404
end

function YarnRunCatalog.dayKey(unix: number): string
	local ok, text = pcall(function()
		return os.date("!%Y-%m-%d", math.floor(unix))
	end)
	if ok and typeof(text) == "string" then
		return text
	end
	return `UTC-{YarnRunCatalog.utcDay(unix)}`
end

function YarnRunCatalog.isPickup(kind: ObstacleKind): boolean
	return kind == "speed" or kind == "magnet" or kind == "shield" or kind == "double" or kind == "yarn" or kind == "roomba"
end

function YarnRunCatalog.isLethal(kind: ObstacleKind): boolean
	return kind == "dog" or kind == "sign" or kind == "wall"
end

function YarnRunCatalog.powerAt(seed: number, index: number): PowerId
	local mix = math.abs(math.floor(seed) * 3 + index * 5)
	return POWERS[(mix % #POWERS) + 1]
end

function YarnRunCatalog.pickupLabel(kind: ObstacleKind): string
	if kind == "speed" then
		return "SPEED BURST"
	elseif kind == "magnet" then
		return "MAGNET ON"
	elseif kind == "shield" then
		return "SHIELD UP"
	elseif kind == "double" then
		return "2X YARN"
	elseif kind == "roomba" then
		return "ROOMBA RAIL"
	end
	return "YARN"
end

function YarnRunCatalog.kindAt(seed: number, index: number): SegmentKind
	if index < YarnRunCatalog.StartGrace then
		return "empty"
	end
	local heat = math.clamp((index - YarnRunCatalog.StartGrace) / 18, 0, 1)
	local bag: { { kind: SegmentKind, w: number } } = {
		{ kind = "empty", w = 0.13 - 0.06 * heat },
		{ kind = "yarn", w = 0.11 - 0.03 * heat },
		{ kind = "dog", w = 0.10 },
		{ kind = "sign", w = 0.09 },
		{ kind = "roomba", w = 0.07 },
		{ kind = "dogYarn", w = 0.07 },
		{ kind = "signYarn", w = 0.06 },
		{ kind = "power", w = 0.08 },
		{ kind = "fountain", w = 0.06 },
	}
	if index >= 5 then
		table.insert(bag, { kind = "zigzag", w = 0.06 + 0.04 * heat })
		table.insert(bag, { kind = "gap", w = 0.05 + 0.03 * heat })
	end
	if index >= 6 then
		table.insert(bag, { kind = "tunnel", w = 0.05 + 0.04 * heat })
		table.insert(bag, { kind = "billboard", w = 0.05 + 0.03 * heat })
	end
	if index >= 8 then
		table.insert(bag, { kind = "bridge", w = 0.05 + 0.05 * heat })
	end
	local total = 0
	for _, row in bag do
		total += math.max(0, row.w)
	end
	local r = unit(seed, index * 17 + 3) * total
	local acc = 0
	for _, row in bag do
		acc += math.max(0, row.w)
		if r <= acc then
			return row.kind
		end
	end
	return "dog"
end

function YarnRunCatalog.segment(seed: number, index: number): Segment
	local kind = YarnRunCatalog.kindAt(seed, index)
	local lane = math.floor(unit(seed, index * 31 + 9) * 3)
	local other = (lane + 1 + math.floor(unit(seed, index * 51 + 2) * 2)) % 3
	local baseZ = index * YarnRunCatalog.SegmentLength
	local obstacles: { Obstacle } = {}

	local function add(obstacleKind: ObstacleKind, atLane: number, zOff: number)
		table.insert(obstacles, { kind = obstacleKind, lane = atLane, z = baseZ + zOff })
	end

	if kind == "dog" or kind == "dogYarn" then
		add("dog", lane, 22)
	end
	if kind == "sign" or kind == "signYarn" then
		add("sign", lane, 22)
	end
	if kind == "yarn" or kind == "dogYarn" or kind == "signYarn" then
		add("yarn", if kind == "yarn" then lane else other, 16)
	end
	if kind == "roomba" then
		add("roomba", lane, 20)
	end
	if kind == "zigzag" then
		add("dog", lane, 12)
		add("dog", other, 28)
		add("yarn", (lane + 2) % 3, 20)
	end
	if kind == "tunnel" then
		add("sign", 0, 22)
		add("sign", 1, 22)
		add("sign", 2, 22)
	end
	if kind == "gap" then
		add("roomba", 1, 10)
		add("dog", 0, 28)
		add("dog", 1, 28)
		add("dog", 2, 28)
	end
	if kind == "fountain" then
		add("yarn", 0, 14)
		add("yarn", 1, 18)
		add("yarn", 2, 14)
		add("yarn", 1, 28)
		if unit(seed, index * 19) > 0.55 then
			add(YarnRunCatalog.powerAt(seed, index), other, 24)
		end
	end
	if kind == "bridge" then
		add("wall", 0, 16)
		add("wall", 2, 16)
		add("wall", 0, 28)
		add("wall", 2, 28)
		add("yarn", 1, 22)
	end
	if kind == "billboard" then
		add("wall", lane, 20)
		add("yarn", other, 16)
	end
	if kind == "power" then
		add(YarnRunCatalog.powerAt(seed, index), lane, 18)
	end
	if kind == "empty" and index >= 3 and unit(seed, index * 91 + 1) > 0.72 then
		add(YarnRunCatalog.powerAt(seed, index + 3), other, 18)
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

function YarnRunCatalog.ghostAt(samples: { GhostSample }, elapsed: number): GhostSample?
	if #samples == 0 then
		return nil
	end
	if elapsed <= samples[1].t then
		return samples[1]
	end
	local last = samples[#samples]
	if elapsed >= last.t then
		return last
	end
	for i = 2, #samples do
		local a = samples[i - 1]
		local b = samples[i]
		if elapsed <= b.t then
			local span = math.max(0.001, b.t - a.t)
			local u = (elapsed - a.t) / span
			return {
				t = elapsed,
				lane = if u < 0.5 then a.lane else b.lane,
				y = a.y + (b.y - a.y) * u,
				z = a.z + (b.z - a.z) * u,
			}
		end
	end
	return last
end

function YarnRunCatalog.isRunner(id: string): boolean
	for _, runner in YarnRunCatalog.Runners do
		if runner == id then
			return true
		end
	end
	return false
end

return YarnRunCatalog
