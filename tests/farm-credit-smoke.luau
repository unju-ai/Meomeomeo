-- Creep score rules. Lane kittens and jungle camps count. Bounties do not.

local function purse(gold: number, cs: number)
	return { gold = gold, cs = cs }
end

local lane = purse(500, 0)
FarmCredit.apply(lane, FarmCredit.lastHit(18))
assert(lane.cs == 1)
assert(lane.gold == 518)

local camp = purse(500, 3)
FarmCredit.apply(camp, FarmCredit.lastHit(48))
assert(camp.cs == 4)
assert(camp.gold == 548)
FarmCredit.apply(camp, FarmCredit.lastHit(22))
assert(camp.cs == 5)
assert(camp.gold == 570)

local kill = purse(200, 7)
FarmCredit.apply(kill, FarmCredit.bounty(180))
assert(kill.cs == 7)
assert(kill.gold == 380)

local assist = purse(200, 7)
FarmCredit.apply(assist, FarmCredit.bounty(60))
assert(assist.cs == 7)
assert(assist.gold == 260)

local tower = purse(200, 7)
FarmCredit.apply(tower, FarmCredit.bounty(120))
assert(tower.cs == 7)
assert(tower.gold == 320)

local nearby = purse(200, 4)
FarmCredit.apply(nearby, FarmCredit.none())
assert(nearby.cs == 4)
assert(nearby.gold == 200)

nearby.gold -= 250
assert(nearby.cs == 4)
assert(nearby.gold == -50)

local bot = purse(500, 0)
FarmCredit.apply(bot, FarmCredit.lastHit(18))
FarmCredit.apply(bot, FarmCredit.lastHit(18))
FarmCredit.apply(bot, FarmCredit.bounty(180))
assert(bot.cs == 2)
assert(bot.gold == 716)

local function read(gold: number, owned: boolean)
	return FarmCredit.cleaveRead(gold, owned, 280)
end

local ready = read(500, false)
assert(ready.tone == "ready" and ready.shortfall == 0)
assert(ready.text == "Cleave 280g · can buy")

local exact = read(280, false)
assert(exact.tone == "ready" and exact.shortfall == 0)

local short = read(279, false)
assert(short.tone == "short" and short.shortfall == 1)
assert(short.text == "Cleave 280g · 1g short")

local broke = read(0, false)
assert(broke.tone == "short" and broke.shortfall == 280)

local owned = read(0, true)
assert(owned.tone == "owned" and owned.shortfall == 0)
assert(owned.text == "Cleave owned")

local ownedRich = read(900, true)
assert(ownedRich.tone == "owned")

local kitten = FarmCredit.lastHit(18)
assert(LastHitJuice.wantsFloat(kitten.cs, kitten.gold) == true)
assert(LastHitJuice.goldLabel(kitten.gold) == "+18g")
local campHit = FarmCredit.lastHit(48)
assert(LastHitJuice.wantsFloat(campHit.cs, campHit.gold) == true)
assert(LastHitJuice.goldLabel(campHit.gold) == "+48g")
local killBounty = FarmCredit.bounty(180)
assert(LastHitJuice.wantsFloat(killBounty.cs, killBounty.gold) == false)
local assistBounty = FarmCredit.bounty(60)
assert(LastHitJuice.wantsFloat(assistBounty.cs, assistBounty.gold) == false)
local towerBounty = FarmCredit.bounty(120)
assert(LastHitJuice.wantsFloat(towerBounty.cs, towerBounty.gold) == false)
local noCredit = FarmCredit.none()
assert(LastHitJuice.wantsFloat(noCredit.cs, noCredit.gold) == false)
assert(LastHitJuice.wantsFloat(1, 0) == false)

assert(BountyJuice.wantsFloat(killBounty.cs, killBounty.gold) == true)
assert(BountyJuice.goldLabel(killBounty.gold) == "+180g")
assert(BountyJuice.wantsFloat(assistBounty.cs, assistBounty.gold) == true)
assert(BountyJuice.goldLabel(assistBounty.gold) == "+60g")
assert(BountyJuice.wantsFloat(towerBounty.cs, towerBounty.gold) == true)
assert(BountyJuice.goldLabel(towerBounty.gold) == "+120g")
assert(BountyJuice.wantsFloat(kitten.cs, kitten.gold) == false)
assert(BountyJuice.wantsFloat(campHit.cs, campHit.gold) == false)
assert(BountyJuice.wantsFloat(noCredit.cs, noCredit.gold) == false)
assert(BountyJuice.wantsFloat(1, 18) == false)
assert(not (LastHitJuice.wantsFloat(kitten.cs, kitten.gold) and BountyJuice.wantsFloat(kitten.cs, kitten.gold)))
assert(not (LastHitJuice.wantsFloat(killBounty.cs, killBounty.gold) and BountyJuice.wantsFloat(killBounty.cs, killBounty.gold)))

print("farm credit ok: kitten and camp last hits, bounties skip CS, cleave purse, last-hit float skips bounties, bounty float skips last hits")
