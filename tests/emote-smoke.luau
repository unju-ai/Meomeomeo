-- Run through tools/test-emote.py against src/shared/EmoteCatalog.luau (+ CosmeticCatalog flair).

assert(#EmoteCatalog.list() == 8, "Eight night-market emotes on the T wheel")
local ids = { "Meow", "Hiss", "Purr", "Flex", "Dance", "Laugh", "Cry", "GG" }
local seen = {}
for i, def in EmoteCatalog.list() do
	assert(def.id == ids[i], "Stable wheel order")
	assert(seen[def.id] == nil)
	seen[def.id] = true
	assert(EmoteCatalog.get(def.id) == def)
	assert(EmoteCatalog.isId(def.id) == true)
	assert(typeof(def.label) == "string" and #def.label > 0)
	assert(typeof(def.emoji) == "string" and #def.emoji > 0)
	assert(typeof(def.cue) == "string" and string.find(def.cue, "Emote", 1, true) == 1)
	assert(
		def.motion == "nod"
			or def.motion == "puff"
			or def.motion == "float"
			or def.motion == "flex"
			or def.motion == "dance"
			or def.motion == "bounce"
			or def.motion == "droop"
			or def.motion == "spin"
	)
	assert(def.color ~= nil)
end
assert(EmoteCatalog.get("Loaf") == nil, "Optional Loaf not required in this slice")
assert(EmoteCatalog.get(nil) == nil)
assert(EmoteCatalog.get(12) == nil)
assert(EmoteCatalog.isId("missing") == false)

-- Closet emoteFlair must resolve a tint for equipped drip (server + client share this helper).
assert(CosmeticCatalog.emoteTint("", "") == nil)
assert(CosmeticCatalog.emoteTint(nil, nil) == nil)
assert(CosmeticCatalog.emoteTint("CreamCap", "YarnPuff") == nil)
local moon = CosmeticCatalog.emoteTint(nil, "MoonDust")
local crown = CosmeticCatalog.emoteTint("CanalCrown", nil)
local orbs = CosmeticCatalog.emoteTint("", "BraincellOrbs")
local spark = CosmeticCatalog.emoteTint("LanternCap", "StallSpark")
assert(moon and crown and orbs and spark)
-- Trail flair wins when both slots carry flair.
local both = CosmeticCatalog.emoteTint("CanalCrown", "MoonDust")
assert(both and both.r == moon.r and both.g == moon.g and both.b == moon.b)

print("PASS: emote catalog order, motions, Closet emoteFlair tint helper")
