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

-- Last-seen ghosts freeze at the pose captured while visible. They are not a vision source.
assert(LastSeenGhostLogic.FadeSeconds >= 1 and LastSeenGhostLogic.FadeSeconds <= 3, "fade stays in the 1–3s band")
assert(LastSeenGhostLogic.FadeSeconds == 1.8, "documented fade is 1.8s")
assert(LastSeenGhostLogic.StartTransparency == 0.45)

local ghosts = LastSeenGhostLogic.newState()
local function poseAt(x: number, z: number, r00: number?): LastSeenGhostLogic.Pose
	return LastSeenGhostLogic.pose(x, 3, z, r00 or 1, 0, 0, 0, 1, 0, 0, 0, 1)
end

assert(LastSeenGhostLogic.lost(ghosts, "p:unseen", 0) == nil, "never-seen units do not ghost")

local moving = poseAt(12, -4, 0)
LastSeenGhostLogic.seen(ghosts, "p:9", moving)
moving.x = 99
moving.r00 = 0.25
local spawned = LastSeenGhostLogic.lost(ghosts, "p:9", 10)
assert(spawned ~= nil and spawned.x == 12 and spawned.z == -4 and spawned.r00 == 0, "ghost copies the last seen pose")
assert(LastSeenGhostLogic.lost(ghosts, "p:9", 10.4) == nil, "a second loss does not recapture")
local frozen = LastSeenGhostLogic.ghostOf(ghosts, "p:9")
assert(frozen ~= nil and frozen.x == 12 and frozen.r00 == 0, "ghost stays put after the live pose changes")

local kitten = poseAt(-30, 8)
LastSeenGhostLogic.seen(ghosts, "m:blue", kitten)
local camp = poseAt(70, 100, 0)
camp.r22 = 0
LastSeenGhostLogic.seen(ghosts, "j:YarnGolemSE", camp)
local kittenGhost = LastSeenGhostLogic.lost(ghosts, "m:blue", 10)
local campGhost = LastSeenGhostLogic.lost(ghosts, "j:YarnGolemSE", 10)
assert(kittenGhost ~= nil and kittenGhost.x == -30, "minion ghost uses its own last pose")
assert(campGhost ~= nil and campGhost.x == 70 and campGhost.r22 == 0, "camp ghost keeps facing")
assert(LastSeenGhostLogic.ghostOf(ghosts, "p:9").x == 12, "champion ghost is not moved by other units")

LastSeenGhostLogic.seen(ghosts, "p:9", poseAt(4, 5))
assert(LastSeenGhostLogic.ghostOf(ghosts, "p:9") == nil, "re-entering vision clears the ghost immediately")
local again = LastSeenGhostLogic.lost(ghosts, "p:9", 20)
assert(again ~= nil and again.x == 4 and again.z == 5, "the next loss uses the new last-seen pose")

local early = LastSeenGhostLogic.expireDue(ghosts, 10 + LastSeenGhostLogic.FadeSeconds)
local expiredKitten = false
local expiredChampionEarly = false
for _, key in early do
	if key == "m:blue" then
		expiredKitten = true
	elseif key == "p:9" then
		expiredChampionEarly = true
	end
end
assert(expiredKitten, "a minion ghost expires on its own clock")
assert(not expiredChampionEarly, "a newer champion ghost is not expired with the minion")
local champStill = LastSeenGhostLogic.ghostOf(ghosts, "p:9")
assert(champStill ~= nil and champStill.x == 4, "the champion ghost is still frozen at the new pose")

local due = LastSeenGhostLogic.expireDue(ghosts, 20 + LastSeenGhostLogic.FadeSeconds)
local foundChampion = false
for _, key in due do
	if key == "p:9" then
		foundChampion = true
	end
end
assert(foundChampion, "ghost expires once the fade elapses")
assert(LastSeenGhostLogic.ghostOf(ghosts, "p:9") == nil)
assert(LastSeenGhostLogic.lost(ghosts, "p:9", 30) == nil, "an expired ghost does not chase or respawn until seen again")

local half = LastSeenGhostLogic.FadeSeconds * 0.5
local mid = LastSeenGhostLogic.partTransparency(0, half)
local expectedMid = 0.45 + 0.55 * (0.5 * 0.5)
assert(math.abs(mid - expectedMid) < 1e-6, "fade holds longer, then drops")
assert(mid < 0.45 + 0.55 * 0.5, "halfway is still more solid than a linear fade")
assert(LastSeenGhostLogic.partTransparency(0, LastSeenGhostLogic.FadeSeconds) == 1)
assert(LastSeenGhostLogic.partTransparency(1, 0) == 1, "already invisible parts stay invisible")
local later = LastSeenGhostLogic.partTransparency(0, LastSeenGhostLogic.FadeSeconds * 0.9)
assert(later > mid and later < 1)

LastSeenGhostLogic.clear(ghosts)
assert(LastSeenGhostLogic.lost(ghosts, "m:blue", 40) == nil, "match end wipes ghost memory")
assert(LastSeenGhostLogic.ghostOf(ghosts, "j:YarnGolemSE") == nil)

print("PASS: fog grid, packed mask, source radii, brush occludes, wall LoS, fog memory, last-seen ghosts")
