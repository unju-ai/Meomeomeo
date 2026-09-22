--!strict

-- Pure projectile travel. Shared by CombatService (hits) and BotService (lead).

local Targeting = require(script.Parent.Targeting)
local VisionLogic = require(script.Parent.VisionLogic)

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

-- Clip a travel step against vision walls / thick cover. Returns (clippedPos, hitWall).
-- Ally and enemy bolts share this path; thin props that fail vision thickness stay open.
function ProjectileLogic.clipAgainstWalls(lastPos: Vector3, pos: Vector3): (Vector3, boolean)
	local t = VisionLogic.wallHitT(lastPos.X, lastPos.Z, pos.X, pos.Z)
	if t == nil then
		return pos, false
	end
	local flat = Targeting.flat(lastPos, pos)
	local mag = flat.Magnitude
	-- Stop just short of the solid so the impact sits on the face, not inside the volume.
	local pad = if mag > 1e-4 then math.min(0.2 / mag, t) else 0
	local clippedT = math.max(t - pad, 0)
	local clipped = Vector3.new(
		lastPos.X + (pos.X - lastPos.X) * clippedT,
		lastPos.Y + (pos.Y - lastPos.Y) * clippedT,
		lastPos.Z + (pos.Z - lastPos.Z) * clippedT
	)
	return clipped, true
end

return ProjectileLogic
