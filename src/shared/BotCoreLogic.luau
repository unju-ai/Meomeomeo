--!strict

-- Hard-only yarn-core siege for Cat Rift practice bots. BotService still
-- moves and attacks through the existing objective lock. Outer posts and
-- lantern stalls stay in BotSiegeLogic and never become this goal.
--
-- Callers pass the enemy yarn core, including whether StructureLogic already
-- marked it vulnerable. This module does not read the map.
--
-- A goal needs one of: a winning wave (two allied kittens and more than
-- theirs), the core already at half HP, or two allies already scratching it.
-- An empty full-HP core is not a solo walk. Easy and Normal never take it.
-- Flee and a critical peel refuse here. Peel, Canal Levi, a hurt camp, and
-- a wounded cat already in face range still outrank the walk in JungleBotLogic.
-- The goal is handed over as the same siege hint a post would use.

local BotCoreLogic = {}

export type Difficulty = "Easy" | "Normal" | "Hard"

-- Own fountain (x about -176) to the enemy yarn core (x = 168) still fits.
BotCoreLogic.Range = 360
-- Same crashing wave as a healthy post siege.
BotCoreLogic.MinKittens = 2
BotCoreLogic.LowRatio = 0.5
-- Other allies already in auto-attack range. This bot does not count itself.
BotCoreLogic.AllyHitters = 2

export type CoreView = {
	id: string,
	x: number,
	z: number,
	health: number,
	maxHealth: number,
	vulnerable: boolean,
	alive: boolean,
	allyKittens: number,
	enemyKittens: number,
	allyHitters: number,
}

export type CoreQuery = {
	difficulty: Difficulty,
	x: number,
	z: number,
	selfHp: number,
	retreatHp: number,
	peelCritical: boolean,
	core: CoreView?,
}

export type CoreGoal = {
	id: string,
	x: number,
	z: number,
}

local function flat(ax: number, az: number, bx: number, bz: number): number
	local dx = ax - bx
	local dz = az - bz
	return math.sqrt(dx * dx + dz * dz)
end

local function ratioOf(core: CoreView): number
	if core.maxHealth <= 0 then
		return 1
	end
	return core.health / core.maxHealth
end

-- True when hitting this core is sane, before the walk distance.
function BotCoreLogic.safe(core: CoreView): boolean
	if not core.alive or not core.vulnerable or core.health <= 0 then
		return false
	end
	if ratioOf(core) <= BotCoreLogic.LowRatio then
		return true
	end
	if core.allyKittens >= BotCoreLogic.MinKittens and core.allyKittens > core.enemyKittens then
		return true
	end
	if core.allyHitters >= BotCoreLogic.AllyHitters then
		return true
	end
	return false
end

-- True when this core is worth hitting from (x, z).
function BotCoreLogic.eligible(x: number, z: number, core: CoreView): boolean
	if not BotCoreLogic.safe(core) then
		return false
	end
	if flat(x, z, core.x, core.z) > BotCoreLogic.Range then
		return false
	end
	return true
end

function BotCoreLogic.pick(query: CoreQuery): CoreGoal?
	if query.difficulty ~= "Hard" then
		return nil
	end
	if query.peelCritical or query.selfHp <= query.retreatHp then
		return nil
	end
	local core = query.core
	if not core or not BotCoreLogic.eligible(query.x, query.z, core) then
		return nil
	end
	return {
		id = core.id,
		x = core.x,
		z = core.z,
	}
end

return BotCoreLogic
