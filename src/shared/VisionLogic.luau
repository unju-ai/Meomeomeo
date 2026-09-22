--!strict

-- Server-authoritative fog grid, jungle brush, and mesh line-of-sight.
-- Keep walls and thick cover are eye-height occlusion volumes. Clients only render the mask.
-- MeshParts / wedges on the same LoS layer are not hard-blocked as boxes; VisionService raycasts those.

local VisionLogic = {}

VisionLogic.MinX = -210
VisionLogic.MaxX = 210
VisionLogic.MinZ = -140
VisionLogic.MaxZ = 140
-- 10-stud cells: 42 x 28 = 1176. Divides MapBounds evenly; ~1.7x the old 14-stud grid.
VisionLogic.CellSize = 10
VisionLogic.Cols = 42
VisionLogic.Rows = 28
VisionLogic.CellCount = 1176
VisionLogic.WordCount = 37
VisionLogic.LaneHalf = 10
VisionLogic.LaneZ = { -80, 0, 80 }

-- Horizontal ray used for every vision sample. Short curbs and overhead signs miss it.
VisionLogic.EyeHeight = 3.5
-- Keep walls are 4 studs thick. Thinner props (pillars, lanterns, ears) must not occlude.
VisionLogic.MinBlockThickness = 3.5
-- Keep-wall parts are authored at this height (MapBuilder). Bottom sits on the ground.
VisionLogic.WallY = 5
VisionLogic.WallHeight = 10

export type BrushSpec = {
	name: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
}

export type WallSpec = {
	name: string,
	x: number,
	z: number,
	sx: number,
	sz: number,
}

export type CoverSpec = {
	name: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
}

export type BlockerShape = "box" | "ball" | "cylinder" | "mesh"

export type Blocker = {
	name: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	shape: BlockerShape,
}

export type Source = {
	x: number,
	z: number,
	radius: number,
}

-- Gameplay AABBs. Kept off the 16-stud lane corridors (lane exclusion is a second guard).
VisionLogic.Brushes = {
	{ name = "BrushNW", x = -88, y = 3.2, z = -108, sx = 22, sy = 7, sz = 16 },
	{ name = "BrushNE", x = -48, y = 3.2, z = -98, sx = 16, sy = 6, sz = 14 },
	{ name = "BrushSE", x = 88, y = 3.2, z = 108, sx = 22, sy = 7, sz = 16 },
	{ name = "BrushSW", x = 48, y = 3.2, z = 98, sx = 16, sy = 6, sz = 14 },
	{ name = "BrushCrabN", x = -22, y = 2.8, z = -48, sx = 12, sy = 5, sz = 10 },
	{ name = "BrushCrabS", x = 22, y = 2.8, z = 48, sx = 12, sy = 5, sz = 10 },
} :: { BrushSpec }

-- Thin keep walls with a mid-lane gate. Not brush — these block vision segments.
VisionLogic.Walls = {
	{ name = "BlueBack", x = -194, z = 0, sx = 4, sz = 48 },
	{ name = "BlueNorth", x = -170, z = -24, sx = 48, sz = 4 },
	{ name = "BlueSouth", x = -170, z = 24, sx = 48, sz = 4 },
	{ name = "BlueEastN", x = -146, z = -17, sx = 4, sz = 14 },
	{ name = "BlueEastS", x = -146, z = 17, sx = 4, sz = 14 },
	{ name = "RedBack", x = 194, z = 0, sx = 4, sz = 48 },
	{ name = "RedNorth", x = 170, z = -24, sx = 48, sz = 4 },
	{ name = "RedSouth", x = 170, z = 24, sx = 48, sz = 4 },
	{ name = "RedWestN", x = 146, z = -17, sx = 4, sz = 14 },
	{ name = "RedWestS", x = 146, z = 17, sx = 4, sz = 14 },
} :: { WallSpec }

