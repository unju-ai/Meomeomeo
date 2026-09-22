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
local kitted = {
	ChairmanMeow = true,
	NyanRocket = true,
	ProfessorWhiskers = true,
	ChonkKnight = true,
	ScammyMcMittens = true,
	GrandmaFluff = true,
}
local expansion = 0
for _, id in ChampionCatalog.ids() do
	if not kitted[id] then
		expansion += 1
		assert(ChampionKits.identity(id) == nil, id)
		assert(ChampionKits.healMultiplier(id) == 1, id)
		assert(ChampionKits.onTakedown(id) == nil, id)
		for _, slot in { "Q", "W", "E", "R" } do
			local plan = ChampionKits.plan(id, slot, 5)
			assert(plan.guardSeconds == 0 and plan.channelSeconds == 0 and plan.pullStuds == 0 and plan.zonePulses == 0, id .. " " .. slot)
			assert(plan.knockStuds == 0 and plan.knockStun == 0, id .. " " .. slot)
			assert(plan.wickGain == 0 and plan.wickBonus == 0 and plan.wickCap == 0, id .. " " .. slot)
			assert(plan.auraGuardSeconds == 0 and plan.auraGuardReduction == 0, id .. " " .. slot)
			assert(ChampionKits.refundMana(id, slot) == 0, id)
			assert(ChampionKits.look(id, slot) == nil, id)
		end
	end
end
assert(expansion == 8, "eight expansion cats stay on the zero plan")

local byte = ChampionCatalog.get("Bytekit")
assert(byte and byte.abilities.Q.damage == 88 and Targeting.of(byte.abilities.Q) == "line")
assert(ChampionKits.plan("Bytekit", "Q", 0).channelSeconds == 0)
assert(ChampionKits.identity("Bytekit") == nil)

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
assert(ChampionKits.plan("ChairmanMeow", "W", 0).knockStuds == 0)
assert(ChampionKits.plan("ChairmanMeow", "R", 0.75).wickGain == 0)
assert(ChampionKits.healMultiplier("ChairmanMeow") == 1)
assert(ChampionKits.healMultiplier("NyanRocket") == 1)
assert(ChampionKits.healMultiplier("ProfessorWhiskers") == 1)
assert(ChampionKits.identity("ChairmanMeow") == nil)
assert(ChampionKits.identity("NyanRocket") == nil)
assert(ChampionKits.identity("ProfessorWhiskers") == nil)
assert(ChampionKits.castPitch("ChairmanMeow", "R") < 1)
assert(ChampionKits.castPitch("NyanRocket", "R") > 1)
assert(ChampionKits.castPitch("Bytekit", "Q") == 1)
assert(ChampionKits.breakPitch("NyanRocket", "R") ~= nil)
assert(ChampionKits.breakPitch("ChairmanMeow", "R") == nil)

local chonk = ChampionCatalog.get("ChonkKnight")
assert(chonk and chonk.abilities.R.damage == 180 and chonk.abilities.R.stunSeconds == 0)
assert(chonk.abilities.Q.damage == 65 and chonk.abilities.E.damage == 90)
assert(chonk.abilities.W.heal == 110)
assert(string.find(chonk.blurb, "Settled Loaf", 1, true))
assert(string.find(chonk.blurb, "Charge Knock", 1, true))
local chonkId = ChampionKits.identity("ChonkKnight")
assert(chonkId and chonkId.passive == "Settled Loaf" and chonkId.signature == "Charge Knock")
local loaf = ChampionKits.plan("ChonkKnight", "E", 0)
assert(loaf.guardSeconds == 2.2 and loaf.guardReduction == 0.3)
assert(loaf.knockStuds == 0 and loaf.guardSeconds ~= 2.5)
local knock = ChampionKits.plan("ChonkKnight", "Q", 0)
assert(knock.knockStuds == 10 and knock.knockStun == 0.45)
assert(knock.guardSeconds == 0)
assert(ChampionKits.plan("ChonkKnight", "W", 0).guardSeconds == 0)
assert(ChampionKits.plan("ChonkKnight", "R", 0).knockStuds == 0)
local bowled = ChampionKits.knockPosition(Vector3.new(4, 2, 1), Vector3.new(0, 2, 0), Vector3.new(32, 2, 0), 10)
assert(math.abs(bowled.X - 14) < 0.01 and bowled.Y == 2 and bowled.Z == 1)
local unmoved = ChampionKits.knockPosition(Vector3.new(4, 2, 1), Vector3.new(3, 2, 1), Vector3.new(3.2, 2, 1), 10)
assert(unmoved.X == 4 and unmoved.Z == 1)
assert(ChampionKits.look("ChonkKnight", "Q") == "knock")
assert(ChampionKits.look("ChonkKnight", "E") == "guard")
assert(ChampionKits.look("ChonkKnight", "W") == nil)
assert(ChampionKits.castPitch("ChonkKnight", "Q") < 1)

