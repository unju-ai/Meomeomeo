-- Run through tools/test-death-recap.py against DamageLog.

assert(DamageLog.Capacity == 24)
assert(DamageLog.Window == 12)
assert(DamageLog.MaxLines == 6)
assert(DamageLog.HideLead == 2.5)
assert(DamageLog.kindWord("champion") == "Cat")
assert(DamageLog.kindWord("tower") == "Post")
assert(DamageLog.kindWord("minion") == "Kitten")
assert(DamageLog.kindWord("jungle") == "Camp")
assert(DamageLog.kindWord("item") == "Item")
assert(DamageLog.kindWord("nope") == "Hit")

local function hit(at: number, amount: number, kind: string, name: string, id: string, label: string, killing: boolean)
	return {
		at = at,
		amount = amount,
		sourceKind = kind,
		sourceName = name,
		sourceId = id,
		label = label,
		killingBlow = killing,
	}
end

DamageLog.clearAll()
assert(DamageLog.count(1) == 0)
assert(#DamageLog.recap(1, 100) == 0)

-- Same cat: scratches stack, the ability stays its own row. Killing blow is the tower.
DamageLog.record(1, hit(90, 10.4, "champion", "Nyan Rocket (Bot)", "bot-1", "Scratch", false))
DamageLog.record(1, hit(92, 10.4, "champion", "Nyan Rocket (Bot)", "bot-1", "Scratch", false))
DamageLog.record(1, hit(94, 40, "champion", "Nyan Rocket (Bot)", "bot-1", "Paw Slam", false))
DamageLog.record(1, hit(96, 8, "minion", "Kitten", "kitten", "Nibble", false))
DamageLog.record(1, hit(97, 8, "minion", "Kitten", "kitten", "Nibble", false))
DamageLog.record(1, hit(98, 22, "jungle", "Yarn Golem", "YarnGolemSE", "Swipe", false))
DamageLog.record(1, hit(99, 30, "item", "Yarn Cleave", "YarnCleave:bot-2", "Scammy (Bot)", false))
DamageLog.record(1, hit(100, 50, "tower", "Red Mid scratching post", "RedMidOuter", "Bolt", true))

local lines = DamageLog.recap(1, 100)
assert(#lines == 6, "six contributors inside the window")
assert(lines[1].killingBlow == true)
assert(lines[1].sourceKind == "tower")
assert(lines[1].sourceName == "Red Mid scratching post")
assert(lines[1].label == "Bolt")
assert(lines[1].amount == 50)

local scratch = nil
local slam = nil
local kitten = nil
local camp = nil
local cleave = nil
for _, line in lines do
	if line.label == "Scratch" then
		scratch = line
	elseif line.label == "Paw Slam" then
		slam = line
	elseif line.sourceKind == "minion" then
		kitten = line
	elseif line.sourceKind == "jungle" then
		camp = line
	elseif line.sourceKind == "item" then
		cleave = line
	end
end
assert(scratch ~= nil and scratch.amount == 21, "10.4 + 10.4 rounds once to 21")
assert(scratch.killingBlow == false)
assert(slam ~= nil and slam.amount == 40 and slam.sourceKind == "champion")
assert(kitten ~= nil and kitten.amount == 16 and kitten.label == "Nibble")
assert(camp ~= nil and camp.sourceName == "Yarn Golem" and camp.amount == 22)
assert(cleave ~= nil and cleave.sourceName == "Yarn Cleave" and cleave.label == "Scammy (Bot)")

-- Hits older than the window drop, even if they are still in the buffer.
DamageLog.record(1, hit(80, 999, "champion", "Ancient", "old", "Scratch", false))
local sawAncient = false
for _, storedHit in DamageLog.hits(1) do
	if storedHit.sourceName == "Ancient" then
		sawAncient = true
	end
end
assert(sawAncient, "old hit stays in the match buffer")
local fresh = DamageLog.recap(1, 100)
for _, line in fresh do
	assert(line.sourceName ~= "Ancient")
end

-- A later killing blow replaces the earlier flag.
DamageLog.clear(1)
DamageLog.record(1, hit(10, 20, "champion", "A", "a", "Scratch", true))
DamageLog.record(1, hit(11, 5, "item", "Stall Fang", "StallFang:a", "A", true))
local fang = DamageLog.recap(1, 11)
assert(fang[1].killingBlow == true)
assert(fang[1].sourceKind == "item")
assert(fang[1].sourceName == "Stall Fang")
local scratchKept = false
for _, line in fang do
	if line.label == "Scratch" then
		scratchKept = true
		assert(line.killingBlow == false)
	end
end
assert(scratchKept)

-- The killing blow stays on the card when more contributors than MaxLines exist.
DamageLog.clear(2)
for i = 1, 8 do
	DamageLog.record(2, hit(50 + i, 10, "champion", `Cat {i}`, `c{i}`, "Scratch", false))
end
DamageLog.record(2, hit(60, 1, "tower", "Blue yarn core", "BlueNexus", "Bolt", true))
local capped = DamageLog.recap(2, 60)
assert(#capped == DamageLog.MaxLines)
assert(capped[1].killingBlow == true)
assert(capped[1].sourceName == "Blue yarn core")
assert(capped[1].amount == 1)

-- Ring buffer drops the oldest raw hit.
DamageLog.clear(3)
for i = 1, DamageLog.Capacity + 5 do
	DamageLog.record(3, hit(i, 1, "champion", `H{i}`, `h{i}`, "Scratch", i == DamageLog.Capacity + 5))
end
assert(DamageLog.count(3) == DamageLog.Capacity)
local stored = DamageLog.hits(3)
assert(stored[1].sourceName == `H{6}`)
assert(stored[#stored].killingBlow == true)
assert(stored[#stored].sourceName == `H{DamageLog.Capacity + 5}`)

DamageLog.clearAll()
assert(DamageLog.count(1) == 0)
assert(DamageLog.count(3) == 0)
print("death recap smoke ok")