-- Upright market drums between the lanes. Diameter is sx/sz; height is sy.
-- Off the 16-stud lane corridors and off the river so they read as cover, not gates.
VisionLogic.Cover = {
	{ name = "CoverNW", x = -36, y = 4, z = -48, sx = 6, sy = 8, sz = 6 },
	{ name = "CoverNE", x = 36, y = 4, z = -48, sx = 6, sy = 8, sz = 6 },
	{ name = "CoverSW", x = -36, y = 4, z = 48, sx = 6, sy = 8, sz = 6 },
	{ name = "CoverSE", x = 36, y = 4, z = 48, sx = 6, sy = 8, sz = 6 },
} :: { CoverSpec }

local overrideBlockers: { Blocker }? = nil
local builtinBlockers: { Blocker }? = nil
-- Returns true when a raycast (or a test double) says the eye segment hits a mesh.
local meshProbe: ((number, number, number, number) -> boolean)? = nil

local function onLane(z: number): boolean
	for _, laneZ in VisionLogic.LaneZ do
		if math.abs(z - laneZ) <= VisionLogic.LaneHalf then
			return true
		end
	end
	return false
end

function VisionLogic.brushAt(x: number, z: number): string?
	if onLane(z) then
		return nil
	end
	for _, spec in VisionLogic.Brushes do
		local hx = spec.sx * 0.5
		local hz = spec.sz * 0.5
		if x >= spec.x - hx and x <= spec.x + hx and z >= spec.z - hz and z <= spec.z + hz then
			return spec.name
		end
	end
	return nil
end

function VisionLogic.qualifies(sx: number, sy: number, sz: number, y: number): boolean
	if sx <= 0 or sy <= 0 or sz <= 0 then
		return false
	end
	if math.min(sx, sz) < VisionLogic.MinBlockThickness then
		return false
	end
	local bottom = y - sy * 0.5
	local top = y + sy * 0.5
	return bottom <= VisionLogic.EyeHeight and top >= VisionLogic.EyeHeight
end

function VisionLogic.blockerFromExtents(
	name: string,
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	shape: BlockerShape
): Blocker?
	if not VisionLogic.qualifies(sx, sy, sz, y) then
		return nil
	end
	return {
		name = name,
		x = x,
		y = y,
		z = z,
		sx = sx,
		sy = sy,
		sz = sz,
		shape = shape,
	}
end

-- Local part size + basis → world extents and a shape the eye query understands.
-- kind matches BasePart.Shape.Name, or "Mesh" for MeshPart. Look is Roblox LookVector (−Z).
function VisionLogic.worldExtents(
	sizeX: number,
	sizeY: number,
	sizeZ: number,
	rightX: number,
	rightY: number,
	rightZ: number,
	upX: number,
	upY: number,
	upZ: number,
	lookX: number,
	lookY: number,
	lookZ: number,
	kind: string
): (number, number, number, BlockerShape)
	if kind == "Ball" then
		return sizeX, sizeY, sizeZ, "ball"
	end
	if kind == "Cylinder" and math.abs(rightY) >= 0.99 then
		local diameter = math.max(sizeY, sizeZ)
		return diameter, sizeX, diameter, "cylinder"
	end
	local sx = math.abs(rightX) * sizeX + math.abs(upX) * sizeY + math.abs(lookX) * sizeZ
	local sy = math.abs(rightY) * sizeX + math.abs(upY) * sizeY + math.abs(lookY) * sizeZ
	local sz = math.abs(rightZ) * sizeX + math.abs(upZ) * sizeY + math.abs(lookZ) * sizeZ
	local upright = math.abs(upY) >= 0.99
	local axis = upright and (math.abs(rightX) >= 0.99 or math.abs(rightZ) >= 0.99)
	if kind == "Block" and axis then
		return sx, sy, sz, "box"
	end
	return sx, sy, sz, "mesh"
end

