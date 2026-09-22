-- Run through tools/test-koi.py against src/shared/KoiCatalog.luau.

local day = math.floor(1_800_000_000 / 86400) * 86400 + 100
assert(KoiCatalog.dailySeed(day) == KoiCatalog.dailySeed(day + 80000), "Seed must be stable for a UTC day")
assert(KoiCatalog.dailySeed(day) ~= KoiCatalog.dailySeed(day + 86400), "Next UTC day must change the pond")
assert(KoiCatalog.utcDay(day + 10) == KoiCatalog.utcDay(day))
assert(typeof(KoiCatalog.dayKey(day)) == "string")

local ids = {}
local weight = 0
for _, fish in KoiCatalog.all() do
	assert(ids[fish.id] == nil, "Duplicate koi id")
	ids[fish.id] = true
	weight += fish.weight
	assert(fish.score > 0 and fish.sweetHalf > 0)
end
assert(#KoiCatalog.all() == 6, "Six cat-koi rarities")
assert(weight == KoiCatalog.totalWeight())
assert(KoiCatalog.get("CoralCrown") ~= nil and KoiCatalog.get("CoralCrown").ticker == "LEGENDARY KOI")
assert(KoiCatalog.get("missing") == nil)

local common = KoiCatalog.pick(0)
assert(common.id == "CreamLoaf", "Low rolls are cream loafs")
local legend = KoiCatalog.pick(0.999)
assert(legend.id == "CoralCrown", "High rolls are coral crowns")
assert(KoiCatalog.inWindow(0.5, common) == true)
assert(KoiCatalog.inWindow(0.5, legend) == true)
assert(KoiCatalog.inWindow(0.9, legend) == false, "Legendary cream window is tight")
assert(KoiCatalog.inWindow(0.9, common) == false)
assert(KoiCatalog.parseRarity("Legendary") == "Legendary")
assert(KoiCatalog.parseRarity("nope") == "Common")
assert(KoiCatalog.rarityTag("Legendary") == "CROWN")
assert(KoiCatalog.rarityTag("Common") == "CREAM")
assert(KoiCatalog.catchTint("Mint Whisker", "Rare").g > KoiCatalog.catchTint("Cobalt Braincell", "Rare").g, "Mint is greener than cobalt")
assert(KoiCatalog.catchTint("Coral Crown", "Legendary").r == 255)
assert(KoiCatalog.catchTint(nil, "Epic").r == 255 and KoiCatalog.catchTint(nil, "Epic").g == 196)

local rows = KoiCatalog.logRows({ CreamLoaf = 3, CoralCrown = 1, PeachKoi = 0 })
assert(#rows == 2)
assert(rows[1].id == "CreamLoaf" and rows[1].count == 3)
assert(rows[2].id == "CoralCrown")

print("PASS: koi catalog rarities, windows, daily seed, stall log, catch tints")
