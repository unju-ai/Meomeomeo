-- Run through tools/test-cosmetics.py against src/shared/CosmeticCatalog.luau.

assert(#CosmeticCatalog.all() >= 12 and #CosmeticCatalog.all() <= 14, "Catalog stays a small night-market closet")
assert(#CosmeticCatalog.all() == 13, "Ten stall pieces plus three Cat Rift unlocks")
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

local function stats(patch: { [string]: any }): CosmeticCatalog.Stats
	local row: CosmeticCatalog.Stats = {
		runMeters = 0,
		koiLegendary = false,
		partyWins = 0,
		arcadeProfit = 0,
		riftWins = 0,
		riftTowerKills = 0,
		riftKills = 0,
	}
	for key, value in patch do
		(row :: any)[key] = value
	end
	return row
end

local none = stats({})
local run200 = stats({ runMeters = 200 })
local run400 = stats({ runMeters = 400 })
local koi = stats({ koiLegendary = true })
local party = stats({ partyWins = 1 })
local arcade15 = stats({ arcadeProfit = 15 })
local arcade25 = stats({ arcadeProfit = 25 })
local riftPost = stats({ riftTowerKills = 1 })
local riftWin = stats({ riftWins = 1 })
local riftKills4 = stats({ riftKills = 4 })
local riftKills5 = stats({ riftKills = 5 })
local riftPile = stats({ riftWins = 3, riftTowerKills = 4, riftKills = 9 })

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

local lantern = CosmeticCatalog.get("LanternCap")
local tally = CosmeticCatalog.get("ScratchTally")
local spark = CosmeticCatalog.get("StallSpark")
assert(lantern and lantern.slot == "hat" and lantern.unlock.kind == "riftTowerKills")
assert(tally and tally.slot == "hat" and tally.unlock.kind == "riftKills" and tally.unlock.amount == 5)
assert(spark and spark.slot == "trail" and spark.unlock.kind == "riftWin" and spark.emoteFlair)
assert(CosmeticCatalog.yarnCost(lantern) == 0 and CosmeticCatalog.canBuy(lantern, 40, false) == false)
assert(CosmeticCatalog.yarnCost(spark) == 0)
assert(CosmeticCatalog.meets(lantern, none) == false)
assert(CosmeticCatalog.meets(lantern, riftPost) == true)
assert(CosmeticCatalog.meets(lantern, riftWin) == false)
assert(CosmeticCatalog.meets(spark, none) == false)
assert(CosmeticCatalog.meets(spark, riftWin) == true)
assert(CosmeticCatalog.meets(spark, riftPost) == false)
assert(CosmeticCatalog.meets(tally, riftKills4) == false)
assert(CosmeticCatalog.meets(tally, riftKills5) == true)
assert(CosmeticCatalog.meets(CosmeticCatalog.get("PartyTiara"), riftPile) == false, "Rift stats do not grant party drip")
assert(CosmeticCatalog.meets(CosmeticCatalog.get("CoralBeanie"), riftPile) == false)
assert(CosmeticCatalog.meets(CosmeticCatalog.get("TapeShades"), riftPile) == false)
assert(CosmeticCatalog.meets(lantern, riftPile) == true)
assert(CosmeticCatalog.meets(spark, riftPile) == true)
assert(CosmeticCatalog.meets(tally, riftPile) == true)
assert(CosmeticCatalog.RiftWinYarn > CosmeticCatalog.RiftLossYarn)
assert(CosmeticCatalog.RiftLossYarn > 0)
assert(CosmeticCatalog.RiftWinYarn <= 12, "Match yarn stays a tip, not a shop grind")
assert(CosmeticCatalog.riftYarn(true) == CosmeticCatalog.RiftWinYarn)
assert(CosmeticCatalog.riftYarn(false) == CosmeticCatalog.RiftLossYarn)

local owned = CosmeticCatalog.ownedList({ "CanalCrown", "bogus" })
assert(#owned == 3)
local set = CosmeticCatalog.ownedSet({ "CanalCrown" })
assert(set.CreamCap and set.YarnPuff and set.CanalCrown and set.bogus == nil)

assert(CosmeticCatalog.emoteTint("CreamCap", "YarnPuff") == nil)
assert(CosmeticCatalog.emoteTint("", "") == nil)
assert(CosmeticCatalog.emoteTint("CanalCrown", nil) ~= nil)
assert(CosmeticCatalog.emoteTint(nil, "BraincellOrbs") ~= nil)
assert(CosmeticCatalog.emoteTint(nil, "MoonDust") ~= nil)
assert(CosmeticCatalog.emoteTint(nil, "StallSpark") ~= nil)
assert(CosmeticCatalog.emoteTint("LanternCap", nil) == nil)
assert(CosmeticCatalog.emoteTint("ScratchTally", "YarnPuff") == nil)
local moon = CosmeticCatalog.emoteTint("CanalCrown", "MoonDust")
local lone = CosmeticCatalog.emoteTint(nil, "MoonDust")
assert(moon and lone and moon.r == lone.r and moon.g == lone.g and moon.b == lone.b, "Trail flair beats hat flair")

-- Closet wardrobe juice helpers (chips + ticker tints). Unlock thresholds unchanged.
assert(CosmeticCatalog.rarityTag("Common") == "CMN")
assert(CosmeticCatalog.rarityTag("Uncommon") == "UNC")
assert(CosmeticCatalog.rarityTag("Rare") == "RARE")
assert(CosmeticCatalog.rarityTag("Epic") == "EPIC")
assert(CosmeticCatalog.unlockSource("free") == "STARTER")
assert(CosmeticCatalog.unlockSource("yarn") == "YARN")
assert(CosmeticCatalog.unlockSource("runMeters") == "RUN")
assert(CosmeticCatalog.unlockSource("koiLegendary") == "KOI")
assert(CosmeticCatalog.unlockSource("partyWin") == "PARTY")
assert(CosmeticCatalog.unlockSource("arcadeProfit") == "ARCADE")
assert(CosmeticCatalog.unlockSource("riftWin") == "RIFT")
assert(CosmeticCatalog.unlockSource("riftTowerKills") == "RIFT")
assert(CosmeticCatalog.unlockSource("riftKills") == "RIFT")
assert(CosmeticCatalog.unlockSourceLabel("runMeters") == "Yarn Run")
assert(CosmeticCatalog.unlockSourceLabel("koiLegendary") == "Koi Pond")
assert(CosmeticCatalog.unlockSourceLabel("partyWin") == "Yarn Party")
assert(CosmeticCatalog.unlockSourceLabel("arcadeProfit") == "Meme Arcade")
assert(CosmeticCatalog.unlockSourceLabel("riftWin") == "Cat Rift")
assert(CosmeticCatalog.unlockSourceLabel("yarn") == "Closet yarn")
assert(CosmeticCatalog.unlockSourceLabel("free") == "Starter")
local runTint = CosmeticCatalog.unlockSourceTint("runMeters")
local riftTint = CosmeticCatalog.unlockSourceTint("riftWin")
assert(runTint and riftTint and (runTint.r ~= riftTint.r or runTint.g ~= riftTint.g or runTint.b ~= riftTint.b))
assert(CosmeticCatalog.isUnlockToast("UNLOCKED · Lantern Cap") == true)
assert(CosmeticCatalog.isEquipToast("EQUIPPED · Cream Cap") == true)
assert(CosmeticCatalog.isBuyToast("BOUGHT · Gold Bell") == true)
assert(CosmeticCatalog.isUnlockToast("Unequipped") == false)
assert(CosmeticCatalog.isEquipToast(nil) == false)
local unlockTint = CosmeticCatalog.toastTint("UNLOCKED · Stall Spark")
local equipTint = CosmeticCatalog.toastTint("EQUIPPED · Moon Dust")
local buyTint = CosmeticCatalog.toastTint("BOUGHT · Gold Bell")
assert(unlockTint and equipTint and buyTint)
assert(unlockTint.r == 255 and unlockTint.g == 196 and unlockTint.b == 74, "Unlock toast stays amber")
assert(equipTint.r == 120 and equipTint.g == 196 and equipTint.b == 150, "Equip toast stays mint")
assert(buyTint.r == 255 and buyTint.g == 184 and buyTint.b == 140, "Buy toast stays peach")
-- Gate amounts must stay put (wardrobe juice only).
assert(CosmeticCatalog.get("CoralBeanie").unlock.amount == 200)
assert(CosmeticCatalog.get("MintAura").unlock.amount == 400)
assert(CosmeticCatalog.get("TapeShades").unlock.amount == 15)
assert(CosmeticCatalog.get("BraincellOrbs").unlock.amount == 25)
assert(CosmeticCatalog.get("ScratchTally").unlock.amount == 5)
assert(CosmeticCatalog.yarnCost(CosmeticCatalog.get("GoldBell")) == 25)
assert(CosmeticCatalog.StartYarn == 40)
assert(CosmeticCatalog.RiftWinYarn == 6 and CosmeticCatalog.RiftLossYarn == 2)

print("PASS: closet catalog, yarn-only shop, score unlocks, Cat Rift drip, starters, emote flair, wardrobe juice chips")