local function segmentHitsAabb(ax: number, az: number, bx: number, bz: number, spec: WallSpec): boolean
	local minX = spec.x - spec.sx * 0.5
	local maxX = spec.x + spec.sx * 0.5
	local minZ = spec.z - spec.sz * 0.5
	local maxZ = spec.z + spec.sz * 0.5
	local dx = bx - ax
	local dz = bz - az
	local tmin = 0
	local tmax = 1
	if math.abs(dx) < 1e-8 then
		if ax < minX or ax > maxX then
			return false
		end
	else
		local ood = 1 / dx
		local t1 = (minX - ax) * ood
		local t2 = (maxX - ax) * ood
		if t1 > t2 then
			t1, t2 = t2, t1
		end
		tmin = math.max(tmin, t1)
		tmax = math.min(tmax, t2)
		if tmin > tmax then
			return false
		end
	end
	if math.abs(dz) < 1e-8 then
		if az < minZ or az > maxZ then
			return false
		end
	else
		local ood = 1 / dz
		local t1 = (minZ - az) * ood
		local t2 = (maxZ - az) * ood
		if t1 > t2 then
			t1, t2 = t2, t1
		end
		tmin = math.max(tmin, t1)
		tmax = math.min(tmax, t2)
		if tmin > tmax then
			return false
		end
	end
	return tmin <= tmax
end

local function crossesEye(blocker: Blocker): boolean
	local bottom = blocker.y - blocker.sy * 0.5
	local top = blocker.y + blocker.sy * 0.5
	local eye = VisionLogic.EyeHeight
	return eye >= bottom and eye <= top
end

local function segmentHitsCircle(ax: number, az: number, bx: number, bz: number, cx: number, cz: number, radius: number): boolean
	local abx = bx - ax
	local abz = bz - az
	local acx = cx - ax
	local acz = cz - az
	local ab2 = abx * abx + abz * abz
	if ab2 < 1e-8 then
		return acx * acx + acz * acz <= radius * radius
	end
	local t = math.clamp((acx * abx + acz * abz) / ab2, 0, 1)
	local px = ax + abx * t - cx
	local pz = az + abz * t - cz
	return px * px + pz * pz <= radius * radius
end

local function segmentHitsBox(ax: number, az: number, bx: number, bz: number, blocker: Blocker): boolean
	if not crossesEye(blocker) then
		return false
	end
	return segmentHitsAabb(ax, az, bx, bz, {
		name = blocker.name,
		x = blocker.x,
		z = blocker.z,
		sx = blocker.sx,
		sz = blocker.sz,
	})
end

local function segmentHitsCylinder(ax: number, az: number, bx: number, bz: number, blocker: Blocker): boolean
	if not crossesEye(blocker) then
		return false
	end
	local radius = math.min(blocker.sx, blocker.sz) * 0.5
	return segmentHitsCircle(ax, az, bx, bz, blocker.x, blocker.z, radius)
end

local function segmentHitsBall(ax: number, az: number, bx: number, bz: number, blocker: Blocker): boolean
	local rx = blocker.sx * 0.5
	local ry = blocker.sy * 0.5
	local rz = blocker.sz * 0.5
	if rx < 1e-4 or ry < 1e-4 or rz < 1e-4 then
		return false
	end
	local dy = (VisionLogic.EyeHeight - blocker.y) / ry
	if dy <= -1 or dy >= 1 then
		return false
	end
	local scale = math.sqrt(1 - dy * dy)
	local hx = rx * scale
	local hz = rz * scale
	if hx < 1e-4 or hz < 1e-4 then
		return false
	end
	local zScale = hx / hz
	return segmentHitsCircle(ax, az * zScale, bx, bz * zScale, blocker.x, blocker.z * zScale, hx)
end

function VisionLogic.hitsBlocker(sx: number, sz: number, tx: number, tz: number, blocker: Blocker): boolean
	if blocker.shape == "mesh" then
		return false
	end
	if not VisionLogic.qualifies(blocker.sx, blocker.sy, blocker.sz, blocker.y) then
		return false
	end
	if blocker.shape == "ball" then
		return segmentHitsBall(sx, sz, tx, tz, blocker)
	end
	if blocker.shape == "cylinder" then
		return segmentHitsCylinder(sx, sz, tx, tz, blocker)
	end
	return segmentHitsBox(sx, sz, tx, tz, blocker)
