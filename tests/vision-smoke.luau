-- Run through tools/test-vision.py against VisionLogic.

assert(VisionLogic.Cols * VisionLogic.CellSize == VisionLogic.MaxX - VisionLogic.MinX)
assert(VisionLogic.Rows * VisionLogic.CellSize == VisionLogic.MaxZ - VisionLogic.MinZ)
assert(VisionLogic.CellCount == VisionLogic.Cols * VisionLogic.Rows)
assert(#VisionLogic.Brushes == 6)
assert(#VisionLogic.Walls == 10)
assert(VisionLogic.CellSize == 10)

local mid = VisionLogic.indexOf(0, 0)
local cx, cz = VisionLogic.center(mid)
assert(math.abs(cx) < VisionLogic.CellSize)
assert(math.abs(cz) < VisionLogic.CellSize)

local last = VisionLogic.CellCount
local flags = table.create(last, false)
flags[1] = true
flags[32] = true
flags[33] = true
flags[last] = true
local packed = VisionLogic.pack(flags)
assert(#packed == VisionLogic.WordCount)
assert(VisionLogic.bitOn(packed, 1) == true)
assert(VisionLogic.bitOn(packed, 2) == false)
assert(VisionLogic.bitOn(packed, 32) == true)
assert(VisionLogic.bitOn(packed, 33) == true)
assert(VisionLogic.bitOn(packed, last) == true)
assert(VisionLogic.bitOn(packed, last - 1) == false)
assert(VisionLogic.bitOn({}, 1) == false)

-- Source-based radius: a champion bubble sees a far target a minion bubble cannot.
local champ = { x = 0, z = 0, radius = 54 }
local kitten = { x = 0, z = 0, radius = 28 }
assert(VisionLogic.canSeeFrom(champ.x, champ.z, champ.radius, 40, 0) == true)
assert(VisionLogic.canSeeFrom(kitten.x, kitten.z, kitten.radius, 40, 0) == false)
assert(VisionLogic.covered({ champ }, 40, 0) == true)
assert(VisionLogic.covered({ kitten }, 40, 0) == false)

-- Open ground is visible; jungle brush hides occupants until a source enters.
assert(VisionLogic.brushAt(0, 0) == nil, "mid lane must not be brush")
assert(VisionLogic.brushAt(-90, -80) == nil, "top lane corridor stays open")
assert(VisionLogic.brushAt(-88, -108) == "BrushNW")
assert(VisionLogic.brushAt(-48, -98) == "BrushNE")

local outside = { x = -88, z = -90, radius = 54 }
assert(VisionLogic.canSeeFrom(outside.x, outside.z, outside.radius, -88, -108) == false, "cannot see into brush from outside")
assert(VisionLogic.canSeeFrom(outside.x, outside.z, outside.radius, -88, -80) == true, "looking at the lane still works")

local inside = { x = -88, z = -108, radius = 54 }
assert(VisionLogic.canSeeFrom(inside.x, inside.z, inside.radius, -82, -108) == true, "same brush is visible")
assert(VisionLogic.canSeeFrom(inside.x, inside.z, inside.radius, -88, -80) == true, "can see out of brush")
assert(VisionLogic.canSeeFrom(inside.x, inside.z, inside.radius, -48, -98) == false, "other brush stays hidden")

-- Ward / tower bubbles paint a compact mask; brush cells stay dark until entered.
local tower = { x = -90, z = -80, radius = 46 }
local mask = VisionLogic.mask({ tower })
assert(VisionLogic.bitOn(mask, VisionLogic.indexOf(-90, -80)) == true)
assert(VisionLogic.bitOn(mask, VisionLogic.indexOf(90, 80)) == false)
assert(VisionLogic.bitOn(mask, VisionLogic.indexOf(-88, -108)) == false, "tower does not light unentered brush")

local wardInBrush = { x = -88, z = -108, radius = 40 }
local wardMask = VisionLogic.mask({ wardInBrush })
assert(VisionLogic.bitOn(wardMask, VisionLogic.indexOf(-88, -108)) == true, "ward in brush lights that pocket")

-- Base walls block LoS; the mid-lane gate stays open. Brush is not a wall.
assert(VisionLogic.clearLine(-176, 0, -120, 0) == true, "mid gate is open")
assert(VisionLogic.canSeeFrom(-176, 0, 54, -130, 0) == true, "fountain sees through the gate")
assert(VisionLogic.clearLine(-176, 0, -90, -80) == false, "cannot see top lane through keep wall")
assert(VisionLogic.canSeeFrom(-176, 0, 120, -90, -80) == false, "radius is not enough to pierce walls")
assert(VisionLogic.clearLine(-130, -30, -176, 0) == false, "angled look into fountain hits the east wall")
assert(VisionLogic.clearLine(-88, -90, -88, -108) == true, "brush is not a solid wall")

local fountain = { x = -176, z = 0, radius = 54 }
local fountainMask = VisionLogic.mask({ fountain })
assert(VisionLogic.bitOn(fountainMask, VisionLogic.indexOf(-176, 0)) == true)
assert(VisionLogic.bitOn(fountainMask, VisionLogic.indexOf(-176, -40)) == false, "keep north wall hides cells behind it")
assert(VisionLogic.bitOn(fountainMask, VisionLogic.indexOf(-130, 0)) == true, "mid gate cells stay lit")

-- Match-lifetime fog memory: OR masks without wiping current vision.
local first = VisionLogic.emptyMask()
VisionLogic.orInto(first, mask)
assert(VisionLogic.bitOn(first, VisionLogic.indexOf(-90, -80)) == true, "orInto copies lit cells")
assert(VisionLogic.bitOn(first, VisionLogic.indexOf(90, 80)) == false)
local copy = VisionLogic.cloneMask(first)
assert(VisionLogic.bitOn(copy, VisionLogic.indexOf(-90, -80)) == true)
local towerIndex = VisionLogic.indexOf(-90, -80)
copy[math.floor((towerIndex - 1) / 32) + 1] = 0
assert(VisionLogic.bitOn(first, towerIndex) == true, "cloneMask is a copy")
VisionLogic.orInto(first, fountainMask)
assert(VisionLogic.bitOn(first, VisionLogic.indexOf(-176, 0)) == true, "memory keeps prior cells and adds new ones")
assert(VisionLogic.bitOn(first, VisionLogic.indexOf(-90, -80)) == true, "explored cells persist after another OR")

print("PASS: fog grid, packed mask, source radii, brush occludes, wall LoS, fog memory")
