-- Run through tools/test-yarn.py against src/shared/YarnRunCatalog.luau.

local day = math.floor(1_800_000_000 / 86400) * 86400 + 100
assert(YarnRunCatalog.dailySeed(day) == YarnRunCatalog.dailySeed(day + 80000), "Seed must be stable for a UTC day")
assert(YarnRunCatalog.dailySeed(day) ~= YarnRunCatalog.dailySeed(day + 86400), "Next UTC day must change the layout")
assert(YarnRunCatalog.utcDay(day + 10) == YarnRunCatalog.utcDay(day))
assert(typeof(YarnRunCatalog.dayKey(day)) == "string")

assert(YarnRunCatalog.kindAt(1, 0) == "empty")
assert(YarnRunCatalog.kindAt(1, 1) == "empty")

local function countKind(seg, kind)
	local n = 0
	for _, obstacle in seg.obstacles do
		if obstacle.kind == kind then
			n += 1
		end
	end
	return n
end

local seen = {}
local powers = { speed = false, magnet = false, shield = false, double = false }
local rich = { zigzag = false, tunnel = false, gap = false, fountain = false, bridge = false, billboard = false, power = false }
for seed = 1, 40 do
	for index = 0, 40 do
		local kind = YarnRunCatalog.kindAt(seed, index)
		seen[kind] = true
		if rich[kind] == false then
			rich[kind] = true
		end
		local seg = YarnRunCatalog.segment(seed, index)
		if kind == "zigzag" then
			assert(countKind(seg, "dog") >= 2, "Zig-zag needs two dogs")
			assert(seg.obstacles[1].lane ~= seg.obstacles[2].lane, "Zig-zag dogs must change lanes")
		elseif kind == "tunnel" then
			assert(countKind(seg, "sign") == 3, "Laundry tunnel covers every lane")
		elseif kind == "gap" then
			assert(countKind(seg, "roomba") == 1 and countKind(seg, "dog") == 3, "Roomba jump gap")
		elseif kind == "fountain" then
			assert(countKind(seg, "yarn") >= 3, "Yarn fountain")
		elseif kind == "bridge" then
			assert(countKind(seg, "wall") >= 4, "Narrow bridge rails")
		elseif kind == "billboard" then
			assert(countKind(seg, "wall") >= 1, "Billboard dodge")
		end
		for _, obstacle in seg.obstacles do
			if powers[obstacle.kind] == false then
				powers[obstacle.kind] = true
			end
		end
	end
end
for name, ok in rich do
	assert(ok, "Missing segment " .. name)
end
for name, ok in powers do
	assert(ok, "Missing power-up " .. name)
end

local samples = {
	{ t = 0, lane = 0, y = 0, z = 0 },
	{ t = 1, lane = 2, y = 4, z = 40 },
}
local mid = YarnRunCatalog.ghostAt(samples, 0.5)
assert(mid and mid.z > 15 and mid.z < 25, "Ghost must interpolate along the PB path")
assert(YarnRunCatalog.ghostAt(samples, 8).z == 40, "Ghost holds the PB finish")
assert(YarnRunCatalog.isPickup("speed") and YarnRunCatalog.isLethal("wall"))
assert(YarnRunCatalog.pickupLabel("double") == "2X YARN")
assert(YarnRunCatalog.pickupLabel("shield") == "SHIELD UP")

print("PASS: daily seed, new segments, power-ups, ghost interpolation")
