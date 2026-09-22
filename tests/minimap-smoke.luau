-- Minimap paint helpers (no Instance / Theme). Vision mask math stays elsewhere.

local function rgbEq(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

-- You vs ally vs enemy strokes stay distinct in a fight.
local selfPip = MinimapPaint.champ(true, true, "Blue", false)
assert(rgbEq(selfPip.fill, MinimapPaint.Cream), "you are cream")
assert(rgbEq(selfPip.stroke, MinimapPaint.Ink), "you get an ink ring")
assert(selfPip.size >= 9, "you are the largest champ pip")
assert(selfPip.shape == "self")

local ally = MinimapPaint.champ(false, true, "Blue", false)
assert(rgbEq(ally.fill, MinimapPaint.Blue), "ally keeps team fill")
assert(rgbEq(ally.stroke, MinimapPaint.Cream), "ally cream stroke")
assert(ally.shape == "ally")

local enemy = MinimapPaint.champ(false, false, "Red", false)
assert(rgbEq(enemy.fill, MinimapPaint.Red), "enemy keeps team fill")
assert(rgbEq(enemy.stroke, MinimapPaint.Coral), "enemy coral stroke")
assert(enemy.shape == "enemy")

local botAlly = MinimapPaint.champ(false, true, "Blue", true)
assert(botAlly.size < ally.size, "bots are smaller than human allies")

-- Structures match smart-ping shapes; gated stalls differ from open.
local post = MinimapPaint.structure("Outer", "Blue", true, true)
assert(post.shape == "post")
assert(post.corner == 2, "posts are square")
assert(rgbEq(post.stroke, MinimapPaint.Lantern), "post lantern ring")

local openStall = MinimapPaint.structure("Inner", "Red", true, true)
assert(openStall.shape == "stall")
assert(openStall.corner == 99, "stalls are round")
assert(rgbEq(openStall.fill, MinimapPaint.Lantern), "open stall is lantern amber")
assert(rgbEq(openStall.stroke, MinimapPaint.Wood), "open stall wood ring")

local gated = MinimapPaint.structure("Inner", "Red", true, false)
assert(gated.shape == "stall")
assert(gated.fill[1] < openStall.fill[1], "gated stall is darker than open")
assert(gated.transparency > 0, "gated stall reads muted")

local core = MinimapPaint.structure("Core", "Blue", true, true)
assert(core.shape == "core")
assert(rgbEq(core.fill, MinimapPaint.Pink), "core is pink")
assert(rgbEq(core.stroke, MinimapPaint.Yarn), "core yarn ring")
assert(core.size > openStall.size, "core is larger than a stall")

local rubble = MinimapPaint.structure("Outer", "Blue", false, false)
assert(rgbEq(rubble.fill, MinimapPaint.Dead), "dead structures go gray")

-- Canal Levi UP / respawn / taken / body.
local body = MinimapPaint.levi("body")
assert(body ~= nil and body.shape == "body")
assert(body.corner == 99, "body is round")
assert(body.size >= 9)

local pit = MinimapPaint.levi("pit")
assert(pit ~= nil and pit.shape == "pit")
assert(pit.corner == 2, "UP-in-fog pit is square")
assert(pit.fill[1] > 200, "UP pit stays bright")

local down = MinimapPaint.levi("down")
assert(down ~= nil and down.shape == "down")
assert(down.corner == 2, "respawn mark is square")
assert(down.fill[1] < pit.fill[1], "respawn is darker than UP pit")
assert(down.transparency > 0)

local spent = MinimapPaint.levi("spent")
assert(spent ~= nil and spent.shape == "spent")
assert(spent.size < down.size, "taken mark is the smallest")
assert(spent.transparency > down.transparency, "taken is the faintest")

assert(MinimapPaint.levi("none") == nil)
assert(MinimapPaint.levi("waiting") == nil)

-- Fog explored tint stays lighter than unexplored (already true — keep it).
local unRgb, unA = MinimapPaint.fogCell(false)
local exRgb, exA = MinimapPaint.fogCell(true)
assert(rgbEq(unRgb, MinimapPaint.FogUnexplored))
assert(rgbEq(exRgb, MinimapPaint.FogExplored))
assert(exA > unA, "explored is more transparent (lighter) than unexplored")
local unLum = unRgb[1] + unRgb[2] + unRgb[3]
local exLum = exRgb[1] + exRgb[2] + exRgb[3]
assert(exLum > unLum, "explored RGB is lighter than black unexplored")

-- Wards stay square; pinks read magenta.
local pink = MinimapPaint.ward("control", "Blue")
assert(pink.corner == 2)
assert(rgbEq(pink.fill, MinimapPaint.Pink))
local trinket = MinimapPaint.ward("trinket", "Red")
assert(trinket.corner == 2)
assert(trinket.fill[1] > 200)

-- Ping shapes share structure paint.
local pingPost = MinimapPaint.ping("post", "Red", MinimapPaint.Amber, 14)
assert(pingPost.shape == "post" and pingPost.corner == 2)
local pingStall = MinimapPaint.ping("stall", "Blue", MinimapPaint.Amber, 14)
assert(pingStall.shape == "stall" and rgbEq(pingStall.fill, MinimapPaint.Lantern))
local pingDot = MinimapPaint.ping("dot", nil, MinimapPaint.Amber, 12)
assert(pingDot.shape == "dot" and rgbEq(pingDot.fill, MinimapPaint.Amber))

-- Click flash: 1 at press, 0 after ClickFlashSeconds.
assert(MinimapPaint.clickFlash(0) == 1)
assert(MinimapPaint.clickFlash(-1) == 0)
assert(MinimapPaint.clickFlash(MinimapPaint.ClickFlashSeconds) == 0)
assert(MinimapPaint.clickFlash(MinimapPaint.ClickFlashSeconds * 0.5) == 0.5)

-- A down small camp is a faint square. The living pip stays round amber. Levi marks stay theirs.
local campWaiting = MinimapPaint.campDown()
local campLiving = MinimapPaint.camp(false)
assert(campWaiting.shape == "campDown")
assert(campWaiting.corner == 2, "a waiting pit is a small square")
assert(campWaiting.transparency > campLiving.transparency, "waiting pit is fainter than a living camp")
assert(campWaiting.fill[1] < MinimapPaint.Amber[1], "waiting fill is dimmer than the living amber")
assert(rgbEq(campWaiting.stroke, MinimapPaint.Amber))
local leviBodyMark = MinimapPaint.levi("body")
assert(leviBodyMark ~= nil and leviBodyMark.size > campWaiting.size, "Levi's body stays larger than a camp pit")
assert(campLiving.shape == "camp" and campLiving.corner == 99)

-- A lane-wave mouth is a tiny round cream pip, not a camp chip and not a kitten.
local waveDot = MinimapPaint.waveMouth()
local kittenPip = MinimapPaint.minion("Blue")
assert(waveDot.shape == "wave")
assert(waveDot.corner == 99, "wave blink is round")
assert(waveDot.size < kittenPip.size, "wave blink is smaller than a kitten pip")
assert(waveDot.size < campWaiting.size, "wave blink is smaller than a camp chip")
assert(rgbEq(waveDot.fill, MinimapPaint.Cream))
assert(rgbEq(waveDot.stroke, MinimapPaint.Lantern))

-- RiverEpic marker states the minimap consumes (no new vision protocol).
assert(RiverEpic.marker("alive", false) == "pit")
assert(RiverEpic.marker("alive", true) == "body")
assert(RiverEpic.marker("returning", false) == "down")
assert(RiverEpic.marker("spent", false) == "spent")
assert(RiverEpic.marker("waiting", false) == "none")

print("minimap-smoke ok")
