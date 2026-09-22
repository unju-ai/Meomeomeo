-- Run through tools/test-jungle-bot.py against JungleBotLogic + VisionLogic.

local function brushes(): { JungleBotLogic.BrushBox }
	local list = {}
	for _, spec in VisionLogic.Brushes do
		table.insert(list, { x = spec.x, z = spec.z, sx = spec.sx, sz = spec.sz })
	end
	assert(#list == 6)
	return list
end

local BOXES = brushes()

local function deeplyInside(x: number, z: number): boolean
	for _, spec in VisionLogic.Brushes do
		local hx = spec.sx * 0.5 - 0.75
		local hz = spec.sz * 0.5 - 0.75
		if math.abs(x - spec.x) <= hx and math.abs(z - spec.z) <= hz then
			return true
		end
	end
	return false
end

local function camp(id: string, x: number, z: number, health: number, maxHealth: number): JungleBotLogic.CampView
	return { id = id, x = x, z = z, health = health, maxHealth = maxHealth }
end

local ALL = {
	camp("YarnGolemNW", -70, -100, 220, 220),
	camp("PigeonsNW", -100, -88, 95, 95),
	camp("YarnGolemSE", 70, 100, 220, 220),
	camp("PigeonsSE", 100, 88, 95, 95),
	camp("RiverCrabN", 0, -48, 150, 150),
	camp("RiverCrabS", 0, 48, 150, 150),
}

local function without(id: string, replacement: JungleBotLogic.CampView?): { JungleBotLogic.CampView }
	local list = {}
	for _, monster in ALL do
		if monster.id == id then
			if replacement then
				table.insert(list, replacement)
			end
		else
			table.insert(list, monster)
		end
	end
	return list
end

local function lane(name: string, z: number, waveX: number?, knownX: number?, knownZ: number?): JungleBotLogic.LaneView
	return {
		name = name,
		z = z,
		waveX = waveX,
		lastKnownX = knownX,
		lastKnownZ = knownZ,
	}
end

local OPEN_LANES = {
	lane("Top", -80, nil, nil, nil),
	lane("Mid", 0, nil, nil, nil),
	lane("Bot", 80, nil, nil, nil),
}

local function ask(partial: {
	difficulty: JungleBotLogic.Difficulty,
	team: JungleBotLogic.TeamId,
	jungler: boolean?,
	x: number,
	z: number,
	lanePushed: boolean?,
	campId: string?,
	routeIndex: number?,
	camps: { JungleBotLogic.CampView }?,
	enemy: JungleBotLogic.EnemyView?,
	lanes: { JungleBotLogic.LaneView }?,
}): JungleBotLogic.JungleDecision
	return JungleBotLogic.decide({
		difficulty = partial.difficulty,
		team = partial.team,
		jungler = if partial.jungler == nil then true else partial.jungler,
		x = partial.x,
		z = partial.z,
		lanePushed = partial.lanePushed == true,
		attackRange = 26,
		memory = { campId = partial.campId, routeIndex = partial.routeIndex or 1 },
		camps = partial.camps or ALL,
		enemy = partial.enemy,
		lanes = partial.lanes or OPEN_LANES,
		brushes = BOXES,
	})
end

-- Both routes together name every camp once. Crabs are shared.
local seen: { [string]: boolean } = {}
for _, id in JungleBotLogic.route("Blue") do
	seen[id] = true
end
for _, id in JungleBotLogic.route("Red") do
	seen[id] = true
end
local count = 0
for _ in seen do
	count += 1
end
assert(count == 6, "routes must cover the six camps")
assert(JungleBotLogic.route("Blue")[1] == "PigeonsNW")
assert(JungleBotLogic.route("Red")[1] == "PigeonsSE")
assert(JungleBotLogic.GankMemorySeconds == 8)

-- Easy never jungles, even if a caller marks them as the jungler.
local easy = ask({ difficulty = "Easy", team = "Red", x = 176, z = 0, lanePushed = true, jungler = true })
assert(easy.action == "lane", "Easy stays in lane")
assert(easy.memory.campId == nil)

local side = ask({ difficulty = "Hard", team = "Blue", x = 0, z = 0, jungler = false })
assert(side.action == "lane", "top and bot are not junglers")

-- Hard follows the route from the fountain, not the nearer river crab.
local opening = ask({ difficulty = "Hard", team = "Blue", x = -176, z = 0, lanePushed = false })
assert(opening.action == "camp")
assert(opening.campId == "PigeonsNW", "Hard opens on the pigeon pack")
assert(opening.memory.routeIndex == 1)

local redOpen = ask({ difficulty = "Hard", team = "Red", x = 176, z = 0, lanePushed = false })
assert(redOpen.campId == "PigeonsSE")

-- Dead first camp: skip ahead instead of idling.
local skipped = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -176,
	z = 0,
	camps = without("PigeonsNW", nil),
})
assert(skipped.campId == "YarnGolemNW")
assert(skipped.memory.routeIndex == 2)

