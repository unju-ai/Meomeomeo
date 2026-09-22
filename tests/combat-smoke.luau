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

assert(#ChampionCatalog.ids() == 14)
local flagship = { ChairmanMeow = true, NyanRocket = true, ProfessorWhiskers = true }
for _, id in ChampionCatalog.ids() do
	if not flagship[id] then
		for _, slot in { "Q", "W", "E", "R" } do
			local plan = ChampionKits.plan(id, slot, 5)
			assert(plan.guardSeconds == 0 and plan.channelSeconds == 0 and plan.pullStuds == 0 and plan.zonePulses == 0, id .. " " .. slot)
			assert(ChampionKits.refundMana(id, slot) == 0, id)
			assert(ChampionKits.look(id, slot) == nil, id)
		end
		assert(ChampionKits.onTakedown(id) == nil, id)
	end
end

local chonk = ChampionCatalog.get("ChonkKnight")
assert(chonk and chonk.abilities.R.damage == 180 and chonk.abilities.R.stunSeconds == 0)
assert(chonk.abilities.W.heal == 110)
assert(ChampionKits.plan("ChonkKnight", "W", 0).guardSeconds == 0)
local byte = ChampionCatalog.get("Bytekit")
assert(byte and byte.abilities.Q.damage == 88 and Targeting.of(byte.abilities.Q) == "line")
assert(ChampionKits.plan("Bytekit", "Q", 0).channelSeconds == 0)
local grandma = ChampionCatalog.get("GrandmaFluff")
assert(grandma and grandma.abilities.R.heal == 160)

local meow = ChampionCatalog.get("ChairmanMeow")
assert(meow and meow.abilities.R.damage == 160 and meow.abilities.R.stunSeconds == 0.75)
assert(string.find(meow.blurb, "Golden Parachute", 1, true))
assert(ChampionKits.plan("ChairmanMeow", "R", meow.abilities.R.stunSeconds).pullStuds == 12)
assert(ChampionKits.plan("ChairmanMeow", "R", 0).pullStuds == 0)
local guard = ChampionKits.plan("ChairmanMeow", "W", 0)
assert(guard.guardSeconds == 2.5 and guard.guardReduction == 0.35)
assert(math.abs(ChampionKits.guardMultiplier(0.35, true) - 0.65) < 1e-6)
assert(ChampionKits.guardMultiplier(0.35, false) == 1)
local pulled = ChampionKits.pullPosition(Vector3.new(0, 2, 0), Vector3.new(30, 2, 0), 12)
assert(math.abs(pulled.X - 12) < 0.01 and pulled.Y == 2)
local stayed = ChampionKits.pullPosition(Vector3.new(10, 2, 4), Vector3.new(10, 2, 4), 12)
assert(stayed.X == 10 and stayed.Z == 4)

local nyan = ChampionCatalog.get("NyanRocket")
assert(nyan and nyan.abilities.R.damage == 220 and nyan.abilities.R.cooldown == 50)
assert(Targeting.of(nyan.abilities.R) == "line")
assert(string.find(nyan.blurb, "Encore", 1, true))
local beam = ChampionKits.plan("NyanRocket", "R", 0)
assert(beam.channelSeconds > 0.4 and beam.channelSeconds < 0.8)
assert(beam.interruptCooldown > 0 and beam.interruptCooldown < nyan.abilities.R.cooldown)
assert(beam.interruptMana > 0 and beam.interruptMana < nyan.abilities.R.manaCost)
local resets = ChampionKits.onTakedown("NyanRocket")
assert(resets and #resets == 3 and resets[1] == "Q" and resets[2] == "W" and resets[3] == "E")

local whisk = ChampionCatalog.get("ProfessorWhiskers")
assert(whisk and whisk.abilities.Q.damage == 85 and whisk.abilities.E.damage == 70)
assert(Targeting.of(whisk.abilities.Q) == "line")
assert(Targeting.of(whisk.abilities.E) == "ground")
assert(string.find(whisk.blurb, "Office Hours", 1, true))
assert(ChampionKits.refundMana("ProfessorWhiskers", "Q") == 22)
assert(ChampionKits.refundMana("ProfessorWhiskers", "E") == 0)
assert(ChampionKits.refundMana("ProfessorWhiskers", "W") == 0)
local zone = ChampionKits.plan("ProfessorWhiskers", "E", 0)
assert(zone.zonePulses == 3 and zone.zoneSeconds > zone.zoneTick and zone.zoneTick > 0)
assert(math.abs(ChampionKits.pulsePower(70, zone.zonePulses) * zone.zonePulses - 70) < 1e-6)

assert(ChampionKits.look("ChairmanMeow", "W") == "guard")
assert(ChampionKits.look("ChairmanMeow", "R") == "pull")
assert(ChampionKits.look("NyanRocket", "Q") == "rainbow")
assert(ChampionKits.look("NyanRocket", "R") == "channel")
assert(ChampionKits.look("ProfessorWhiskers", "Q") == "laser")
assert(ChampionKits.look("ProfessorWhiskers", "E") == "zone")
assert(ChampionKits.castPitch("ChairmanMeow", "R") < 1)
assert(ChampionKits.castPitch("NyanRocket", "R") > 1)
assert(ChampionKits.castPitch("Bytekit", "Q") == 1)
assert(ChampionKits.breakPitch("NyanRocket", "R") ~= nil)
assert(ChampionKits.breakPitch("ChairmanMeow", "R") == nil)
assert(#ChampionKits.helpRows() == 3)
local tip = ChampionKits.practiceTip()
assert(string.find(tip, "damage cut", 1, true))
assert(string.find(tip, "pull", 1, true))
assert(string.find(tip, "resets", 1, true))
assert(string.find(tip, "beam", 1, true))
assert(string.find(tip, "mana", 1, true))
assert(string.find(tip, "zone", 1, true))

print("PASS: targeting modes, traveling projectile timing, sweep hits, flagship kit hooks")
