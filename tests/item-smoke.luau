-- Run through tools/test-items.py against ItemCatalog stacks and ItemKits effects.

assert(ItemCatalog.get("WhiskerLens") ~= nil)
assert(ItemCatalog.get("ControlYarn") ~= nil)
assert(ItemCatalog.maxStack("WhiskerLens") == 1)
assert(ItemCatalog.maxStack("ControlYarn") == 2)
assert(ItemCatalog.maxStack("nope") == 1)

local empty = {}
assert(ItemCatalog.count(empty, "ControlYarn") == 0)
assert(ItemCatalog.canBuy(empty, "ControlYarn") == true)
assert(ItemCatalog.canBuy(empty, "WhiskerLens") == true)

local one = { "ControlYarn" }
assert(ItemCatalog.count(one, "ControlYarn") == 1)
assert(ItemCatalog.canBuy(one, "ControlYarn") == true)

local two = { "ControlYarn", "Longclaw", "ControlYarn" }
assert(ItemCatalog.count(two, "ControlYarn") == 2)
assert(ItemCatalog.canBuy(two, "ControlYarn") == false)
assert(ItemCatalog.canBuy(two, "WhiskerLens") == true)
assert(ItemCatalog.canBuy({ "WhiskerLens" }, "WhiskerLens") == false)

local catalog = ItemCatalog.all()
local seen = false
local ids = {}
for _, item in catalog do
	table.insert(ids, item.id)
	if item.id == "ControlYarn" then
		seen = true
		assert(item.cost == 75)
		assert(item.stackMax == 2)
		assert(item.bonusDamage == 0)
	end