local scammy = ChampionCatalog.get("ScammyMcMittens")
assert(scammy and scammy.abilities.Q.damage == 75 and scammy.abilities.E.damage == 80)
assert(string.find(scammy.blurb, "Open Wick", 1, true))
assert(string.find(scammy.blurb, "Hype Candle", 1, true))
local scammyId = ChampionKits.identity("ScammyMcMittens")
assert(scammyId and scammyId.passive == "Open Wick" and scammyId.signature == "Hype Candle")
local wick = ChampionKits.plan("ScammyMcMittens", "Q", 0)
assert(wick.wickGain == 1 and wick.wickCap == 3 and wick.wickSeconds == 8 and wick.wickBonus == 0)
local candle = ChampionKits.plan("ScammyMcMittens", "E", 0)
assert(candle.wickBonus == 0.4 and candle.wickGain == 0)
assert(ChampionKits.plan("ScammyMcMittens", "W", 0).wickGain == 0)
assert(ChampionKits.plan("ScammyMcMittens", "R", 0).wickBonus == 0)
assert(ChampionKits.addWick(0, 3) == 1)
assert(ChampionKits.addWick(2, 3) == 3)
assert(ChampionKits.addWick(3, 3) == 3)
assert(ChampionKits.wickPower(0, 0.4) == 1)
assert(math.abs(ChampionKits.wickPower(1, 0.4) - 1.4) < 1e-6)
assert(math.abs(ChampionKits.wickPower(3, 0.4) - 2.2) < 1e-6)
assert(ChampionKits.wickPower(3, 0.4) > ChampionKits.wickPower(1, 0.4))
assert(ChampionKits.look("ScammyMcMittens", "Q") == "wick")
assert(ChampionKits.look("ScammyMcMittens", "E") == "candle")
assert(ChampionKits.look("ScammyMcMittens", "R") == nil)
assert(ChampionKits.castPitch("ScammyMcMittens", "Q") > 1)

local grandma = ChampionCatalog.get("GrandmaFluff")
assert(grandma and grandma.abilities.R.heal == 160 and grandma.abilities.Q.heal == 85 and grandma.abilities.W.heal == 120)
assert(string.find(grandma.blurb, "Second Helping", 1, true))
assert(string.find(grandma.blurb, "Sweater Aura", 1, true))
local grandmaId = ChampionKits.identity("GrandmaFluff")
assert(grandmaId and grandmaId.passive == "Second Helping" and grandmaId.signature == "Sweater Aura")
assert(math.abs(ChampionKits.healMultiplier("GrandmaFluff") - 1.22) < 1e-6)
assert(ChampionKits.healMultiplier("GrandmaFluff") > 1)
local sweater = ChampionKits.plan("GrandmaFluff", "W", 0)
assert(sweater.auraGuardSeconds == 2.4 and sweater.auraGuardReduction == 0.22)
assert(sweater.guardSeconds == 0 and sweater.auraGuardReduction < 0.35)
assert(ChampionKits.plan("GrandmaFluff", "Q", 0).auraGuardSeconds == 0)
assert(ChampionKits.plan("GrandmaFluff", "E", 0).auraGuardSeconds == 0)
assert(ChampionKits.plan("GrandmaFluff", "R", 0).auraGuardSeconds == 0)
assert(ChampionKits.preferGuard(0.35, true, 0.22) == false)
assert(ChampionKits.preferGuard(0.22, true, 0.22) == true)
assert(ChampionKits.preferGuard(0.22, false, 0.22) == true)
assert(ChampionKits.preferGuard(0, false, 0) == false)
assert(ChampionKits.look("GrandmaFluff", "W") == "sweater")
assert(ChampionKits.look("GrandmaFluff", "Q") == nil)
assert(ChampionKits.castPitch("GrandmaFluff", "W") < 1)

assert(#ChampionKits.helpRows() == 6)
local help = ""
for _, row in ChampionKits.helpRows() do
	help ..= row[1] .. " " .. row[2] .. "\n"
end
assert(string.find(help, "Chonk", 1, true) and string.find(help, "loaf", 1, true) and string.find(help, "knock", 1, true))
assert(string.find(help, "Scammy", 1, true) and string.find(help, "wick", 1, true) and string.find(help, "candle", 1, true))
assert(string.find(help, "Grandma", 1, true) and string.find(help, "amp", 1, true) and string.find(help, "aura", 1, true))
local tip = ChampionKits.practiceTip()
assert(string.find(tip, "damage cut", 1, true))
assert(string.find(tip, "pull", 1, true))
assert(string.find(tip, "resets", 1, true))
assert(string.find(tip, "beam", 1, true))
assert(string.find(tip, "mana", 1, true))
assert(string.find(tip, "zone", 1, true))
local more = ChampionKits.practiceTipMore()
assert(string.find(more, "Settled Loaf", 1, true))
assert(string.find(more, "Charge Knock", 1, true))
assert(string.find(more, "Open Wick", 1, true))
assert(string.find(more, "Hype Candle", 1, true))
assert(string.find(more, "Second Helping", 1, true))
assert(string.find(more, "Sweater Aura", 1, true))

print("PASS: targeting modes, traveling projectile timing, sweep hits, flagship kit hooks, Settled Loaf, Charge Knock, Open Wick, Hype Candle, Second Helping, Sweater Aura")
