-- Kill feed plate helpers (no Instance / Theme). Combat copy stays elsewhere.

local function rgbEq(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

assert(KillFeedPaint.MaxRows == 4, "tidy stack is four chips")
assert(KillFeedPaint.AnnounceHoldSeconds < KillFeedPaint.HoldSeconds, "announce expires before scratch lines")

-- Kind resolution: stall tag + older tower lines that name a lantern stall.
assert(KillFeedPaint.resolveKind("stall", "who snuffed the Red Mid lantern stall") == "stall")
assert(KillFeedPaint.resolveKind("tower", "who knocked over the Blue Mid scratching post") == "tower")
assert(KillFeedPaint.resolveKind("tower", "who snuffed the Red Mid lantern stall") == "stall")
assert(KillFeedPaint.resolveKind("kill", "A scratched B into next week") == "kill")
assert(KillFeedPaint.resolveKind("announce", "Kitty Caster: FIRST BLOOD") == "announce")
assert(KillFeedPaint.resolveKind("ping", "⚠ Caution · Nyan Rocket") == "ping")
assert(KillFeedPaint.resolveKind("nexus", "who unplugged the Red yarn core") == "nexus")
assert(KillFeedPaint.resolveKind("level", "A grew another life — level 2") == "level")

-- Personal emphasis from existing cat copy (no new remote fields).
local names = { "Loaf", "Player1" }
assert(KillFeedPaint.involvement("kill", "Loaf scratched Bot into next week", names) == "selfKill")
assert(KillFeedPaint.involvement("kill", "Bot scratched Loaf into next week", names) == "selfDeath")
assert(KillFeedPaint.involvement("kill", "Loaf got batted by a tower (or a kitten)", names) == "selfDeath")
assert(KillFeedPaint.involvement("kill", "Other scratched Bot into next week", names) == "none")
assert(KillFeedPaint.involvement("tower", "Loaf knocked over the Red Mid scratching post", names) == "selfKill")
assert(KillFeedPaint.involvement("stall", "Loaf snuffed the Red Mid lantern stall", names) == "selfKill")
assert(KillFeedPaint.involvement("announce", "Kitty Caster: FIRST BLOOD · Loaf", names) == "none")
assert(KillFeedPaint.involvement("level", "Loaf grew another life — level 3", names) == "selfKill")

-- Night-market plates stay distinct by kind.
local kill = KillFeedPaint.plate("kill", "none", 1)
assert(rgbEq(kill.text, KillFeedPaint.Peach), "kills read peach")
assert(kill.fillAlpha < 0.7)

local tower = KillFeedPaint.plate("tower", "none", 1)
assert(rgbEq(tower.stroke, KillFeedPaint.Lantern), "posts get lantern stroke")

local stall = KillFeedPaint.plate("stall", "none", 1)
assert(rgbEq(stall.stroke, KillFeedPaint.Wood), "stalls get wood stroke")
assert(rgbEq(stall.text, KillFeedPaint.Lantern), "stall text is lantern")

local nexus = KillFeedPaint.plate("nexus", "none", 1)
assert(rgbEq(nexus.stroke, KillFeedPaint.Pink), "yarn core is pink")

local announce = KillFeedPaint.plate("announce", "none", 1)
assert(announce.fillAlpha > kill.fillAlpha, "announce plate is quieter than kills")
assert(announce.strokeAlpha > kill.strokeAlpha, "announce stroke stays soft under the banner")

local ping = KillFeedPaint.plate("ping", "none", 1)
assert(rgbEq(ping.stroke, KillFeedPaint.Blue), "pings use cobalt")

local level = KillFeedPaint.plate("level", "none", 1)
assert(rgbEq(level.text, KillFeedPaint.Mint), "level-ups are mint")

-- Your kill / death get a light cream or coral ring.
local youKill = KillFeedPaint.plate("kill", "selfKill", 1)
assert(rgbEq(youKill.stroke, KillFeedPaint.Cream), "your kill cream ring")
assert(youKill.bold == true)
assert(youKill.fillAlpha < kill.fillAlpha, "your kill plate is a touch stronger")

local youDeath = KillFeedPaint.plate("kill", "selfDeath", 1)
assert(rgbEq(youDeath.stroke, KillFeedPaint.Coral), "your death coral ring")
assert(youDeath.bold == true)

-- Older rows fade so the stack stays scannable.
assert(KillFeedPaint.ageFade(1) == 0)
assert(KillFeedPaint.ageFade(2) > 0)
assert(KillFeedPaint.ageFade(4) > KillFeedPaint.ageFade(2))
local old = KillFeedPaint.plate("kill", "none", 4)
assert(old.fillAlpha > kill.fillAlpha, "oldest chip is more faded")
assert(old.textAlpha > kill.textAlpha, "oldest text softens")

assert(KillFeedPaint.holdSeconds("announce") == KillFeedPaint.AnnounceHoldSeconds)
assert(KillFeedPaint.holdSeconds("kill") == KillFeedPaint.HoldSeconds)

print("kill-feed-smoke ok")