end
assert(seen)
assert(ids[1] == "Longclaw")
assert(ids[2] == "Yarnplate")
assert(ids[3] == "ManaTreat")
assert(ids[4] == "PounceBoots")
assert(ids[5] == "WhiskerLens")
assert(ids[6] == "ControlYarn")
assert(ids[7] == ItemKits.CleaveId)
assert(ids[8] == ItemKits.FangId)
assert(ids[9] == ItemKits.CharmId)
assert(#ids == 9)

local bonuses = ItemCatalog.bonuses({ "ControlYarn", "ControlYarn", "PounceBoots" })
assert(bonuses.walkSpeed == 6)
assert(bonuses.bonusDamage == 0)

local cleave = ItemCatalog.get(ItemKits.CleaveId)
local fang = ItemCatalog.get(ItemKits.FangId)
local charm = ItemCatalog.get(ItemKits.CharmId)
assert(cleave and cleave.name == "Yarn Cleave" and cleave.cost == ItemKits.CLEAVE_COST)
assert(fang and fang.name == "Stall Fang" and fang.cost == ItemKits.FANG_COST)
assert(charm and charm.name == "Paper Charm" and charm.cost == ItemKits.CHARM_COST)
assert(cleave.bonusDamage == 0 and cleave.armor == 0 and cleave.maxHealth == 0 and cleave.maxMana == 0 and cleave.walkSpeed == 0)
assert(fang.bonusDamage == 0 and fang.maxHealth == 0)
assert(charm.bonusDamage == 0 and charm.walkSpeed == 0)
assert(ItemCatalog.maxStack(ItemKits.CleaveId) == 1)
assert(ItemCatalog.canBuy({ ItemKits.CleaveId }, ItemKits.CleaveId) == false)
assert(ItemCatalog.canBuy({ ItemKits.FangId }, ItemKits.CharmId) == true)
assert(string.find(cleave.blurb, "Press 7", 1, true))
assert(string.find(fang.blurb, "20%", 1, true))
assert(string.find(charm.blurb, "2.4s", 1, true))

local flat = ItemCatalog.bonuses({ ItemKits.CleaveId, ItemKits.FangId, ItemKits.CharmId })
assert(flat.bonusDamage == 0 and flat.armor == 0 and flat.maxHealth == 0 and flat.maxMana == 0 and flat.walkSpeed == 0)

assert(ItemKits.CLEAVE_COST == 280 and ItemKits.CLEAVE_COST <= 300)
assert(ItemKits.FANG_COST == 300)
assert(ItemKits.CHARM_COST == 220)
assert(ItemKits.FANG_THRESHOLD == 0.2)
assert(ItemKits.fangBonus(100, 100, true) == 0)
assert(ItemKits.fangBonus(20, 100, true) == ItemKits.FANG_BONUS)
assert(ItemKits.fangBonus(19, 100, true) == ItemKits.FANG_BONUS)
assert(ItemKits.fangBonus(20, 100, false) == 0)
assert(ItemKits.fangBonus(1, 0, true) == 0)
assert(ItemKits.fangBonus(0, 100, true) == 0)

assert(ItemKits.cleaveReady(10, 10) == true)
assert(ItemKits.cleaveReady(9.9, 10) == false)
assert(ItemKits.cleaveReady(0, nil) == true)
assert(ItemKits.cleaveReadyAt(4) == 4 + ItemKits.CLEAVE_COOLDOWN)

local origin = Vector3.new(0, 10, 0)
assert(ItemKits.inCleave(origin, Vector3.new(12, 0, 0)) == true)
assert(ItemKits.inCleave(origin, Vector3.new(12.1, 0, 0)) == false)
assert(ItemKits.inCleave(origin, Vector3.new(0, 100, 0)) == true)
assert(ItemKits.inCleave(origin, Vector3.new(9, 0, 9)) == false)

local opened = ItemKits.charmStep(0.7, true, 10, nil, nil)
assert(opened.procced == true and opened.mul == 1)
assert(opened.untilAt == 10 + ItemKits.CHARM_WINDOW)
assert(opened.readyAt == 10 + ItemKits.CHARM_COOLDOWN)
local inside = ItemKits.charmStep(0.7, true, 11, opened.untilAt, opened.readyAt)
assert(inside.procced == false and inside.mul == 1 and inside.untilAt == opened.untilAt)
local cooling = ItemKits.charmStep(0.7, true, 13, opened.untilAt, opened.readyAt)
assert(cooling.procced == false and cooling.mul == 0.7 and cooling.untilAt == nil)
local bare = ItemKits.charmStep(0.7, false, 10, nil, nil)
assert(bare.procced == false and bare.mul == 0.7)
local calm = ItemKits.charmStep(1, true, 10, nil, nil)
assert(calm.procced == false and calm.mul == 1)

assert(ItemKits.cleaveHud(false, 0, 0) == "7  Cleave  (buy)")
assert(ItemKits.cleaveHud(true, 0, 0) == "7  Cleave  ready")
assert(ItemKits.cleaveHud(true, 0, 5) == "7  Cleave  5s")
assert(ItemKits.charmHud(false, 0, nil, nil) == "")
assert(ItemKits.charmHud(true, 0, 2, 20) == " · Charm")
assert(ItemKits.charmHud(true, 3, 2, 20) == " · Charm 17s")
assert(ItemKits.owns({ ItemKits.CleaveId }, ItemKits.CleaveId) == true)
assert(ItemKits.owns({}, ItemKits.FangId) == false)

local sawCleave = false
local sawFang = false
local sawCharm = false
for _, row in ItemKits.helpRows() do
	local text = row[2]
	if text and string.find(text, "Yarn Cleave", 1, true) then
		sawCleave = true
	end
	if text and string.find(text, "Stall Fang", 1, true) then
		sawFang = true
	end
	if text and string.find(text, "Paper Charm", 1, true) then
		sawCharm = true
	end
end
assert(sawCleave and sawFang and sawCharm)

-- ShopPaint: register sections, key chips, gold / fountain copy, buy tint (UI only).
local function rgbEq(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

assert(ShopPaint.sectionOf("Longclaw") == "Stats")
assert(ShopPaint.sectionOf("Yarnplate") == "Stats")
assert(ShopPaint.sectionOf("ManaTreat") == "Stats")
assert(ShopPaint.sectionOf("PounceBoots") == "Stats")
assert(ShopPaint.sectionOf("WhiskerLens") == "Vision")
assert(ShopPaint.sectionOf("ControlYarn") == "Vision")
assert(ShopPaint.sectionOf(ItemKits.CleaveId) == "Actives")
assert(ShopPaint.sectionOf(ItemKits.FangId) == "Actives")
assert(ShopPaint.sectionOf(ItemKits.CharmId) == "Actives")

local sections = ShopPaint.sectionOrder()
assert(sections[1] == "Stats" and sections[2] == "Vision" and sections[3] == "Actives")
assert(ShopPaint.sectionTitle("Stats") == "STATS · sticks")
assert(ShopPaint.sectionTag("Vision") == "VISION")
assert(ShopPaint.sectionTag("Actives") == "ACTIVES")

assert(ShopPaint.keybind("WhiskerLens") == "5")
assert(ShopPaint.keybind("ControlYarn") == "6")
assert(ShopPaint.keybind(ItemKits.CleaveId) == "7")
assert(ShopPaint.keybind("Longclaw") == nil)
assert(ShopPaint.keybind(ItemKits.FangId) == nil)

assert(ShopPaint.goldLine(500) == "500g")
assert(ShopPaint.goldLine(0) == "0g")
assert(ShopPaint.goldLine(-3) == "0g")
assert(ShopPaint.fountainLine(true) == "at fountain")
assert(ShopPaint.fountainLine(false) == "must be at fountain")
assert(ShopPaint.headerLine(500, true) == "500g · at fountain")
assert(string.find(ShopPaint.hintLine(), "Stats", 1, true))
assert(ShopPaint.buyToast("Longclaw") == "Bought Longclaw · Pawmart")

assert(ShopPaint.cardKind(500, true, 0, 1, 250) == "buyable")
assert(ShopPaint.cardKind(100, true, 0, 1, 250) == "short")
assert(ShopPaint.cardKind(500, false, 0, 1, 250) == "away")
assert(ShopPaint.cardKind(500, true, 1, 1, 250) == "owned")
assert(ShopPaint.cardKind(500, true, 2, 2, 75) == "full")
assert(ShopPaint.cardKind(500, true, 1, 2, 75) == "buyable")
assert(ShopPaint.cardKind(50, true, 1, 2, 75) == "short")

local buyable = ShopPaint.cardPaint("buyable")
assert(buyable.active == true)
assert(rgbEq(buyable.stroke, ShopPaint.Amber))
local short = ShopPaint.cardPaint("short")
assert(short.active == false)
assert(rgbEq(short.stroke, ShopPaint.Coral))
local owned = ShopPaint.cardPaint("owned")
assert(owned.active == false)
assert(rgbEq(owned.stroke, ShopPaint.Mint))
local away = ShopPaint.cardPaint("away")
assert(away.active == false)
assert(rgbEq(away.text, ShopPaint.Muted))

assert(ShopPaint.nameLine("Control Yarn", 75, 1, 2, "buyable") == "Control Yarn  ·  1/2  ·  75g")
assert(ShopPaint.nameLine("Longclaw", 250, 1, 1, "owned") == "Longclaw  ·  owned")
assert(ShopPaint.nameLine("Yarn Cleave", 280, 0, 1, "buyable") == "Yarn Cleave  ·  280g")

-- Every catalog row maps to a section (nine items stay buyable at the register).
local mapped = 0
for _, item in ItemCatalog.all() do
	local sec = ShopPaint.sectionOf(item.id)
	assert(sec == "Stats" or sec == "Vision" or sec == "Actives")
	mapped += 1
end
assert(mapped == 9)

print("PASS: Control Yarn stack cap, unique lens, Yarn Cleave, Stall Fang, Paper Charm, ShopPaint")
