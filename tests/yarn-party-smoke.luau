-- Run through tools/test-party.py against src/shared/YarnPartyCatalog.luau.

assert(YarnPartyCatalog.SeatCount == 4)
assert(YarnPartyCatalog.RoundCount == 3)
assert(#YarnPartyCatalog.Plan == 3)
assert(YarnPartyCatalog.roundAt(1) == "Dodge")
assert(YarnPartyCatalog.roundAt(2) == "Pillows")
assert(YarnPartyCatalog.roundAt(3) == "Dodge")
assert(YarnPartyCatalog.roundAt(99) == "Dodge")
local kinds = YarnPartyCatalog.kinds()
assert(#kinds == 2, "Need two distinct mini-round types")
assert(YarnPartyCatalog.titleOf("Dodge") == "YARN DODGE")
assert(YarnPartyCatalog.titleOf("Pillows") == "STALL FREEZE")
assert(YarnPartyCatalog.pointsForPlace(1) == 3)
assert(YarnPartyCatalog.pointsForPlace(2) == 2)
assert(YarnPartyCatalog.pointsForPlace(3) == 1)
assert(YarnPartyCatalog.pointsForPlace(4) == 0)
assert(YarnPartyCatalog.botName(1) == "LoafBot")
assert(YarnPartyCatalog.botChampion(2) == "Bytekit")
local ranked = YarnPartyCatalog.rankByScore({
	{ id = 2, score = 4, alive = false },
	{ id = 1, score = 6, alive = true },
	{ id = 3, score = 6, alive = false },
})
assert(ranked[1] == 1, "Higher score + alive wins ties")
assert(ranked[2] == 3)
print("PASS: yarn party rounds, scoring, bot fill names")
