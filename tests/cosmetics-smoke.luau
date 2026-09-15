-- Run through tools/test-cosmetics.py against src/shared/CosmeticCatalog.luau.

assert(#CosmeticCatalog.all() >= 6 and #CosmeticCatalog.all() <= 10, "Catalog should be 6–10 drip items")
assert(#CosmeticCatalog.all() == 10, "This slice ships ten hats/trails")
assert(CosmeticCatalog.StartYarn == 40)
assert(string.find(string.lower(CosmeticCatalog.Disclaimer), "not real", 1, true)
	or string.find(string.lower(CosmeticCatalog.Disclaimer), "not robux", 1, true))
assert(not string.find(string.lower(CosmeticCatalog.Disclaimer), "robux buy", 1, true))

local starters = CosmeticCatalog.starters()
assert(#starters == 2, "Cream Cap + Yarn Puff starters")
local starterSet = {}
for _, id in starters do
	starterSet[id] = true
end
assert(starterSet.CreamCap and starterSet.YarnPuff)

local hats, trails, flair = 0, 0, 0
local seen = {}
for _, row in CosmeticCatalog.all() do
	assert(seen[row.id] == nil, "Duplicate cosmetic id")
	seen[row.id] = true
	assert(CosmeticCatalog.get(row.id) == row)
	assert(row.slot == "hat" or row.slot == "trail")
	assert(row.attach == "head" or row.attach == "neck" or row.attach == "face" or row.attach == "aura")
	if row.slot == "hat" then
		hats += 1
	else
		trails += 1
	end
	if row.emoteFlair then
		flair += 1
	end
end
assert(hats >= 4 and trails >= 3, "Mix of hats and trails")
assert(flair >= 2, "Rare drip should tint emotes")
assert(CosmeticCatalog.get("missing") == nil)
assert(CosmeticCatalog.parseSlot("hat") == "hat")
assert(CosmeticCatalog.parseSlot("trail") == "trail")
assert(CosmeticCatalog.parseSlot("cape") == nil)

local gold = CosmeticCatalog.get("GoldBell")
assert(gold and gold.unlock.kind == "yarn" and CosmeticCatalog.yarnCost(gold) == 25)
assert(CosmeticCatalog.canBuy(gold, 40, false) == true)
assert(CosmeticCatalog.canBuy(gold, 10, false) == false)
assert(CosmeticCatalog.canBuy(gold, 40, true) == false)

local none: CosmeticCatalog.Stats = {
	runMeters = 0,
	koiLegendary = false,
	partyWins = 0,
	arcadeProfit = 0,
}
local run200: CosmeticCatalog.Stats = {
	runMeters = 200,
	koiLegendary = false,
	partyWins = 0,
	arcadeProfit = 0,
}
local run400: CosmeticCatalog.Stats = {
	runMeters = 400,
	koiLegendary = false,
	partyWins = 0,
	arcadeProfit = 0,
}
local koi: CosmeticCatalog.Stats = {
	runMeters = 0,
	koiLegendary = true,
	partyWins = 0,
	arcadeProfit = 0,
}
local party: CosmeticCatalog.Stats = {
	runMeters = 0,
	koiLegendary = false,
	partyWins = 1,
	arcadeProfit = 0,
}
local arcade15: CosmeticCatalog.Stats = {
	runMeters = 0,
	koiLegendary = false,
	partyWins = 0,
	arcadeProfit = 15,
}
local arcade25: CosmeticCatalog.Stats = {
	runMeters = 0,
	koiLegendary = false,
	partyWins = 0,
	arcadeProfit = 25,
}

assert(CosmeticCatalog.meets(CosmeticCatalog.get("CreamCap"), none) == true)
assert(CosmeticCatalog.meets(gold, none) == false, "Yarn shop items are bought, not scored")
assert(CosmeticCatalog.meets(CosmeticCatalog.get("CoralBeanie"), none) == false)
assert(CosmeticCatalog.meets(CosmeticCatalog.get("CoralBeanie"), run200) == true)
assert(CosmeticCatalog.meets(CosmeticCatalog.get("MintAura"), run200) == false)
assert(CosmeticCatalog.meets(CosmeticCatalog.get("MintAura"), run400) == true)
assert(CosmeticCatalog.meets(CosmeticCatalog.get("CanalCrown"), koi) == true)
assert(CosmeticCatalog.meets(CosmeticCatalog.get("PartyTiara"), party) == true)
assert(CosmeticCatalog.meets(CosmeticCatalog.get("MoonDust"), party) == true)
assert(CosmeticCatalog.meets(CosmeticCatalog.get("TapeShades"), arcade15) == true)
assert(CosmeticCatalog.meets(CosmeticCatalog.get("BraincellOrbs"), arcade15) == false)
assert(CosmeticCatalog.meets(CosmeticCatalog.get("BraincellOrbs"), arcade25) == true)

local owned = CosmeticCatalog.ownedList({ "CanalCrown", "bogus" })
assert(#owned == 3)
local set = CosmeticCatalog.ownedSet({ "CanalCrown" })
assert(set.CreamCap and set.YarnPuff and set.CanalCrown and set.bogus == nil)

assert(CosmeticCatalog.emoteTint("CreamCap", "YarnPuff") == nil)
assert(CosmeticCatalog.emoteTint("CanalCrown", nil) ~= nil)
assert(CosmeticCatalog.emoteTint(nil, "BraincellOrbs") ~= nil)
assert(CosmeticCatalog.emoteTint(nil, "MoonDust") ~= nil)

print("PASS: closet catalog, yarn-only shop, score unlocks, starters, emote flair")
