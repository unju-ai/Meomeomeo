--!strict

-- Hard-only siege for Cat Rift practice bots. BotService still moves and attacks
-- through the existing objective lock. Callers pass living enemy structures and
-- the ally / enemy kitten counts already measured under them. This module does
-- not read the map.
--
-- A goal is a vulnerable outer post or an open stall the wave is already on.
-- A healthy post needs two allied kittens and a winning wave. One kitten is
-- enough when that structure is already focused or low. An empty post (no
-- allied kitten) is never a walk, including a low one. The yarn core is never
-- a goal. Easy and Normal never siege.
--
-- Ranking against peel, Canal Levi, and camps lives in JungleBotLogic. This
-- pick already refuses a fleeing bot and a critical peel. Damage, items, and
-- human controls stay elsewhere.

local BotSiegeLogic = {}

export type Difficulty = "Easy" | "Normal" | "Hard"
export type Kind = "Tower" | "Nexus"
export type Tier = "Outer" | "Inner" | "Core"

-- Walk-up distance from the bot to the structure. River to an outer post fits.
-- A camp on the far side of the map does not.
BotSiegeLogic.Range = 100
-- Healthy post: match the crashing-wave dive (two kittens, and more than theirs).
BotSiegeLogic.MinKittens = 2
-- Already being hit, or this low, so one tanking kitten is enough to join.
BotSiegeLogic.LowRatio = 0.5

export type StructureView = {
	id: string,
	x: number,
	z: number,
	health: number,
	maxHealth: number,
	vulnerable: boolean,
	kind: Kind,
	tier: Tier,
	allyKittens: number,
	enemyKittens: number,
	-- Caller: the post is already taking damage (or the bolt is on the wave).
	focused: boolean,
}

export type SiegeQuery = {
	difficulty: Difficulty,
	x: number,
	z: number,
	selfHp: number,
	retreatHp: number,
	peelCritical: boolean,
	structures: { StructureView },
}

export type SiegeGoal = {
	id: string,
	x: number,
	z: number,
	tier: Tier,
}

local function flat(ax: number, az: number, bx: number, bz: number): number
	local dx = ax - bx
	local dz = az - bz
	return math.sqrt(dx * dx + dz * dz)
end

local function ratioOf(structure: StructureView): number
	if structure.maxHealth <= 0 then
		return 1
	end
	return structure.health / structure.maxHealth
end

-- True when this one structure is worth hitting from (x, z).
function BotSiegeLogic.eligible(x: number, z: number, structure: StructureView): boolean
	if not structure.vulnerable or structure.health <= 0 then
		return false
	end
	if structure.kind == "Nexus" or structure.tier == "Core" then
		return false
	end
	if flat(x, z, structure.x, structure.z) > BotSiegeLogic.Range then
		return false
	end
	-- Nothing tanking. Do not step under an empty post.
	if structure.allyKittens < 1 then
		return false
	end
	local ratio = ratioOf(structure)
	local low = ratio <= BotSiegeLogic.LowRatio
	local opened = structure.focused or low
	if structure.allyKittens >= BotSiegeLogic.MinKittens and structure.allyKittens > structure.enemyKittens then
		return true
	end
	if opened then
		return true
	end
	return false
end

local function better(dist: number, ratio: number, id: string, bestDist: number, bestRatio: number, bestId: string): boolean
	if dist < bestDist - 0.5 then
		return true
	end
	if dist > bestDist + 0.5 then
		return false
	end
	if ratio < bestRatio - 0.0001 then
		return true
	end
	if ratio > bestRatio + 0.0001 then
		return false
	end
	return id < bestId
end

function BotSiegeLogic.pick(query: SiegeQuery): SiegeGoal?
	if query.difficulty ~= "Hard" then
		return nil
	end
	if query.peelCritical or query.selfHp <= query.retreatHp then
		return nil
	end

	local best: StructureView? = nil
	local bestDist = 1e9
	local bestRatio = 2
	local bestId = ""
	for _, structure in query.structures do
		if BotSiegeLogic.eligible(query.x, query.z, structure) then
			local gap = flat(query.x, query.z, structure.x, structure.z)
			local ratio = ratioOf(structure)
			if not best or better(gap, ratio, structure.id, bestDist, bestRatio, bestId) then
				best = structure
				bestDist = gap
				bestRatio = ratio
				bestId = structure.id
			end
		end
	end
	if not best then
		return nil
	end
	return {
		id = best.id,
		x = best.x,
		z = best.z,
		tier = best.tier,
	}
end

return BotSiegeLogic
