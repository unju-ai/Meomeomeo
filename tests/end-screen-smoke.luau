-- End-screen display helpers. Run through tools/test-end-screen.py.

assert(EndScreenCopy.outcomeTitle(true) == "VICTORY")
assert(EndScreenCopy.outcomeTitle(false) == "DEFEAT")
assert(EndScreenCopy.outcomeTitle(nil) == "MATCH OVER")
assert(EndScreenCopy.outcomeTone(true) == "win")
assert(EndScreenCopy.outcomeTone(false) == "loss")
assert(EndScreenCopy.outcomeTone(nil) == "neutral")

assert(EndScreenCopy.subLine(true, "Blue") == "Blue wins · enemy yarn core unplugged")
assert(EndScreenCopy.subLine(false, "Red") == "Red wins · your yarn core fell")
assert(string.find(EndScreenCopy.subLine(nil, nil), "match over", 1, true) ~= nil)

assert(EndScreenCopy.mvpLine("Whiskers", 8, 2, 4, 12345.6) == "MVP · Whiskers · 8/2/4 · 12345 dmg")
assert(EndScreenCopy.mvpLine(nil) == "MVP · nobody clawed hard enough")

assert(EndScreenCopy.leviLine(true, false) == "Levi · Blue take")
assert(EndScreenCopy.leviLine(false, true) == "Levi · Red take")
assert(EndScreenCopy.leviLine(true, true) == "Levi · Blue + Red")
assert(EndScreenCopy.leviLine(false, false) == nil)
assert(EndScreenCopy.leviLine(nil, nil) == nil)

local empty = EndScreenCopy.timelineLines({}, nil)
assert(string.find(empty, "no structures", 1, true) ~= nil)

local lined = EndScreenCopy.timelineLines({
	{ team = "Blue", tier = "Outer", lane = "Top" },
	{ team = "Red", tier = "Outer", lane = "Mid" },
	{ team = "Blue", tier = "Inner", lane = "Bot" },
	{ team = "Red", tier = "Core", lane = "Base" },
}, "Levi · Blue take")
assert(string.find(lined, "Posts", 1, true) ~= nil)
assert(string.find(lined, "Blue Top post", 1, true) ~= nil)
assert(string.find(lined, "Red Mid post", 1, true) ~= nil)
assert(string.find(lined, "Stalls", 1, true) ~= nil)
assert(string.find(lined, "Blue Bot stall", 1, true) ~= nil)
assert(string.find(lined, "Core", 1, true) ~= nil)
assert(string.find(lined, "Red yarn core", 1, true) ~= nil)
assert(string.find(lined, "Levi · Blue take", 1, true) ~= nil)
-- posts before stalls before core
local postsAt = string.find(lined, "Posts", 1, true) :: number
local stallsAt = string.find(lined, "Stalls", 1, true) :: number
local coreAt = string.find(lined, "Core", 1, true) :: number
assert(postsAt < stallsAt and stallsAt < coreAt, "timeline reads posts → stalls → core")

assert(EndScreenCopy.rowMark(true, true) == "*YOU")
assert(EndScreenCopy.rowMark(false, true) == "*MVP")
assert(EndScreenCopy.rowMark(true, false) == " YOU")
assert(EndScreenCopy.rowMark(false, false) == "    ")

print("end-screen copy ok")