-- Enemy quadrant is not a camp for this team.
local onlyEnemy = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 0,
	z = 0,
	camps = { camp("YarnGolemSE", 70, 100, 220, 220) },
	lanes = {
		lane("Top", -80, 10, nil, nil),
		lane("Mid", 0, 10, nil, nil),
		lane("Bot", 80, 40, nil, nil),
	},
})
assert(onlyEnemy.action == "rotate", "Blue does not invade the only enemy camp")
assert(onlyEnemy.z == 80, "rotate toward the pushed bot wave")

-- Started camp is finished. A close champion does not pull a low camp.
local finishing = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -70,
	z = -100,
	campId = "YarnGolemNW",
	routeIndex = 2,
	camps = without("YarnGolemNW", camp("YarnGolemNW", -70, -100, 50, 220)),
	enemy = { x = -60, z = -90 },
})
assert(finishing.action == "camp", "finish a camp under 40% before contesting")
assert(finishing.campId == "YarnGolemNW")

local contest = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -70,
	z = -100,
	campId = "YarnGolemNW",
	routeIndex = 2,
	camps = without("YarnGolemNW", camp("YarnGolemNW", -70, -100, 180, 220)),
	enemy = { x = -58, z = -88 },
})
assert(contest.action == "fight", "a close champion pulls a healthy camp")
assert(contest.memory.campId == "YarnGolemNW", "the camp is resumed after the fight")

local ignoreFar = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -70,
	z = -100,
	campId = "YarnGolemNW",
	routeIndex = 2,
	enemy = { x = -70, z = -55 },
})
assert(ignoreFar.action == "camp", "a champion outside contest range is not a reason to drop the camp")

-- Normal: nearest sticky camp, and only when the wave is pushed — unless the camp is already hurt.
local normalIdle = ask({ difficulty = "Normal", team = "Blue", x = 20, z = 0, lanePushed = false })
assert(normalIdle.action == "lane", "Normal does not leave an unpushed wave to jungle")

local normalStart = ask({ difficulty = "Normal", team = "Blue", x = 0, z = 0, lanePushed = true })
assert(normalStart.action == "camp")
assert(normalStart.campId == "RiverCrabN", "equidistant crabs break toward the route order")

local sticky = ask({
	difficulty = "Normal",
	team = "Blue",
	x = 0,
	z = 8,
	lanePushed = true,
	campId = "RiverCrabN",
	routeIndex = 3,
})
assert(sticky.campId == "RiverCrabN", "a slightly closer crab does not steal a started walk")

local switched = ask({
	difficulty = "Normal",
	team = "Blue",
	x = 0,
	z = 20,
	lanePushed = true,
	campId = "RiverCrabN",
	routeIndex = 3,
})
assert(switched.campId == "RiverCrabS", "a camp that is clearly closer wins")

local normalFinish = ask({
	difficulty = "Normal",
	team = "Blue",
	x = 0,
	z = -40,
	lanePushed = false,
	campId = "RiverCrabN",
	camps = without("RiverCrabN", camp("RiverCrabN", 0, -48, 40, 150)),
	enemy = { x = 8, z = -30 },
})
assert(normalFinish.action == "camp", "Normal finishes a hurt camp after the wave crashes back")

local normalBrawl = ask({
	difficulty = "Normal",
	team = "Blue",
	x = 0,
	z = -40,
	lanePushed = true,
	campId = "RiverCrabN",
	camps = without("RiverCrabN", camp("RiverCrabN", 0, -48, 140, 150)),
	enemy = { x = 6, z = -28 },
})
assert(normalBrawl.action == "fight")
assert(normalBrawl.memory.campId == "RiverCrabN")

