-- Run through tools/test-vision.py against VisionLogic.

assert(VisionLogic.Cols * VisionLogic.CellSize == VisionLogic.MaxX - VisionLogic.MinX)
assert(VisionLogic.Rows * VisionLogic.CellSize == VisionLogic.MaxZ - VisionLogic.MinZ)
assert(VisionLogic.CellCount == VisionLogic.Cols * VisionLogic.Rows)
assert(#VisionLogic.Brushes == 6)
assert(#VisionLogic.Walls == 10)
assert(#VisionLogic.Cover == 4)
assert(VisionLogic.CellSize == 10)
assert(VisionLogic.EyeHeight > 2 and VisionLogic.EyeHeight < 6)
assert(VisionLogic.MinBlockThickness >= 3 and VisionLogic.MinBlockThickness <= 4)

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

-- Mesh LoS: eye-height volumes. Thick drums block; thin props, curbs, and overhead signs do not.
assert(#VisionLogic.activeBlockers() == #VisionLogic.Walls + #VisionLogic.Cover)
for _, cover in VisionLogic.Cover do
	assert(VisionLogic.brushAt(cover.x, cover.z) == nil, "cover is not brush")
	assert(math.abs(cover.x) >= 20, "cover stays off the river")
	local onLane = false
	for _, laneZ in VisionLogic.LaneZ do
		if math.abs(cover.z - laneZ) <= VisionLogic.LaneHalf + 2 then
			onLane = true
		end
	end
	assert(onLane == false, "cover stays off the lanes")
end
assert(VisionLogic.blockerFromExtents("Lantern", 1.1, 8, 1.1, 0, 4, 0, "box") == nil, "thin props do not occlude")
assert(VisionLogic.blockerFromExtents("Curb", 12, 1.2, 8, 0, 0.4, 0, "box") == nil, "short curbs stay under the eye ray")
assert(VisionLogic.blockerFromExtents("Sign", 8, 3, 6, 0, 12, 0, "box") == nil, "overhead signs do not occlude")
local thinPole = { name = "Pole", x = 0, y = 4, z = 0, sx = 1.2, sy = 8, sz = 1.2, shape = "box" }
assert(VisionLogic.hitsBlocker(-8, 0, 8, 0, thinPole) == false, "a tagged thin pole still fails the thickness rule")

assert(VisionLogic.clearLine(-36, -60, -36, -36) == false, "a ray through a market drum is blocked")
assert(VisionLogic.clearLine(-28, -48, -20, -48) == true, "the gap beside a drum stays open")
assert(VisionLogic.clearLine(-38.9, -50.8, -38.5, -50.6) == true, "drum corners are round, not a square pocket")
assert(VisionLogic.covered({ { x = -36, z = -70, radius = 54 } }, -36, -30) == false, "a champion cannot see through cover")
assert(VisionLogic.covered({ { x = -36, z = -70, radius = 40 } }, -20, -70) == true, "open ground beside cover stays visible")

local pink = { x = -36, z = -70, radius = 48 }
local pinkMask = VisionLogic.mask({ pink })
assert(VisionLogic.bitOn(pinkMask, VisionLogic.indexOf(-36, -70)) == true, "pink lights its own cell")
assert(VisionLogic.bitOn(pinkMask, VisionLogic.indexOf(-36, -30)) == false, "pink bubble does not light through a drum")

local crystal = VisionLogic.blockerFromExtents("Crystal", 14, 18, 14, 0, 10, 0, "ball")
assert(crystal ~= nil, "a thick ball that crosses the eye plane qualifies")
assert(VisionLogic.hitsBlocker(-10, 0, 10, 0, crystal) == true, "eye ray through the ball is blocked")
assert(VisionLogic.hitsBlocker(-10, 8, 10, 8, crystal) == false, "a ray beside the ball's eye slice is clear")

local wsx, wsy, wsz, wshape = VisionLogic.worldExtents(4, 10, 48, 1, 0, 0, 0, 1, 0, 0, 0, -1, "Block")
assert(wshape == "box" and wsx == 4 and wsy == 10 and wsz == 48, "axis-aligned walls keep their size")
wsx, wsy, wsz, wshape = VisionLogic.worldExtents(48, 10, 4, 0, 0, -1, 0, 1, 0, -1, 0, 0, "Block")
assert(wshape == "box" and math.abs(wsx - 4) < 1e-4 and wsy == 10 and math.abs(wsz - 48) < 1e-4, "yawed walls swap X/Z")
wsx, wsy, wsz, wshape = VisionLogic.worldExtents(8, 6, 6, 0, 1, 0, -1, 0, 0, 0, 0, -1, "Cylinder")
assert(wshape == "cylinder" and wsx == 6 and wsy == 8 and wsz == 6, "upright cylinders use diameter and height")
wsx, wsy, wsz, wshape = VisionLogic.worldExtents(8, 8, 8, 1, 0, 0, 0, 1, 0, 0, 0, -1, "Mesh")
assert(wshape == "mesh" and wsx == 8 and wsy == 8 and wsz == 8, "mesh parts stay on the raycast path")
wsx, wsy, wsz, wshape = VisionLogic.worldExtents(8, 8, 4, 0.7, 0, 0.7, 0, 1, 0, -0.7, 0, 0.7, "Block")
assert(wshape == "mesh", "tilted blocks are not treated as full squares")

local stall = VisionLogic.blockerFromExtents("StallMesh", 8, 8, 8, 0, 4, 80, "mesh")
assert(stall ~= nil)
assert(VisionLogic.hitsBlocker(-5, 80, 5, 80, stall) == false, "a mesh AABB is not a hard block")
assert(VisionLogic.hitsMesh(-5, 80, 5, 80, stall) == true, "the mesh broadphase still sees the segment")
assert(VisionLogic.hitsMesh(-5, 70, 5, 70, stall) == false)
VisionLogic.setBlockers({ stall })
local probes = 0
VisionLogic.setMeshProbe(function(sx, sz, tx, tz)
	probes += 1
	if not VisionLogic.meshAlong(sx, sz, tx, tz, VisionLogic.activeBlockers()) then
		return false
	end
	return math.abs((sz + tz) * 0.5 - 80) < 0.6
end)
assert(VisionLogic.clearLine(-6, 80, 6, 80) == false, "a ray through the mesh core is blocked")
assert(VisionLogic.clearLine(-3.6, 83.6, -3.2, 83.4) == true, "mesh corners do not paint an unfair pocket")
assert(probes >= 1, "the mesh probe runs when a segment meets the volume")
VisionLogic.setBlockers(nil)
VisionLogic.setMeshProbe(function()
	return false
end)
assert(VisionLogic.clearLine(-176, 0, -90, -80) == false, "a clear probe does not open keep walls")
assert(VisionLogic.clearLine(-36, -60, -36, -36) == false, "a clear probe does not open thick cover")
VisionLogic.setMeshProbe(nil)
local only = VisionLogic.blockerFromExtents("Temp", 6, 8, 6, 0, 4, 20, "cylinder")
assert(only ~= nil)
VisionLogic.setBlockers({ only })
assert(VisionLogic.clearLine(-176, 0, -90, -80) == true, "an override replaces the authored walls")
assert(VisionLogic.clearLine(0, 10, 0, 30) == false, "the override cylinder blocks its own ray")
VisionLogic.setBlockers(nil)
assert(VisionLogic.clearLine(-176, 0, -90, -80) == false, "clearing the override restores keep walls")
assert(VisionLogic.clearLine(-10, 20, 10, 20) == true, "open ground is clear again")

-- Skillshot wall clips reuse the same solids as LoS (keep walls, drums; not brush / thin props).
assert(VisionLogic.wallHitT(-176, 0, -120, 0) == nil, "mid gate stays open for bolts")
assert(VisionLogic.wallHitT(-88, -90, -88, -108) == nil, "brush does not stop a bolt")
local keepT = VisionLogic.wallHitT(-176, 0, -90, -80)
assert(keepT ~= nil and keepT > 0.05 and keepT < 0.95, "a bolt into the keep finds the wall face")
local drumT = VisionLogic.wallHitT(-36, -60, -36, -36)
assert(drumT ~= nil and drumT > 0.1 and drumT < 0.9, "a bolt into a market drum stops on cover")
assert(VisionLogic.wallHitT(-28, -48, -20, -48) == nil, "the gap beside a drum stays open for bolts")
assert(VisionLogic.wallHitT(-8, 0, 8, 0) == nil, "open mid is clear for bolts")

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

-- Minimap fog cell paint: explored stays lighter than unexplored (client only).
local unRgb, unA = MinimapPaint.fogCell(false)
local exRgb, exA = MinimapPaint.fogCell(true)
assert(exA > unA, "explored minimap fog is more transparent than unexplored")
assert(exRgb[1] + exRgb[2] + exRgb[3] > unRgb[1] + unRgb[2] + unRgb[3], "explored RGB is lighter")

-- Champion plate fog gate mirrors AA refuse (pure helpers; paint is client-side).
assert(ChampionPlate.show({ alive = true, ally = false, inVision = false }) == false)
assert(ChampionPlate.show({ alive = true, ally = true, inVision = false }) == true)
assert(ChampionPlate.show({ alive = true, ally = false, inVision = true }) == true)
assert(ChampionPlate.nameLine("Nyan Rocket", true, false) == "Nyan Rocket (Bot)")

-- Brush juice reads the same pockets. It does not open them or change a radius.
assert(BrushJuice.modeAllows("Moba", "InProgress") == true)
assert(BrushJuice.modeAllows("Moba", "Lobby") == false)
assert(BrushJuice.modeAllows("Moba", "ChampionSelect") == false)
assert(BrushJuice.modeAllows("Moba", "Ended") == false)
assert(BrushJuice.modeAllows("Hub", "InProgress") == false)
assert(BrushJuice.modeAllows("YarnRun", "InProgress") == false)
assert(BrushJuice.modeAllows("KoiPond", "InProgress") == false)
assert(BrushJuice.modeAllows("YarnParty", "InProgress") == false)
assert(BrushJuice.modeAllows("MemeArcade", "InProgress") == false)

assert(BrushJuice.pocket(0, 0) == nil, "mid lane is not a brush wash")
assert(BrushJuice.pocket(-90, -80) == nil, "lane corridor stays open")
for _, spec in VisionLogic.Brushes do
	assert(BrushJuice.pocket(spec.x, spec.z) == spec.name, "juice pocket matches the authored brush")
	assert(BrushJuice.pocket(spec.x, spec.z) == VisionLogic.brushAt(spec.x, spec.z))
end
assert(BrushJuice.LeafCount <= 4, "enter is a few leaves, not a storm")

assert(BrushJuice.edge(nil, nil) == "none")
assert(BrushJuice.edge(nil, "BrushNW") == "enter")
assert(BrushJuice.edge("BrushNW", "BrushNW") == "stay")
assert(BrushJuice.edge("BrushNW", nil) == "leave")
assert(BrushJuice.edge("BrushNW", "BrushNE") == "enter")

assert(BrushJuice.cueKind(1, 1, true, false) == "local")
assert(BrushJuice.cueKind(1, 2, true, true) == "ally")
assert(BrushJuice.cueKind(1, 2, true, false) == "none", "a hidden ally is not marked")
assert(BrushJuice.cueKind(1, 3, false, true) == "none", "a visible enemy in brush is not marked")
assert(BrushJuice.cueKind(1, 3, false, false) == "none")
assert(BrushJuice.shouldPaint("local") == true)
assert(BrushJuice.shouldPaint("ally") == true)
assert(BrushJuice.shouldPaint("none") == false)
assert(BrushJuice.wantsVignette("local", "enter") == true)
assert(BrushJuice.wantsVignette("local", "leave") == true)
assert(BrushJuice.wantsVignette("ally", "enter") == false)
assert(BrushJuice.wantsHush("local", "enter") == true)
assert(BrushJuice.wantsHush("local", "leave") == false)
assert(BrushJuice.wantsHush("ally", "enter") == false)
assert(BrushJuice.wantsLeaves("ally", "enter") == false)
assert(BrushJuice.tint("leave")[1] > 240, "leave fades cream")
assert(BrushJuice.tint("enter")[2] > BrushJuice.tint("enter")[1], "enter is mint")
assert(BrushJuice.washTransparency("ally", "stay") > BrushJuice.washTransparency("local", "stay"))
assert(BrushJuice.vignettePeak("stay") > BrushJuice.vignettePeak("enter"))
assert(BrushJuice.vignettePeak("enter") >= 0.8, "enter darken stays subtle")

local brushWatch = BrushJuice.blank()
local brushNext, brushEdge, brushPocket, brushBurst = BrushJuice.observe(brushWatch, "m1", -88, -108, true, 10)
assert(brushEdge == "enter" and brushPocket == "BrushNW" and brushBurst == true)
assert(brushWatch.pocket == nil, "observe does not mutate the previous watch")
brushNext, brushEdge, brushPocket, brushBurst = BrushJuice.observe(brushNext, "m1", -88, -107, true, 10.05)
assert(brushEdge == "stay" and brushPocket == "BrushNW" and brushBurst == false)
brushNext, brushEdge, brushPocket, brushBurst = BrushJuice.observe(brushNext, "m1", 0, 0, true, 10.1)
assert(brushEdge == "leave" and brushPocket == nil and brushBurst == false, "a flutter does not replay the burst")
brushNext, brushEdge, brushPocket, brushBurst = BrushJuice.observe(brushNext, "m1", -88, -108, true, 10.1 + BrushJuice.EdgeGap)
assert(brushEdge == "enter" and brushBurst == true, "a real re-entry plays again")

local heldBrush = brushNext
local clearedBrush, leftBrush = BrushJuice.observe(heldBrush, "m1", -88, -108, false, 30)
assert(leftBrush == "leave" and clearedBrush.pocket == nil, "leaving the rift clears a held pocket")
local quietBrush, quietEdge = BrushJuice.observe(clearedBrush, "m1", -88, -108, false, 31)
assert(quietEdge == "none")
local swappedBrush, swappedEdge = BrushJuice.observe(heldBrush, "m2", 0, 0, true, 40)
assert(swappedEdge == "none" and swappedBrush.pocket == nil, "a new match does not fake a leave")
assert(VisionLogic.canSeeFrom(-88, -90, 54, -88, -108) == false, "brush juice does not open the pocket")
assert(VisionLogic.brushAt(-88, -108) == "BrushNW")

print("PASS: fog grid, packed mask, source radii, brush occludes, wall LoS, mesh cover, fog memory, last-seen ghosts, minimap fog tint, champion plate fog, brush juice")
