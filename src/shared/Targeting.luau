--!strict

local Types = require(script.Parent.Types)

export type Mode = Types.AbilityTargeting

export type Preview = {
	mode: Mode,
	dest: Vector3,
	clamped: boolean,
	valid: boolean,
	showAim: boolean,
}

local Targeting = {}

-- Ground casts still accept a short slack past max range (CombatService).
local GROUND_SLACK = 6

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

-- Client aim juice: clamped dest, warn tint, and whether an aim part should draw.
function Targeting.preview(ability: Types.AbilityDef, origin: Vector3, aim: Vector3): Preview
	local mode = Targeting.of(ability)
	if mode == "instant" then
		return {
			mode = mode,
			dest = origin,
			clamped = false,
			valid = true,
			showAim = false,
		}
	end
	local flat = Targeting.flat(origin, aim)
	local dist = flat.Magnitude
	if mode == "line" or mode == "dash" then
		local dest = Targeting.clampAim(origin, aim, ability.range)
		return {
			mode = mode,
			dest = dest,
			clamped = dist > ability.range + 0.05,
			valid = true,
			showAim = true,
		}
	end
	-- ground
	local function groundDest(point: Vector3): Vector3
		-- Keep cursor height so the AoE disc sits on the ground hit, not at root height.
		return Vector3.new(point.X, aim.Y, point.Z)
	end
	if dist > ability.range + GROUND_SLACK then
		return {
			mode = mode,
			dest = groundDest(Targeting.clampAim(origin, aim, ability.range)),
			clamped = true,
			valid = false,
			showAim = true,
		}
	end
	local beyondIdeal = dist > ability.range + 0.05
	return {
		mode = mode,
		dest = groundDest(if beyondIdeal then Targeting.clampAim(origin, aim, ability.range) else aim),
		clamped = beyondIdeal,
		valid = true,
		showAim = true,
	}
end

function Targeting.groundSlack(): number
	return GROUND_SLACK
end

return Targeting