end

-- Broadphase for a mesh: the eye segment meets its world box. Corners are not a hard block.
function VisionLogic.hitsMesh(sx: number, sz: number, tx: number, tz: number, blocker: Blocker): boolean
	if blocker.shape ~= "mesh" then
		return false
	end
	if not VisionLogic.qualifies(blocker.sx, blocker.sy, blocker.sz, blocker.y) then
		return false
	end
	return segmentHitsBox(sx, sz, tx, tz, blocker)
end

function VisionLogic.blockedBy(sx: number, sz: number, tx: number, tz: number, blockers: { Blocker }): boolean
	for _, blocker in blockers do
		if VisionLogic.hitsBlocker(sx, sz, tx, tz, blocker) then
			return true
		end
	end
	return false
end

function VisionLogic.meshAlong(sx: number, sz: number, tx: number, tz: number, blockers: { Blocker }): boolean
	for _, blocker in blockers do
		if VisionLogic.hitsMesh(sx, sz, tx, tz, blocker) then
			return true
		end
	end
	return false
end

local function builtin(): { Blocker }
	if builtinBlockers then
		return builtinBlockers
	end
	local list: { Blocker } = {}
	for _, wall in VisionLogic.Walls do
		local blocker = VisionLogic.blockerFromExtents(
			wall.name,
			wall.sx,
			VisionLogic.WallHeight,
			wall.sz,
			wall.x,
			VisionLogic.WallY,
			wall.z,
			"box"
		)
		if blocker then
			table.insert(list, blocker)
		end
	end
	for _, cover in VisionLogic.Cover do
		local blocker = VisionLogic.blockerFromExtents(cover.name, cover.sx, cover.sy, cover.sz, cover.x, cover.y, cover.z, "cylinder")
		if blocker then
			table.insert(list, blocker)
		end
	end
	builtinBlockers = list
	return list
end

function VisionLogic.activeBlockers(): { Blocker }
	if overrideBlockers then
		return overrideBlockers
	end
	return builtin()
end

-- nil restores the authored walls + cover. Used when the map's tagged parts are harvested.
function VisionLogic.setBlockers(list: { Blocker }?)
	overrideBlockers = list
end

-- nil clears the raycast hook. A true result blocks; false does not open an analytical hit.
function VisionLogic.setMeshProbe(probe: ((number, number, number, number) -> boolean)?)
	meshProbe = probe
end

function VisionLogic.clearLine(sx: number, sz: number, tx: number, tz: number): boolean
	local blockers = VisionLogic.activeBlockers()
	if VisionLogic.blockedBy(sx, sz, tx, tz, blockers) then
		return false
	end
	local probe = meshProbe
	if probe ~= nil and probe(sx, sz, tx, tz) then
		return false
	end
	return true
end

-- Earliest parametric t in [0, 1] where the segment meets a vision wall / thick cover / mesh.
-- nil means the segment is clear (same solids as clearLine). Used by traveling skillshots.
function VisionLogic.wallHitT(sx: number, sz: number, tx: number, tz: number): number?
	if VisionLogic.clearLine(sx, sz, tx, tz) then
		return nil
	end
	local dx = tx - sx
	local dz = tz - sz
	if dx * dx + dz * dz < 1e-8 then
		return 0
	end
	local lo = 0
	local hi = 1
	for _ = 1, 14 do
		local mid = (lo + hi) * 0.5
		local mx = sx + dx * mid
		local mz = sz + dz * mid
		if VisionLogic.clearLine(sx, sz, mx, mz) then
			lo = mid
		else
			hi = mid
		end
	end
	return hi
end

function VisionLogic.canSeeFrom(sx: number, sz: number, radius: number, tx: number, tz: number): boolean
	local dx = tx - sx
	local dz = tz - sz
	if dx * dx + dz * dz > radius * radius then
		return false
	end
	if not VisionLogic.clearLine(sx, sz, tx, tz) then
		return false
	end
	local targetBrush = VisionLogic.brushAt(tx, tz)
	if targetBrush == nil then
		return true
	end
	return VisionLogic.brushAt(sx, sz) == targetBrush
