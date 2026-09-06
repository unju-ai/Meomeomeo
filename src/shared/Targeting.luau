--!strict

local Types = require(script.Parent.Types)

export type Mode = Types.AbilityTargeting

local Targeting = {}

function Targeting.of(ability: Types.AbilityDef): Mode
	if ability.targeting then
		return ability.targeting
	end
	if ability.kind == "dash" then
		return "dash"
	end
	if (ability.kind == "heal" or ability.kind == "shield") and ability.range <= 14 then
		return "instant"
	end
	return "ground"
end

function Targeting.flat(origin: Vector3, aim: Vector3): Vector3
	return Vector3.new(aim.X - origin.X, 0, aim.Z - origin.Z)
end

function Targeting.clampAim(origin: Vector3, aim: Vector3, range: number): Vector3
	local flat = Targeting.flat(origin, aim)
	if flat.Magnitude < 1 then
		return origin + Vector3.new(1, 0, 0) * math.min(range, 8)
	end
	return origin + flat.Unit * math.min(flat.Magnitude, range)
end

function Targeting.distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local pa = Vector3.new(point.X, 0, point.Z)
	local aa = Vector3.new(a.X, 0, a.Z)
	local bb = Vector3.new(b.X, 0, b.Z)
	local ab = bb - aa
	local denom = ab:Dot(ab)
	local t = if denom > 1e-4 then math.clamp(ab:Dot(pa - aa) / denom, 0, 1) else 0
	return (pa - (aa + ab * t)).Magnitude
end

function Targeting.hits(mode: Mode, origin: Vector3, aim: Vector3, point: Vector3, radius: number): boolean
	if mode == "line" then
		return Targeting.distanceToSegment(point, origin, aim) <= radius
	end
	local dx = point.X - aim.X
	local dz = point.Z - aim.Z
	return math.sqrt(dx * dx + dz * dz) <= radius
end

return Targeting
