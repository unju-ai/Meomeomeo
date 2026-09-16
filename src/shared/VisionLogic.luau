--!strict

-- Server-authoritative fog grid + jungle brush. Clients only render the mask.

local VisionLogic = {}

VisionLogic.MinX = -210
VisionLogic.MaxX = 210
VisionLogic.MinZ = -140
VisionLogic.MaxZ = 140
VisionLogic.CellSize = 14
VisionLogic.Cols = 30
VisionLogic.Rows = 20
VisionLogic.CellCount = 600
VisionLogic.WordCount = 19
VisionLogic.LaneHalf = 10
VisionLogic.LaneZ = { -80, 0, 80 }

export type BrushSpec = {
	name: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
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

function VisionLogic.canSeeFrom(sx: number, sz: number, radius: number, tx: number, tz: number): boolean
	local dx = tx - sx
	local dz = tz - sz
	if dx * dx + dz * dz > radius * radius then
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
