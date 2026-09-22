--!strict

-- Hard-only finish for Cat Rift practice bots. BotService still moves and attacks.
-- Callers pass enemies that team fog already shows, and whether walking onto
-- that cat is a legal dive. This module does not read the map.
--
-- A goal ranks above a full-HP camp and soft lane last-hitting. It loses to
-- low-HP flee, peel, Canal Levi, a camp that is already hurt, a cat already
-- in face range, and an active safe siege (a post, a stall, or an open yarn
-- core). Easy and Normal never take it.
-- Damage, items, and cast chance stay elsewhere.

local BotFinishLogic = {}

export type Difficulty = "Easy" | "Normal" | "Hard"

-- Within a short chase, this HP or lower is worth leaving farm.
BotFinishLogic.CloseHp = 0.4
-- A rotate-length walk only commits when the cat is this low.
BotFinishLogic.LongHp = 0.28
-- About two face-range contests. Same lane or the next camp.
BotFinishLogic.Chase = 64
-- Farther than that, up to a jungle-to-lane rotate. Not a map-long hunt.
BotFinishLogic.Long = 112

export type Cat = {
	userId: number,
	x: number,
	z: number,
	hpRatio: number,
	alive: boolean,
	-- Caller: allowDive for stepping onto this cat. Empty towers stay false.
	diveOk: boolean,
}

export type FinishQuery = {
	difficulty: Difficulty,
	x: number,
	z: number,
	selfHp: number,
	retreatHp: number,
	enemies: { Cat },
}

export type FinishGoal = {
	userId: number,
	x: number,
	z: number,
	hpRatio: number,
	-- True when the walk is past the short chase and used the tighter HP bar.
	long: boolean,
}

local function flat(ax: number, az: number, bx: number, bz: number): number
	local dx = ax - bx
	local dz = az - bz
	return math.sqrt(dx * dx + dz * dz)
end

-- HP cap for this distance. Nil when the walk is too far to bother.
function BotFinishLogic.limit(distance: number): number?
	if distance <= BotFinishLogic.Chase then
		return BotFinishLogic.CloseHp
	end
	if distance <= BotFinishLogic.Long then
		return BotFinishLogic.LongHp
	end
	return nil
end

-- Living cat, inside a chase band, at or under that band's HP.
function BotFinishLogic.worth(hpRatio: number, distance: number): boolean
	if hpRatio <= 0 then
		return false
	end
	local cap = BotFinishLogic.limit(distance)
	if not cap then
		return false
	end
	return hpRatio <= cap
end

-- Higher is more urgent. Nil when the cat is not a finish.
-- A clearly lower cat beats a closer one. A hundredth of HP does not.
function BotFinishLogic.urgency(hpRatio: number, distance: number): number?
	if not BotFinishLogic.worth(hpRatio, distance) then
		return nil
	end
	return (1 - hpRatio) * 1000 - distance
end

function BotFinishLogic.pick(query: FinishQuery): FinishGoal?
	if query.difficulty ~= "Hard" then
		return nil
	end
	if query.selfHp <= query.retreatHp then
		return nil
	end

	local best: Cat? = nil
	local bestScore = -1e9
	local bestDist = 0
	for _, enemy in query.enemies do
		if enemy.alive and enemy.diveOk then
			local gap = flat(query.x, query.z, enemy.x, enemy.z)
			local score = BotFinishLogic.urgency(enemy.hpRatio, gap)
			local take = false
			if score then
				if not best then
					take = true
				elseif score > bestScore + 0.01 then
					take = true
				elseif math.abs(score - bestScore) <= 0.01 and enemy.userId < best.userId then
					take = true
				end
			end
			if take and score then
				best = enemy
				bestScore = score
				bestDist = gap
			end
		end
	end

	if not best then
		return nil
	end
	return {
		userId = best.userId,
		x = best.x,
		z = best.z,
		hpRatio = best.hpRatio,
		long = bestDist > BotFinishLogic.Chase,
	}
end

return BotFinishLogic
