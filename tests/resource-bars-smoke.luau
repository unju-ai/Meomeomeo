-- Resource bar format / warn helpers (no Instance / Theme).

assert(ResourceBars.LowHpRatio == 0.3, "low HP threshold is 30%")

assert(ResourceBars.ratio(50, 100) == 0.5, "half HP")
assert(ResourceBars.ratio(0, 100) == 0, "empty")
assert(ResourceBars.ratio(100, 0) == 0, "zero max stays empty")
assert(ResourceBars.ratio(120, 100) == 1, "overfill clamps")

assert(ResourceBars.formatPair(72.9, 400) == "72 / 400", "floor current / max")
assert(ResourceBars.formatPair(0, 280) == "0 / 280", "empty pair")

assert(ResourceBars.isLowHp(29, 100) == true, "under 30% warns")
assert(ResourceBars.isLowHp(30, 100) == false, "30% is not low")
assert(ResourceBars.isLowHp(0, 100) == false, "dead does not pulse low-HP")
assert(ResourceBars.isLowHp(50, 0) == false, "zero max is not low")

assert(ResourceBars.isManaGated(40, { 50, 0, 30 }) == true, "any unpaid cost gates")
assert(ResourceBars.isManaGated(50, { 50, 30 }) == false, "exact cost is payable")
assert(ResourceBars.isManaGated(10, { 0, 0 }) == false, "zero costs never gate")

assert(ResourceBars.xpLabel(3, 12, 68) == "Lv 3 · 12 / 68", "xp into next")
assert(ResourceBars.xpLabel(18, 0, 0) == "Lv 18 · MAX", "cap level")

local calm = ResourceBars.warnPulse(1.2, false)
assert(calm == 0, "inactive warn is calm")
local a = ResourceBars.warnPulse(0, true)
local b = ResourceBars.warnPulse(ResourceBars.WarnPulseSeconds * 0.25, true)
assert(a >= 0.35 and a <= 1, "pulse stays in range")
assert(b > a, "pulse rises in first quarter")

print("resource-bars-smoke ok")