-- After the route is down, Hard rotates to pressure instead of pacing the river.
local pushed = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 0,
	z = 0,
	camps = {},
	lanes = {
		lane("Top", -80, 15, nil, nil),
		lane("Mid", 0, 20, nil, nil),
		lane("Bot", 80, 70, nil, nil),
	},
})
assert(pushed.action == "rotate")
assert(pushed.z == 80 and pushed.x == 70, "join the furthest allied wave")

local gank = ask({
	difficulty = "Hard",
	team = "Red",
	x = 0,
	z = 0,
	camps = {},
	lanes = {
		lane("Top", -80, -80, nil, nil),
		lane("Mid", 0, -20, -10, 4),
		lane("Bot", 80, -30, nil, nil),
	},
})
assert(gank.action == "rotate")
assert(gank.z == 0, "a fresh last-known enemy outweighs a modest push")

local arrived = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 70,
	z = 80,
	camps = {},
	lanes = {
		lane("Top", -80, 15, nil, nil),
		lane("Mid", 0, 20, nil, nil),
		lane("Bot", 80, 70, nil, nil),
	},
})
assert(arrived.action == "lane", "arriving at the wave hands control back to lane combat")

-- Clearing a camp advances the route instead of restarting.
local cleared = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -100,
	z = -88,
	campId = "PigeonsNW",
	routeIndex = 1,
	camps = without("PigeonsNW", nil),
})
assert(cleared.campId == "YarnGolemNW")
assert(cleared.memory.routeIndex == 2)

-- Brush: cut around a pocket, walk straight when the line is open, leave a pocket you are already in.
local skirtX, skirtZ = JungleBotLogic.stepPoint(-50, -48, 0, -48, BOXES)
assert(not deeplyInside(skirtX, skirtZ), "skirt waypoint sits outside the crab brush")
assert(math.abs(skirtX) > 1 or math.abs(skirtZ + 48) > 1, "skirt does not walk through the brush")
local openX, openZ = JungleBotLogic.stepPoint(-176, 0, -100, -88, BOXES)
assert(openX == -100 and openZ == -88, "fountain to pigeons is already a clean line")
local insideX, insideZ = JungleBotLogic.stepPoint(-88, -108, -70, -100, BOXES)
assert(insideX == -70 and insideZ == -100, "already inside brush, walk straight out")

-- Walk the Hard opener. The camp id stays put, and the path does not sit in a pocket.
local x, z = -176, 0
local memory = { campId = nil :: string?, routeIndex = 1 }
local reached = false
for _ = 1, 24 do
	local decision = ask({
		difficulty = "Hard",
		team = "Blue",
		x = x,
		z = z,
		campId = memory.campId,
		routeIndex = memory.routeIndex,
	})
	assert(decision.action == "camp" and decision.campId == "PigeonsNW", "opener does not flip camps")
	local sx = decision.stepX or x
	local sz = decision.stepZ or z
	local dx, dz = sx - x, sz - z
	local mag = math.sqrt(dx * dx + dz * dz)
	if mag <= 26 then
		reached = true
		break
	end
	local step = math.min(18, mag)
	local nx = x + dx / mag * step
	local nz = z + dz / mag * step
	for sample = 1, 4 do
		local t = sample / 4
		assert(not deeplyInside(x + (nx - x) * t, z + (nz - z) * t), "opener path entered brush")
	end
	x, z = nx, nz
	memory = decision.memory
end
assert(reached, "Hard jungler reaches the pigeon pack")
assert(math.sqrt((x + 100) * (x + 100) + (z + 88) * (z + 88)) <= 30)

local function withEpic(list: { JungleBotLogic.CampView }, health: number?): { JungleBotLogic.CampView }
	local copy = {}
	for _, monster in list do
		table.insert(copy, monster)
	end
	local body = camp("CanalLevi", RiverEpic.X, RiverEpic.Z, health or RiverEpic.Health, RiverEpic.Health)
	body.epic = true
	table.insert(copy, body)
	return copy
end

