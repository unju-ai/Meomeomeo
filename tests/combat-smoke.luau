-- Run through tools/test-combat.py against Targeting + ProjectileLogic.

assert(Targeting.of({
	slot = "Q",
	name = "Laser",
	description = "",
	kind = "damage",
	cooldown = 4,
	manaCost = 30,
	range = 42,
	radius = 8,
	damage = 80,
	heal = 0,
	shield = 0,
	stunSeconds = 0,
	targeting = "line",
}) == "line")

assert(Targeting.of({
	slot = "Q",
	name = "Slam",
	description = "",
	kind = "damage",
	cooldown = 5,
	manaCost = 40,
	range = 28,
	radius = 14,
	damage = 70,
	heal = 0,
	shield = 0,
	stunSeconds = 0,
}) == "ground")

assert(Targeting.of({
	slot = "W",
	name = "Dash",
	description = "",
	kind = "dash",
	cooldown = 8,
	manaCost = 35,
	range = 36,
	radius = 8,
	damage = 40,
	heal = 0,
	shield = 0,
	stunSeconds = 0,
}) == "dash")

local origin = Vector3.new(0, 2, 0)
local dest = Vector3.new(36, 2, 0)
assert(Targeting.hits("line", origin, dest, Vector3.new(18, 2, 4), 8) == true)
assert(Targeting.hits("line", origin, dest, Vector3.new(18, 2, 20), 8) == false)
assert(Targeting.hits("ground", origin, dest, dest, 10) == true)

assert(ProjectileLogic.Speed == 72)
local seconds = ProjectileLogic.travelSeconds(origin, dest, ProjectileLogic.Speed)
assert(seconds > 0.4 and seconds < 0.6, "42-stud line at 72 studs/s is ~0.5s")
assert(ProjectileLogic.positionAt(origin, dest, 0, seconds).X == 0)
local mid = ProjectileLogic.positionAt(origin, dest, seconds / 2, seconds)
assert(mid.X > 16 and mid.X < 20)
local endPos = ProjectileLogic.positionAt(origin, dest, seconds, seconds)
assert(math.abs(endPos.X - 36) < 0.01)

local last = Vector3.new(0, 2, 0)
local now = Vector3.new(8, 2, 0)
assert(ProjectileLogic.sweepHits(last, now, Vector3.new(4, 2, 3), 8) == true)
assert(ProjectileLogic.sweepHits(last, now, Vector3.new(4, 2, 24), 8) == false)
assert(ProjectileLogic.MaxLive >= 16)

print("PASS: targeting modes, traveling projectile timing, sweep hits")
