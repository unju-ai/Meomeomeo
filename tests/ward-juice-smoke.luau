-- Ward place / lifetime juice. Duration, radius, and fog membership stay on the server.

assert(WardJuice.modeAllows("Moba", "InProgress") == true)
assert(WardJuice.modeAllows("Moba", "Lobby") == false)
assert(WardJuice.modeAllows("Moba", "Ended") == false)
assert(WardJuice.modeAllows("Moba", nil) == false)
assert(WardJuice.modeAllows("Hub", "InProgress") == false)
assert(WardJuice.modeAllows("YarnRun", "InProgress") == false)
assert(WardJuice.modeAllows("KoiPond", "InProgress") == false)
assert(WardJuice.modeAllows("YarnParty", "InProgress") == false)
assert(WardJuice.modeAllows("MemeArcade", "InProgress") == false)

-- Allies are shown without the vision list. Enemies need that list.
assert(WardJuice.revealed(true, false) == true)
assert(WardJuice.revealed(false, true) == true)
assert(WardJuice.revealed(false, false) == false)

assert(WardJuice.cueKind(7, 7, true, false) == "local")
assert(WardJuice.cueKind(7, 8, true, false) == "ally")
assert(WardJuice.cueKind(7, 9, false, true) == "enemy")
assert(WardJuice.cueKind(7, 9, false, false) == "none")
assert(WardJuice.cueKind(7, nil, true, false) == "ally")
assert(WardJuice.shouldPaint("local") == true)
assert(WardJuice.shouldPaint("ally") == true)
assert(WardJuice.shouldPaint("enemy") == true)
assert(WardJuice.shouldPaint("none") == false)

assert(WardJuice.plantLine("control") == "Control Yarn planted")
assert(WardJuice.plantLine("trinket") == "Ward planted")
assert(WardJuice.wantsToast("local") == true)
assert(WardJuice.wantsToast("ally") == false)
assert(WardJuice.wantsToast("enemy") == false)

local now = 100
assert(WardJuice.placeFresh(nil, now) == false)
assert(WardJuice.placeFresh(now, now) == true)
assert(WardJuice.placeFresh(now - WardJuice.PlaceWindow, now) == true)
assert(WardJuice.placeFresh(now - WardJuice.PlaceWindow - 0.05, now) == false)
assert(WardJuice.placeFresh(now + WardJuice.PlaceSlack, now) == true)
assert(WardJuice.placeFresh(now + WardJuice.PlaceSlack + 0.05, now) == false)

assert(WardJuice.shouldPuff("local", now, now, false) == true)
assert(WardJuice.shouldPuff("none", now, now, false) == false)
assert(WardJuice.shouldPuff("enemy", now, now, true) == false)
assert(WardJuice.shouldPuff("enemy", now - 30, now, false) == false)
assert(WardJuice.shouldPuff("ally", now - 0.2, now, false) == true)

assert(WardJuice.shouldPop(true) == true)
assert(WardJuice.shouldPop(false) == false)

local lead = WardJuice.FadeLead
assert(WardJuice.fading(now + lead + 1, now) == false)
assert(WardJuice.fading(now + lead, now) == true)
assert(WardJuice.fading(now + 1, now) == true)
assert(WardJuice.fading(now, now) == false)
assert(WardJuice.fading(nil, now) == false)
assert(WardJuice.expired(now, now) == true)
assert(WardJuice.expired(now + 1, now) == false)
assert(WardJuice.expired(nil, now) == false)

assert(WardJuice.fadeAlpha(now + lead + 5, now) == 0)
assert(WardJuice.fadeAlpha(nil, now) == 0)
local held = WardJuice.fadeAlpha(now, now)
assert(held > 0.3 and held <= 0.55, "expired stamp holds the peak until the part is gone")
local edge = WardJuice.fadeAlpha(lead, 0)
assert(math.abs(edge - 0.08) < 1e-9, "fade starts soft")
local mid = WardJuice.fadeAlpha(lead / 2, 0)
assert(math.abs(mid - 0.25) < 1e-9, "fade rises through the window")
assert(mid > edge)

assert(WardJuice.bodyTransparency("local", now + 40, now) == 0.12)
assert(WardJuice.bodyTransparency("ally", now + 40, now) == 0.22)
assert(WardJuice.bodyTransparency("enemy", now + 40, now) == 0.42)
assert(WardJuice.bodyTransparency("local", now + 1, now) > 0.12)

assert(WardJuice.pulseScale(now + 40, now) == 1)
assert(WardJuice.pulseScale(nil, now) == 1)
local pulsed = WardJuice.pulseScale(math.pi / 16,  math.pi / 16)
-- expiresAt == now == pi/16, left is 0, not fading.
assert(pulsed == 1)
local pulseNow = math.pi / 16
local pulsing = WardJuice.pulseScale(pulseNow + 1, pulseNow)
assert(math.abs(pulsing - 1.08) < 1e-9)

assert(WardJuice.bobOffset(0) == 0)
local bobNow = math.pi / (2 * WardJuice.BobSpeed)
assert(math.abs(WardJuice.bobOffset(bobNow) - WardJuice.BobLift) < 1e-9)

assert(WardJuice.scale("local") > WardJuice.scale("ally"))
assert(WardJuice.scale("ally") > WardJuice.scale("enemy"))

local function rgbEq(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

local pole, lantern, yarn = WardJuice.palette("local", "control")
assert(rgbEq(pole, WardJuice.Cream))
assert(rgbEq(lantern, WardJuice.Amber))
assert(rgbEq(yarn, WardJuice.Cream))
local trinketPole, trinketLantern, trinketYarn = WardJuice.palette("ally", "trinket")
assert(rgbEq(trinketPole, WardJuice.Cream))
assert(rgbEq(trinketLantern, WardJuice.Cream))
assert(rgbEq(trinketYarn, WardJuice.Amber))
local enemyPole, enemyLantern, enemyYarn = WardJuice.palette("enemy", "control")
assert(rgbEq(enemyPole, WardJuice.Pink))
assert(rgbEq(enemyLantern, WardJuice.Pink))
assert(rgbEq(enemyYarn, WardJuice.Cream))

-- Fade adds transparency. It does not grant a minimap dot by itself.
assert(WardJuice.minimapTransparency(0, nil, now) == 0)
assert(WardJuice.minimapTransparency(0, now + 40, now) == 0)
local faint = WardJuice.minimapTransparency(0, lead, 0)
assert(math.abs(faint - 0.08 * 0.85) < 1e-9)
assert(faint > 0 and faint < 0.72)
assert(WardJuice.minimapTransparency(0.2, now + 40, now) == 0.2)

print("ward-juice-smoke ok")