end

function VisionLogic.covered(sources: { Source }, x: number, z: number): boolean
	for _, source in sources do
		if VisionLogic.canSeeFrom(source.x, source.z, source.radius, x, z) then
			return true
		end
	end
	return false
end

function VisionLogic.indexOf(x: number, z: number): number
	local col = math.clamp(math.floor((x - VisionLogic.MinX) / VisionLogic.CellSize), 0, VisionLogic.Cols - 1)
	local row = math.clamp(math.floor((z - VisionLogic.MinZ) / VisionLogic.CellSize), 0, VisionLogic.Rows - 1)
	return row * VisionLogic.Cols + col + 1
end

function VisionLogic.center(index: number): (number, number)
	local i = math.clamp(index, 1, VisionLogic.CellCount) - 1
	local col = i % VisionLogic.Cols
	local row = math.floor(i / VisionLogic.Cols)
	return VisionLogic.MinX + (col + 0.5) * VisionLogic.CellSize, VisionLogic.MinZ + (row + 0.5) * VisionLogic.CellSize
end

function VisionLogic.pack(flags: { boolean }): { number }
	local words = table.create(VisionLogic.WordCount, 0)
	for i = 1, VisionLogic.WordCount do
		words[i] = 0
	end
	for i = 1, VisionLogic.CellCount do
		if flags[i] then
			local wordIndex = math.floor((i - 1) / 32) + 1
			local bit = (i - 1) % 32
			words[wordIndex] = bit32.bor(words[wordIndex], bit32.lshift(1, bit))
		end
	end
	return words
end

function VisionLogic.bitOn(words: { number }, index: number): boolean
	if index < 1 or index > VisionLogic.CellCount then
		return false
	end
	local word = words[math.floor((index - 1) / 32) + 1]
	if typeof(word) ~= "number" then
		return false
	end
	local bit = (index - 1) % 32
	return bit32.band(word, bit32.lshift(1, bit)) ~= 0
end

function VisionLogic.emptyMask(): { number }
	return table.create(VisionLogic.WordCount, 0)
end

function VisionLogic.cloneMask(words: { number }): { number }
	local out = table.create(VisionLogic.WordCount, 0)
	for i = 1, VisionLogic.WordCount do
		out[i] = words[i] or 0
	end
	return out
end

-- Match-lifetime fog memory: OR src into dest (same WordCount packed bitset).
function VisionLogic.orInto(dest: { number }, src: { number })
	for i = 1, VisionLogic.WordCount do
		dest[i] = bit32.bor(dest[i] or 0, src[i] or 0)
	end
end

function VisionLogic.paint(sources: { Source }): { boolean }
	local flags = table.create(VisionLogic.CellCount, false)
	for i = 1, VisionLogic.CellCount do
		flags[i] = false
	end
	local minX = VisionLogic.MinX
	local minZ = VisionLogic.MinZ
	local cell = VisionLogic.CellSize
	local cols = VisionLogic.Cols
	local rows = VisionLogic.Rows
	for _, source in sources do
		local r = source.radius
		local c0 = math.clamp(math.floor((source.x - r - minX) / cell), 0, cols - 1)
		local c1 = math.clamp(math.floor((source.x + r - minX) / cell), 0, cols - 1)
		local r0 = math.clamp(math.floor((source.z - r - minZ) / cell), 0, rows - 1)
		local r1 = math.clamp(math.floor((source.z + r - minZ) / cell), 0, rows - 1)
		for row = r0, r1 do
			for col = c0, c1 do
				local idx = row * cols + col + 1
				if not flags[idx] then
					local cx, cz = VisionLogic.center(idx)
					if VisionLogic.canSeeFrom(source.x, source.z, source.radius, cx, cz) then
						flags[idx] = true
					end
				end
			end
		end
	end
	return flags
end

function VisionLogic.mask(sources: { Source }): { number }
	return VisionLogic.pack(VisionLogic.paint(sources))
end

return VisionLogic
