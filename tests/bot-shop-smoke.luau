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
		assert(not contains(plan, "ControlYarn"), `{difficulty} {role} must not buy Control Yarn`)
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
assert(BotShopLogic.nextItem("Hard", "Tank", cost("WhiskerLens"), afterCleave) == "WhiskerLens")
assert(BotShopLogic.nextItem("Hard", "Tank", 99999, { "Yarnplate", "PaperCharm", "YarnCleave", "WhiskerLens" }) == nil)
assert(BotShopLogic.nextItem("Hard", "Tank", cost("PaperCharm") - 1, { "Yarnplate" }) == nil)

local hardAssassin, hardAssassinGold = buyAll("Hard", "Assassin", START, {})
assert(hardAssassin[1] == "Longclaw" and hardAssassin[2] == "PounceBoots" and #hardAssassin == 2)
assert(hardAssassinGold == START - 250 - 200)
assert(not contains(hardAssassin, "StallFang"))
assert(BotShopLogic.nextItem("Hard", "Marksman", cost("StallFang"), hardAssassin) == "StallFang")
assert(BotShopLogic.nextItem("Hard", "Assassin", cost("StallFang") - 1, hardAssassin) == nil)
local afterFang = { "Longclaw", "PounceBoots", "StallFang" }
assert(BotShopLogic.nextItem("Hard", "Assassin", cost("YarnCleave"), afterFang) == "YarnCleave")

local hardMage, hardMageGold = buyAll("Hard", "Mage", START, {})
assert(hardMage[1] == "ManaTreat" and hardMage[2] == "Longclaw" and #hardMage == 2)
assert(hardMageGold == START - 200 - 250)
assert(BotShopLogic.nextItem("Hard", "Support", cost("YarnCleave"), hardMage) == "YarnCleave")
assert(BotShopLogic.nextItem("Hard", "Mage", cost("YarnCleave") - 1, hardMage) == nil)

assert(cost("YarnCleave") == 280)
assert(cost("StallFang") == 300)
assert(cost("PaperCharm") == 220)
assert(cost("WhiskerLens") == 180)
assert(cost("ManaTreat") == 200)

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

print("bot shop ok: Yarnplate, Paper Charm, Longclaw, Pounce Boots, Stall Fang, Mana Treat, Yarn Cleave, Whisker Lens")
