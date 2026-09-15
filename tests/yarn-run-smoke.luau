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
assert(YarnRunCatalog.runnerTag("Shadowpounce") == "Shad")

assert(YarnBoardLogic.clipName("   ") == "Cat")
assert(YarnBoardLogic.clipName("abcdefghijklmnopqrstuvwxyz") == "abcdefghijklmnopqr")
assert(YarnBoardLogic.podiumTitle(1) == "#1 YARN LORD")
assert(YarnBoardLogic.podiumTitle(2) == "#2 YARN ACE")
assert(YarnBoardLogic.podiumTitle(3) == "#3 YARN CREW")
assert(YarnBoardLogic.podiumTitle(4) == nil)

local first = YarnBoardLogic.submit({}, {
	userId = 1, name = "Nyan", score = 100, meters = 40, championId = "NyanRocket", at = 1,
})
assert(first.improved and first.rank == 1)
local same = YarnBoardLogic.submit(first.entries, {
	userId = 1, name = "Nyan", score = 80, meters = 90, championId = "NyanRocket", at = 2,
})
assert(same.improved == false and same.entries[1].score == 100)
local beat = YarnBoardLogic.submit(same.entries, {
	userId = 1, name = "Nyan", score = 200, meters = 10, championId = "NyanRocket", at = 3,
})
assert(beat.improved and beat.entries[1].score == 200)
local rival = YarnBoardLogic.submit(beat.entries, {
	userId = 2, name = "Shad", score = 250, meters = 80, championId = "Shadowpounce", at = 4,
})
assert(rival.rank == 1)
assert(rival.entries[1].userId == 2)
assert(YarnBoardLogic.rankOf(rival.entries, 1) == 2)

local crowded = {}
for i = 1, 12 do
	crowded = YarnBoardLogic.submit(crowded, {
		userId = i, name = "Cat" .. i, score = i * 10, meters = i, championId = "NyanRocket", at = i,
	}).entries
end
assert(#crowded == YarnBoardLogic.TopN)
assert(crowded[1].score == 120)
assert(YarnBoardLogic.rankOf(crowded, 1) == nil)

assert(YarnRunCatalog.parseRunner("Shadowpounce") == "Shadowpounce")
assert(YarnRunCatalog.parseRunner("nope") == "NyanRocket")
assert(YarnRunCatalog.parseRunner(nil) == "NyanRocket")

local monday = YarnRunCatalog.weekStart(1_800_000_000)
assert(YarnRunCatalog.weekKey(monday) == YarnRunCatalog.weekKey(monday + 86400 * 6), "UTC week is stable Mon–Sun")
assert(YarnRunCatalog.weekKey(monday) ~= YarnRunCatalog.weekKey(monday + 86400 * 7), "Next Monday starts a new week")
assert(YarnRunCatalog.weekStart(monday + 100000) == monday)
assert(string.find(YarnRunCatalog.weekLabel(monday), "Week of", 1, true))

local bag = {}
for i = 1, 500 do
	table.insert(bag, { t = i, lane = i % 3, y = 1.26, z = i * 10 })
end
local capped = YarnRunCatalog.capSamples(bag)
assert(#capped <= YarnRunCatalog.GhostStoreCap, "Persisted ghost must stay under the DataStore cap")
assert(#capped >= 2)
assert(capped[1].z == YarnRunCatalog.packSample(bag[1]).z)
assert(capped[#capped].z == YarnRunCatalog.packSample(bag[#bag]).z)
local packed = YarnRunCatalog.packSample({ t = 1.234, lane = 1.4, y = 2.26, z = 40.04 })
assert(packed.lane == 1)
assert(packed.y == 2.3)
local tiny = YarnRunCatalog.capSamples({ bag[1], bag[2] })
assert(#tiny == 2)
assert(YarnRunCatalog.readSample({ t = 1, z = 8, lane = 2, y = 0 }))
assert(YarnRunCatalog.readSample("nope") == nil)

print("PASS: daily seed, new segments, power-ups, ghost interpolation")
print("PASS: daily board ranking, name clip, podium titles")
print("PASS: UTC week keys, ghost sample cap, runner parse")