-- Canal Levi is off the six-camp route. Hard may walk it when it is up.
local levi = ask({
	difficulty = "Hard",
	team = "Red",
	x = 70,
	z = 100,
	routeIndex = 3,
	camps = withEpic(ALL),
})
assert(levi.action == "camp" and levi.campId == "CanalLevi", "Hard mid paths to Canal Levi when it is up")
assert(levi.memory.routeIndex == 3, "the route index waits while they take the canal")

local finishFirst = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -70,
	z = -100,
	campId = "YarnGolemNW",
	routeIndex = 2,
	camps = withEpic(without("YarnGolemNW", camp("YarnGolemNW", -70, -100, 50, 220))),
})
assert(finishFirst.action == "camp" and finishFirst.campId == "YarnGolemNW", "a started camp is finished before the canal")

local afterClear = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -100,
	z = -88,
	campId = "PigeonsNW",
	routeIndex = 1,
	camps = withEpic(without("PigeonsNW", nil)),
})
assert(afterClear.campId == "CanalLevi")
assert(afterClear.memory.routeIndex == 2, "clearing pigeons still advances, then the canal")

local resume = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 0,
	z = 24,
	campId = "CanalLevi",
	routeIndex = 2,
	camps = without("PigeonsNW", nil),
})
assert(resume.campId == "YarnGolemNW", "after Levi the route resumes")
assert(resume.memory.routeIndex == 2)

local instead = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 0,
	z = 0,
	camps = withEpic({}),
	lanes = {
		lane("Top", -80, 15, nil, nil),
		lane("Mid", 0, 20, nil, nil),
		lane("Bot", 80, 70, nil, nil),
	},
})
assert(instead.action == "camp" and instead.campId == "CanalLevi", "an up Levi beats pacing the river")

local brawl = ask({
	difficulty = "Hard",
	team = "Red",
	x = 0,
	z = 24,
	camps = withEpic(ALL),
	enemy = { x = 8, z = 24 },
})
assert(brawl.action == "fight", "a cat in their face still comes before the canal")

local normalIgnore = ask({
	difficulty = "Normal",
	team = "Blue",
	x = 0,
	z = 20,
	lanePushed = true,
	camps = withEpic(ALL),
})
assert(normalIgnore.campId == "RiverCrabS", "Normal does not take Canal Levi")

local easyLevi = ask({
	difficulty = "Easy",
	team = "Red",
	x = 0,
	z = 24,
	lanePushed = true,
	jungler = true,
	camps = withEpic(ALL),
})
assert(easyLevi.action == "lane", "Easy ignores Canal Levi")

local laneBot = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 0,
	z = 24,
	jungler = false,
	camps = withEpic(ALL),
})
assert(laneBot.action == "lane", "top and bot do not path to Canal Levi")

assert(RiverEpic.wantsHardPath("Hard", true, true) == false)
assert(RiverEpic.wantsHardPath("Normal", true, false) == false)

-- HUD copy is pure. The client paints these strings; it does not pick the wake.
local opening = RiverEpic.hudRead(96, 0, "waiting", RiverEpic.dueAt(0, "waiting", nil))
assert(opening.clock == "1:36")
assert(opening.objective == "Levi 1:24")
local wokeLine = RiverEpic.hudRead(180, 0, "alive", RiverEpic.dueAt(0, "alive", nil))
assert(wokeLine.clock == "3:00" and wokeLine.objective == "Levi UP")
local downClock = RiverEpic.killed({
	phase = "alive",
	spawnsUsed = 1,
	respawnAt = nil,
}, 200)
assert(downClock.respawnAt == 290)
local respawnLine = RiverEpic.hudRead(243, 0, "returning", RiverEpic.dueAt(0, "returning", downClock.respawnAt))
assert(respawnLine.objective == "Levi 0:47")
local spentLine = RiverEpic.hudRead(400, 0, "spent", nil)
assert(spentLine.objective == "Levi taken" and spentLine.clock == "6:40")
assert(RiverEpic.purseLine("Blue", true, false) == "Canal Levi · +8% damage")
assert(RiverEpic.purseLine("Blue", false, true) == "Red holds Levi")

print("PASS: jungle route, commit, contest, rotate, brush skirt, canal levi")
