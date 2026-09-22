--!strict

-- Hard-only peel for Cat Rift practice bots. BotService still moves and attacks.
-- Callers pass allies and enemies that team fog already shows (the same
-- champion list hunts use). This module does not read the map.
--
-- A goal ranks above leftover camps, rotates, soft hunts, and idle lane shove.
-- It loses to low-HP flee and an unsafe tower dive. Canal Levi still wins
-- unless the ally is critically low and that fight is nearby. Easy and Normal
-- never peel. Damage, items, and human controls stay elsewhere.

local BotPeelLogic = {}

export type Difficulty = "Easy" | "Normal" | "Hard"

-- Under this ratio a visible ally with an enemy on them is worth leaving farm.
BotPeelLogic.AllyHp = 0.38
-- Stricter bar. Only this, and a nearby fight, may pull a bot off Canal Levi.
BotPeelLogic.CriticalHp = 0.22
-- Enemy must be this close to the ally. Same neighborhood as a camp contest.
BotPeelLogic.FightRadius = 32
-- Bot-to-fight distance that counts as nearby for the Levi exception.
BotPeelLogic.NearbyRadius = 48

export type Cat = {
	userId: number,
	x: number,
	z: number,
	hpRatio: number,
	alive: boolean,
}

export type PeelQuery = {
	difficulty: Difficulty,
	selfUserId: number,
	x: number,
	z: number,
	selfHp: number,
	retreatHp: number,
	unsafeDive: boolean,
	allies: { Cat },
	enemies: { Cat },
}

export type PeelGoal = {
	allyUserId: number,
	enemyUserId: number,
	x: number,
	z: number,
	allyHp: number,
	critical: boolean,
	nearby: boolean,
}

local function flat(ax: number, az: number, bx: number, bz: number): number
	local dx = ax - bx
	local dz = az - bz
	return math.sqrt(dx * dx + dz * dz)
end

-- Lowest ally first. A tie prefers the ally closer to this bot, then the smaller id.
local function betterAlly(hp: number, dist: number, userId: number, bestHp: number, bestDist: number, bestId: number): boolean
	if hp < bestHp - 0.0001 then
		return true
	end
	if hp > bestHp + 0.0001 then
		return false
	end
	if math.abs(dist - bestDist) > 0.5 then
		return dist < bestDist
	end
	return userId < bestId
end

function BotPeelLogic.pick(query: PeelQuery): PeelGoal?
	if query.difficulty ~= "Hard" then
		return nil
	end
	if query.unsafeDive or query.selfHp <= query.retreatHp then
		return nil
	end

	local bestAlly: Cat? = nil
	local bestEnemy: Cat? = nil
	local bestHp = 2
	local bestDist = 1e9
	local bestId = 0

	for _, ally in query.allies do
		if not ally.alive or ally.userId == query.selfUserId or ally.hpRatio <= 0 or ally.hpRatio > BotPeelLogic.AllyHp then
			continue
		end
		local allyDist = flat(query.x, query.z, ally.x, ally.z)
		local threat: Cat? = nil
		local threatDist = BotPeelLogic.FightRadius + 1
		for _, enemy in query.enemies do
			if enemy.alive then
				local gap = flat(ally.x, ally.z, enemy.x, enemy.z)
				if gap <= BotPeelLogic.FightRadius and (not threat or gap < threatDist - 0.01 or (math.abs(gap - threatDist) <= 0.01 and enemy.userId < threat.userId)) then
					threat = enemy
					threatDist = gap
				end
			end
		end
		if threat and (not bestAlly or betterAlly(ally.hpRatio, allyDist, ally.userId, bestHp, bestDist, bestId)) then
			bestAlly = ally
			bestEnemy = threat
			bestHp = ally.hpRatio
			bestDist = allyDist
			bestId = ally.userId
		end
	end

	if not bestAlly or not bestEnemy then
		return nil
	end
	local enemyDist = flat(query.x, query.z, bestEnemy.x, bestEnemy.z)
	local near = math.min(bestDist, enemyDist) <= BotPeelLogic.NearbyRadius
	return {
		allyUserId = bestAlly.userId,
		enemyUserId = bestEnemy.userId,
		x = bestEnemy.x,
		z = bestEnemy.z,
		allyHp = bestAlly.hpRatio,
		critical = bestAlly.hpRatio <= BotPeelLogic.CriticalHp,
		nearby = near,
	}
end

return BotPeelLogic
