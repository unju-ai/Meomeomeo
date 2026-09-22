-- Bump rules for the in-match meme tape. Run through tools/test-meme-stock.py.

assert(MemeStockLogic.Kill > 0)
assert(MemeStockLogic.Death < 0)
assert(math.abs(MemeStockLogic.Death) < MemeStockLogic.Kill)
assert(MemeStockLogic.Post > MemeStockLogic.Kill)
assert(MemeStockLogic.Stall > MemeStockLogic.Post)
assert(MemeStockLogic.Core > MemeStockLogic.Stall)
assert(MemeStockLogic.Core < 0.35)
assert(MemeStockLogic.TeamPost > 0 and MemeStockLogic.TeamPost < MemeStockLogic.Post)
assert(MemeStockLogic.TeamStall > 0 and MemeStockLogic.TeamStall < MemeStockLogic.Stall)
assert(MemeStockLogic.TeamCore > 0 and MemeStockLogic.TeamCore < MemeStockLogic.Core)

assert(MemeStockLogic.structureKind("Outer", false) == "post")
assert(MemeStockLogic.structureKind("Inner", false) == "stall")
assert(MemeStockLogic.structureKind("Core", false) == "core")
assert(MemeStockLogic.structureKind("Outer", true) == "teamPost")
assert(MemeStockLogic.structureKind("Inner", true) == "teamStall")
assert(MemeStockLogic.structureKind("Core", true) == "teamCore")
assert(MemeStockLogic.structureKind("Lane", false) == nil)
assert(MemeStockLogic.structureKind("Lane", true) == nil)

local kill = MemeStockLogic.admit("kill", 10, nil)
assert(kill ~= nil and kill.magnitude == MemeStockLogic.Kill)
local death = MemeStockLogic.admit("death", 10, nil)
assert(death ~= nil and death.magnitude == MemeStockLogic.Death)
local post = MemeStockLogic.admit("post", 10, nil)
assert(post ~= nil and post.magnitude == MemeStockLogic.Post)
local stall = MemeStockLogic.admit("stall", 10, nil)
assert(stall ~= nil and stall.magnitude == MemeStockLogic.Stall)
local core = MemeStockLogic.admit("core", 10, nil)
assert(core ~= nil and core.magnitude == MemeStockLogic.Core)
local teamPost = MemeStockLogic.admit("teamPost", 10, nil)
assert(teamPost ~= nil and teamPost.magnitude == MemeStockLogic.TeamPost)

-- Lane kittens and camps never print, even as a burst.
local quietKinds = { "minion", "jungle", "assist", "ward", "lastHit", "" }
for _, kind in quietKinds do
	for step = 0, 7 do
		assert(MemeStockLogic.admit(kind, step * 0.2, nil) == nil)
	end
end

-- Same-kind gap. A second kill inside the window is dropped; a double after it prints.
assert(MemeStockLogic.admit("kill", 10.1, 10) == nil)
assert(MemeStockLogic.admit("kill", 10 + MemeStockLogic.KillGap, 10) ~= nil)
assert(MemeStockLogic.admit("post", 11, 10) == nil)
assert(MemeStockLogic.admit("post", 10 + MemeStockLogic.EventGap, 10) ~= nil)
-- A death does not borrow the kill clock. The service keeps those stamps apart.
assert(MemeStockLogic.admit("death", 10.1, nil) ~= nil)

local up, gain = MemeStockLogic.nextPrice(10, MemeStockLogic.Kill)
assert(math.abs(up - 10.8) < 0.0001)
assert(math.abs(gain - 0.8) < 0.0001)
local dipped, loss = MemeStockLogic.nextPrice(10, MemeStockLogic.Death)
assert(math.abs(dipped - 9.7) < 0.0001)
assert(math.abs(loss - -0.3) < 0.0001)
local floored, flat = MemeStockLogic.nextPrice(1, MemeStockLogic.Death)
assert(floored == 1 and flat == 0)

assert(MemeStockLogic.tone(0.8) == "up")
assert(MemeStockLogic.tone(-0.4) == "down")
assert(MemeStockLogic.tone(0.01) == "flat")
assert(MemeStockLogic.tone(0) == "flat")
assert(MemeStockLogic.signed(0.8) == "+0.8")
assert(MemeStockLogic.signed(-0.4) == "-0.4")
assert(MemeStockLogic.signed(0) == "0.0")
assert(MemeStockLogic.signed(0.02) == "0.0")
assert(MemeStockLogic.priceText(12.4) == "12.4")

print("PASS: meme tape bumps, quiet kittens, rate limit, green/red text")
