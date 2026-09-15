--!strict

-- Pure projectile travel. Shared by CombatService (hits) and BotService (lead).

local Targeting = require(script.Parent.Targeting)

local ProjectileLogic = {
	Speed = 72,
	MaxLive = 24,
}

function ProjectileLogic.travelSeconds(origin: Vector3, dest: Vector3, speed: number?): number
	local flat = Targeting.flat(origin, dest)
	local spd = if typeof(speed) == "number" and speed > 1 then speed else ProjectileLogic.Speed
	return math.max(flat.Magnitude / spd, 0.08)
end

function ProjectileLogic.positionAt(origin: Vector3, dest: Vector3, elapsed: number, duration: number): Vector3
	local t = if duration > 1e-4 then math.clamp(elapsed / duration, 0, 1) else 1
	local a = Vector3.new(origin.X, origin.Y, origin.Z)
	local b = Vector3.new(dest.X, dest.Y, dest.Z)
	return a + (b - a) * t
end

function ProjectileLogic.sweepHits(lastPos: Vector3, pos: Vector3, point: Vector3, radius: number): boolean
	return Targeting.distanceToSegment(point, lastPos, pos) <= radius
end

return ProjectileLogic
