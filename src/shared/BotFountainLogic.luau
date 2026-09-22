--!strict

-- Enemy fountain pad for Cat Rift practice bots. The disk is FountainRegenJuice:
-- radius 32 at Blue x = -176 and Red x = 176, z = 0. That is the same pad
-- ShopService.nearFountain measures (Config.Shop.FountainRadius from the
-- MapBuilder fountain spawn) and the pad fountain regen already uses.
-- Not a second radius.
--
-- A hunt, finish, peel, or generic step onto the enemy pad is refused.
-- The ally pad stays legal (recall, shop, regen). An open yarn-core siege
-- is not this pad: callers pass allowCore when that walk already earned
-- the step. The core sits inside the disk and is still a siege.
-- Easy, Normal, and Hard share the disk. Callers decide priority.

local FountainRegenJuice = require(script.Parent:WaitForChild("FountainRegenJuice"))

local BotFountainLogic = {}

export type TeamId = "Blue" | "Red"

BotFountainLogic.Radius = FountainRegenJuice.Radius

function BotFountainLogic.enemyOf(team: TeamId): TeamId
	if team == "Blue" then
		return "Red"
	end
	return "Blue"
end

function BotFountainLogic.onPad(padTeam: TeamId, x: number, z: number): boolean
	return FountainRegenJuice.nearFountain(padTeam, x, z)
end

function BotFountainLogic.onEnemyPad(team: TeamId, x: number, z: number): boolean
	return BotFountainLogic.onPad(BotFountainLogic.enemyOf(team), x, z)
end

function BotFountainLogic.onAllyPad(team: TeamId, x: number, z: number): boolean
	return BotFountainLogic.onPad(team, x, z)
end

-- True when a chase should not step onto (x, z).
-- allowCore keeps an open-nexus siege BotCoreLogic already accepted.
function BotFountainLogic.refuseChase(team: TeamId, x: number, z: number, allowCore: boolean?): boolean
	if allowCore then
		return false
	end
	return BotFountainLogic.onEnemyPad(team, x, z)
end

-- Just outside the closed disk, toward the lanes (toward x = 0).
-- z is kept so a side lane is not pulled to mid.
function BotFountainLogic.laneRim(team: TeamId, z: number): (number, number)
	local padX = FountainRegenJuice.padX(BotFountainLogic.enemyOf(team))
	local toward = if padX > 0 then -1 else 1
	local exitX = padX + toward * (FountainRegenJuice.Radius + 1)
	return exitX, z
end

return BotFountainLogic
