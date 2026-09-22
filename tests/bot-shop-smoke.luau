-- Run through tools/test-bot-shop.py against BotShopLogic + ItemCatalog + ChampionCatalog.
-- Practice starts at 500 gold. Plans must fit that purse without skipping ahead.

local START = 500

local function cost(id: string): number
	local def = ItemCatalog.get(id)
	assert(def, id)
	return def.cost
end

local function contains(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

local function buyAll(difficulty: BotShopLogic.Difficulty, role: string, gold: number, owned: { string }): ({ string }, number)
	local purse = gold
	local bag = table.clone(owned)
	local bought = {}
	for _ = 1, BotShopLogic.MaxBuysPerVisit do
		local id = BotShopLogic.nextItem(difficulty, role, purse, bag)
		if not id then
			break
		end
		local price = cost(id)
		assert(purse >= price, `{difficulty} {role} bought {id} broke`)
		purse -= price
		table.insert(bag, id)
		table.insert(bought, id)
	end
	assert(purse >= 0)
	return bought, purse
end

assert(BotShopLogic.lineFor("Tank") == "tank")
assert(BotShopLogic.lineFor("Bruiser") == "tank")
assert(BotShopLogic.lineFor("Assassin") == "assassin")
assert(BotShopLogic.lineFor("Marksman") == "assassin")
assert(BotShopLogic.lineFor("Mage") == "mage")
assert(BotShopLogic.lineFor("Support") == "mage")
assert(BotShopLogic.lineFor("Mystery") == "mage")

local pool = {
	ChonkKnight = "tank",
	SirScratchalot = "tank",
	Chromeclaw = "tank",
	NyanRocket = "assassin",
	Shadowpounce = "assassin",
	Bytekit = "mage",
}
for id, line in pool do
	local champ = ChampionCatalog.get(id)
	assert(champ, id)
	assert(BotShopLogic.lineFor(champ.role) == line, `{id} {champ.role}`)
end

for _, difficulty in { "Easy", "Normal", "Hard" } do
	for _, role in { "Tank", "Assassin", "Mage", "Bruiser", "Marksman", "Support" } do
		local plan = BotShopLogic.plan(difficulty :: BotShopLogic.Difficulty, role)
		local yarnAt = table.find(plan, "ControlYarn")
		if difficulty == "Hard" then
			local cleaveAt = table.find(plan, "YarnCleave")
			local lensAt = table.find(plan, "WhiskerLens")
			assert(yarnAt ~= nil and cleaveAt ~= nil and lensAt ~= nil, `{role} Hard plan`)
			assert(yarnAt > cleaveAt and yarnAt < lensAt, `{role} Control Yarn sits after Cleave and before Lens`)
		else
			assert(yarnAt == nil, `{difficulty} {role} must not buy Control Yarn`)
		end
		assert(#plan <= BotShopLogic.MaxBuysPerVisit)
	end
	assert(BotShopLogic.shouldShop(difficulty :: BotShopLogic.Difficulty, false, true) == false)
end

assert(#BotShopLogic.plan("Easy", "Tank") == 1)
assert(BotShopLogic.plan("Easy", "Assassin")[1] == "ManaTreat")
assert(BotShopLogic.shouldShop("Easy", true, false) == false)
assert(BotShopLogic.shouldShop("Easy", true, true) == true)
local easyOpen = buyAll("Easy", "Mage", START, {})
assert(#easyOpen == 1 and easyOpen[1] == "ManaTreat")
assert(BotShopLogic.nextItem("Easy", "Tank", 5000, { "ManaTreat" }) == nil)
assert(BotShopLogic.nextItem("Easy", "Assassin", 100, {}) == nil)

assert(BotShopLogic.shouldShop("Normal", true, false) == false)
assert(BotShopLogic.shouldShop("Normal", true, true) == true)
local normalTank, normalTankGold = buyAll("Normal", "Bruiser", START, {})
assert(normalTank[1] == "Yarnplate" and normalTank[2] == "PounceBoots" and #normalTank == 2)
assert(normalTankGold == START - cost("Yarnplate") - cost("PounceBoots"))
assert(BotShopLogic.nextItem("Normal", "Bruiser", 5000, normalTank) == nil)
local normalAssassin = buyAll("Normal", "Assassin", START, {})
assert(normalAssassin[1] == "Longclaw" and normalAssassin[2] == "PounceBoots")
assert(not contains(normalAssassin, "StallFang"))
assert(not contains(normalAssassin, "YarnCleave"))
local normalMage = buyAll("Normal", "Mage", START, {})
assert(normalMage[1] == "ManaTreat" and normalMage[2] == "Longclaw" and #normalMage == 2)

assert(BotShopLogic.shouldShop("Hard", true, false) == true)
local hardTank, hardTankGold = buyAll("Hard", "Tank", START, {})
assert(hardTank[1] == "Yarnplate" and hardTank[2] == "PaperCharm" and #hardTank == 2)
assert(hardTankGold == START - 250 - 220)
assert(BotShopLogic.nextItem("Hard", "Tank", hardTankGold, hardTank) == nil)
assert(BotShopLogic.nextItem("Hard", "Bruiser", cost("YarnCleave"), hardTank) == "YarnCleave")
local afterCleave = { "Yarnplate", "PaperCharm", "YarnCleave" }
assert(BotShopLogic.nextItem("Hard", "Tank", cost("ControlYarn") - 1, afterCleave) == nil)
assert(BotShopLogic.nextItem("Hard", "Tank", cost("WhiskerLens"), afterCleave) == "ControlYarn")
local oneYarn = { "Yarnplate", "PaperCharm", "YarnCleave", "ControlYarn" }
assert(BotShopLogic.nextItem("Hard", "Tank", cost("ControlYarn") - 1, oneYarn) == nil)
assert(BotShopLogic.nextItem("Hard", "Tank", cost("WhiskerLens"), oneYarn) == "ControlYarn")
local twoYarn = { "Yarnplate", "PaperCharm", "YarnCleave", "ControlYarn", "ControlYarn" }
assert(BotShopLogic.nextItem("Hard", "Tank", cost("WhiskerLens") - 1, twoYarn) == nil)
assert(BotShopLogic.nextItem("Hard", "Tank", cost("WhiskerLens"), twoYarn) == "WhiskerLens")
assert(BotShopLogic.nextItem("Hard", "Tank", 99999, twoYarn) == "WhiskerLens")
assert(BotShopLogic.nextItem("Hard", "Tank", 99999, { "Yarnplate", "PaperCharm", "YarnCleave", "ControlYarn", "ControlYarn", "WhiskerLens" }) == nil)
assert(BotShopLogic.nextItem("Hard", "Tank", cost("PaperCharm") - 1, { "Yarnplate" }) == nil)
local richTank = buyAll("Hard", "Tank", 5000, {})
assert(richTank[1] == "Yarnplate" and richTank[2] == "PaperCharm" and richTank[3] == "YarnCleave")
assert(richTank[4] == "ControlYarn" and richTank[5] == "ControlYarn" and richTank[6] == "WhiskerLens")
assert(#richTank == 6)

local hardAssassin, hardAssassinGold = buyAll("Hard", "Assassin", START, {})
assert(hardAssassin[1] == "Longclaw" and hardAssassin[2] == "PounceBoots" and #hardAssassin == 2)
assert(hardAssassinGold == START - 250 - 200)
assert(not contains(hardAssassin, "StallFang"))
assert(BotShopLogic.nextItem("Hard", "Marksman", cost("StallFang"), hardAssassin) == "StallFang")
assert(BotShopLogic.nextItem("Hard", "Assassin", cost("StallFang") - 1, hardAssassin) == nil)
assert(BotShopLogic.nextItem("Hard", "Assassin", cost("ControlYarn") + cost("WhiskerLens"), hardAssassin) == nil)
local afterFang = { "Longclaw", "PounceBoots", "StallFang" }
assert(BotShopLogic.nextItem("Hard", "Assassin", cost("YarnCleave"), afterFang) == "YarnCleave")

local hardMage, hardMageGold = buyAll("Hard", "Mage", START, {})
assert(hardMage[1] == "ManaTreat" and hardMage[2] == "Longclaw" and #hardMage == 2)
assert(hardMageGold == START - 200 - 250)
assert(BotShopLogic.nextItem("Hard", "Support", cost("YarnCleave"), hardMage) == "YarnCleave")
assert(BotShopLogic.nextItem("Hard", "Mage", cost("YarnCleave") - 1, hardMage) == nil)
local afterMageCleave = { "ManaTreat", "Longclaw", "YarnCleave" }
assert(BotShopLogic.nextItem("Hard", "Mage", cost("ControlYarn"), afterMageCleave) == "ControlYarn")
assert(BotShopLogic.nextItem("Hard", "Support", cost("ControlYarn") - 1, afterMageCleave) == nil)
local richAssassin = buyAll("Hard", "Assassin", 5000, {})
assert(richAssassin[3] == "StallFang" and richAssassin[4] == "YarnCleave")
assert(richAssassin[5] == "ControlYarn" and richAssassin[6] == "ControlYarn" and richAssassin[7] == "WhiskerLens")
assert(#richAssassin == 7)

assert(cost("YarnCleave") == 280)
assert(cost("StallFang") == 300)
assert(cost("PaperCharm") == 220)
assert(cost("WhiskerLens") == 180)
assert(cost("ManaTreat") == 200)
assert(cost("ControlYarn") == 75)
assert(ItemCatalog.maxStack("ControlYarn") == 2)

assert(BotShopLogic.shouldCleave(2, true, true) == true)
assert(BotShopLogic.shouldCleave(3, true, true) == true)
assert(BotShopLogic.shouldCleave(1, true, true) == false)
assert(BotShopLogic.shouldCleave(2, false, true) == false)
assert(BotShopLogic.shouldCleave(2, true, false) == false)
assert(BotShopLogic.shouldCleave(0, true, true) == false)

assert(BotShopLogic.shouldLens(true, true, true) == true)
assert(BotShopLogic.shouldLens(false, true, true) == false)
assert(BotShopLogic.shouldLens(true, false, true) == false)
assert(BotShopLogic.shouldLens(true, true, false) == false)

assert(BotShopLogic.chargeReady(false, 0, 10) == true)
assert(BotShopLogic.chargeReady(true, 0, 10) == false)
assert(BotShopLogic.chargeReady(false, 12, 10) == false)
assert(BotShopLogic.chargeReady(false, 10, 10) == true)
assert(BotShopLogic.releaseWardLatch(true, false, false) == true)
assert(BotShopLogic.releaseWardLatch(true, true, false) == false)
assert(BotShopLogic.releaseWardLatch(true, false, true) == false)
assert(BotShopLogic.releaseWardLatch(false, false, false) == false)

assert(BotShopLogic.shouldPlaceControl("Hard", true, true, true) == true)
assert(BotShopLogic.shouldPlaceControl("Easy", true, true, true) == false)
assert(BotShopLogic.shouldPlaceControl("Normal", true, true, true) == false)
assert(BotShopLogic.shouldPlaceControl("Hard", false, true, true) == false)
assert(BotShopLogic.shouldPlaceControl("Hard", true, false, true) == false)
assert(BotShopLogic.shouldPlaceControl("Hard", true, true, false) == false)

local PLACE = 28
local spots = BotShopLogic.visionSpots()
local none: { BotShopLogic.Post } = {}

local function plant(x: number, z: number, posts: { BotShopLogic.Post }?): (number?, number?, string?)
	return BotShopLogic.controlDestination(x, z, PLACE, spots, posts or none)
end

local brushX, brushZ, brushKind = plant(-22, -48)
assert(brushX == -22 and brushZ == -48 and brushKind == "river-brush")

local crabX, crabZ, crabKind = plant(0, -48)
assert(crabX == -22 and crabZ == -48 and crabKind == "river-brush")

local canalX, canalZ, canalKind = plant(0, 24)
assert(canalX == 0 and canalZ == 24 and canalKind == "canal")

local midX, midZ, midKind = plant(0, 0)
assert(midX == 0 and midZ == 24 and midKind == "canal")

local homeX, homeZ, homeKind = plant(176, 0)
assert(homeX == nil and homeZ == nil and homeKind == nil)

local diveX = plant(70, 0, { { x = 90, z = 0, range = 44 } })
assert(diveX == nil)

local onlyCanal = { { x = 0, z = 24, kind = "canal" :: BotShopLogic.SpotKind } }
local blockedCanal = BotShopLogic.controlDestination(0, 0, PLACE, onlyCanal, { { x = 0, z = 24, range = 10 } })
assert(blockedCanal == nil)

local aroundX, aroundZ, aroundKind = plant(0, 0, { { x = 0, z = 24, range = 10 } })
assert(aroundKind == "river-brush")
assert(aroundX ~= nil and aroundZ ~= nil)
assert(not (aroundX == 0 and aroundZ == 24))

local stepX, stepZ, stepKind = plant(10, -80)
assert(stepKind == "river-brush")
assert(stepX ~= nil and stepZ ~= nil)
local stepDist = math.sqrt((stepX :: number - 10) ^ 2 + (stepZ :: number - (-80)) ^ 2)
assert(math.abs(stepDist - PLACE) < 0.001)
local brushDist = math.sqrt((stepX :: number - (-22)) ^ 2 + (stepZ :: number - (-48)) ^ 2)
local fromLane = math.sqrt((10 - (-22)) ^ 2 + (-80 - (-48)) ^ 2)
assert(brushDist < fromLane)

local clamped = BotShopLogic.controlDestination(40, 24, PLACE, onlyCanal, { { x = 0, z = 24, range = 20 } })
assert(clamped == nil)

print("bot shop ok: Yarnplate, Paper Charm, Longclaw, Pounce Boots, Stall Fang, Mana Treat, Yarn Cleave, Control Yarn, Whisker Lens")
