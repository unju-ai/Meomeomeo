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
assert(YarnRunCatalog.powerChipLabel("speed") == "SPD")
assert(YarnRunCatalog.powerChipLabel("magnet") == "MAG")
assert(YarnRunCatalog.powerChipLabel("shield") == "SHD")
assert(YarnRunCatalog.powerChipLabel("double") == "2X")
local sr, sg, sb = YarnRunCatalog.powerRgb("speed")
assert(sr == 90 and sg == 220 and sb == 255)
assert(YarnRunCatalog.isPowerEvent("SPEED BURST") == "speed")
assert(YarnRunCatalog.isPowerEvent("MAGNET ON") == "magnet")
assert(YarnRunCatalog.isPowerEvent("SHIELD UP") == "shield")
assert(YarnRunCatalog.isPowerEvent("SHIELD POP") == "shield")
assert(YarnRunCatalog.isPowerEvent("2X YARN") == "double")
assert(YarnRunCatalog.isPowerEvent("CLOSE!") == nil)
assert(YarnRunCatalog.pbCompareLine(900, 120, 500, 80, true) == "NEW PB  900  ·  was 500 / 80m")
assert(YarnRunCatalog.pbCompareLine(400, 50, 500, 80, false) == "PB  500 / 80m  ·  this 400 (-100)")
assert(YarnRunCatalog.pbCompareLine(10, 4, 0, 0, false) == "PB  —  ·  this run 10 / 4m")
assert(YarnRunCatalog.deathRankLine(1, 4, true) == "Daily podium  #1   ·   Weekly #4")
assert(YarnRunCatalog.deathRankLine(nil, nil, false) == "Daily —   ·   Weekly —")
assert(string.find(YarnRunCatalog.deathRecapLine(120, 3, 8, 40), "best combo x8", 1, true))
assert(YarnRunCatalog.runnerTag("Shadowpounce") == "Shad")

assert(YarnBoardLogic.clipName("   ") == "Cat")
assert(YarnBoardLogic.clipName("abcdefghijklmnopqrstuvwxyz") == "abcdefghijklmnopqr")
assert(YarnBoardLogic.AnonName == "Anonymous Cat")
assert(YarnBoardLogic.visibleName("Nyan", true) == "Anonymous Cat")
assert(YarnBoardLogic.visibleName("Nyan", false) == "Nyan")
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

assert(StallBoardLogic.AnonName == "Anonymous Cat")
assert(StallBoardLogic.clipName("abcdefghijklmnopqrstuvwxyz") == "abcdefghijklmnopqr")
assert(StallBoardLogic.visibleName("Loaf", true) == "Anonymous Cat")
assert(StallBoardLogic.clipDetail("") == "—")
local koiFirst = StallBoardLogic.submit({}, {
	userId = 1, name = "Nyan", score = 40, detail = "Rare · Peach Koi", at = 1, anon = false,
})
assert(koiFirst.improved and koiFirst.rank == 1)
local koiSame = StallBoardLogic.submit(koiFirst.entries, {
	userId = 1, name = "Nyan", score = 20, detail = "Common · Cream Loaf", at = 2, anon = true,
})
assert(koiSame.improved == false and koiSame.entries[1].score == 40)
local koiBeat = StallBoardLogic.submit(koiSame.entries, {
	userId = 1, name = "Nyan", score = 90, detail = "Legendary · Canal Crown", at = 3, anon = true,
})
assert(koiBeat.improved and koiBeat.entries[1].detail == "Legendary · Canal Crown")
assert(koiBeat.entries[1].anon == true)
local bust = StallBoardLogic.submit({}, {
	userId = 8, name = "Tape", score = -12, detail = "-12 yarn", at = 1,
})
assert(bust.rank == 1 and bust.entries[1].score == -12)
local worseBust = StallBoardLogic.submit(bust.entries, {
	userId = 8, name = "Tape", score = -30, detail = "-30 yarn", at = 2,
})
assert(worseBust.improved == false and worseBust.entries[1].score == -12)
local boom = StallBoardLogic.submit(worseBust.entries, {
	userId = 9, name = "Moon", score = 25, detail = "+25 yarn", at = 3,
})
assert(boom.rank == 1 and boom.entries[2].score == -12)
local packedBoard = {}
for i = 1, 12 do
	packedBoard = StallBoardLogic.submit(packedBoard, {
		userId = i, name = "Cat" .. i, score = i, detail = "Catch", at = i,
	}).entries
end
assert(#packedBoard == StallBoardLogic.TopN)
assert(StallBoardLogic.rankOf(packedBoard, 1) == nil)

print("PASS: daily seed, new segments, power-ups, ghost interpolation")
print("PASS: daily board ranking, name clip, podium titles, Anonymous Cat")
print("PASS: UTC week keys, ghost sample cap, runner parse")
print("PASS: power chip RGB / labels, death PB + rank lines")
print("PASS: stall boards rank koi catches and negative arcade profit")
