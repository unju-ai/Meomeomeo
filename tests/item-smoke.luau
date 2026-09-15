-- Run through tools/test-items.py against ItemCatalog stacks.

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
for _, item in catalog do
	if item.id == "ControlYarn" then
		seen = true
		assert(item.cost == 75)
		assert(item.stackMax == 2)
		assert(item.bonusDamage == 0)
	end
end
assert(seen)

local bonuses = ItemCatalog.bonuses({ "ControlYarn", "ControlYarn", "PounceBoots" })
assert(bonuses.walkSpeed == 6)
assert(bonuses.bonusDamage == 0)

print("PASS: Control Yarn stack cap, unique lens, bonuses ignore pink charges")
