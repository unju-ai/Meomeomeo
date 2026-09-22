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
	peel: JungleBotLogic.PeelHint?,
	siege: JungleBotLogic.SiegeHint?,
	finish: JungleBotLogic.FinishHint?,
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
		peel = partial.peel,
		siege = partial.siege,
		finish = partial.finish,
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

-- Canal Levi is off the six-camp route. Hard mid contests it when UP — even over
-- leftover route camps. A started (hurt / in-range) camp still finishes first.
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

local leftover = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -100,
	z = -88,
	campId = "PigeonsNW",
	routeIndex = 1,
	camps = withEpic(ALL),
})
assert(leftover.action == "camp" and leftover.campId == "CanalLevi", "Levi beats leftover healthy route camps")
assert(leftover.memory.routeIndex == 1, "abandoning a leftover walk does not advance the route")

local openerLevi = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -176,
	z = 0,
	lanePushed = false,
	camps = withEpic(ALL),
})
assert(openerLevi.campId == "CanalLevi", "Hard mid leaves the opener for Levi when UP")

local finishFirst = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -70,
	z = -100,
	campId = "YarnGolemNW",
	routeIndex = 2,
	camps = withEpic(without("YarnGolemNW", camp("YarnGolemNW", -70, -100, 50, 220))),
})
assert(finishFirst.action == "camp" and finishFirst.campId == "YarnGolemNW", "a hurt camp is finished before the canal")

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

local peel = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 12,
	z = 24,
	camps = withEpic(ALL),
	enemy = { x = 4, z = 24 },
})
assert(peel.action == "fight" and peel.campId == "CanalLevi", "a visible enemy on Levi is contested")

local walkContest = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -80,
	z = -40,
	camps = withEpic(ALL),
	enemy = { x = 2, z = 24 },
})
assert(walkContest.action == "camp" and walkContest.campId == "CanalLevi", "a far visible enemy on Levi still pulls a Hard walk")

-- Normal mid only tags along when already in the canal pocket. Far Normal stays on camps.
local normalAssist = ask({
	difficulty = "Normal",
	team = "Blue",
	x = 0,
	z = 20,
	lanePushed = true,
	camps = withEpic(ALL),
})
assert(normalAssist.campId == "CanalLevi", "Normal mid already mid-river may assist Levi")

local normalFar = ask({
	difficulty = "Normal",
	team = "Blue",
	x = -100,
	z = -88,
	lanePushed = true,
	camps = withEpic(ALL),
})
assert(normalFar.campId == "PigeonsNW", "far Normal still ignores Canal Levi")

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
assert(RiverEpic.wantsHardPath("Hard", true, false) == true)
assert(RiverEpic.wantsHardPath("Normal", true, false) == false)
assert(RiverEpic.wantsNormalAssist("Normal", true, 0, 20) == true)
assert(RiverEpic.wantsNormalAssist("Normal", true, -100, -88) == false)
assert(RiverEpic.wantsNormalAssist("Easy", true, 0, 24) == false)
assert(RiverEpic.wantsNormalAssist("Hard", true, 0, 24) == false)

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

-- Take juice reads the same buff flags. It does not change Hard-mid priority or the +8%.
assert(RiverEpic.DamageAmp == 1.08 and RiverEpic.SpawnSeconds == 180 and RiverEpic.Lives == 2)
assert(RiverEpicJuice.pitX() == RiverEpic.X and RiverEpicJuice.pitZ() == RiverEpic.Z)
assert(RiverEpicJuice.takeTeam("alive", "returning", false, false, true, false) == "Blue")
assert(RiverEpicJuice.takeTeam("alive", "spent", true, false, true, true) == "Red")
assert(RiverEpicJuice.takeTeam("alive", "spent", true, false, true, false) == "Blue")
assert(RiverEpicJuice.tint("Blue")[1] == RiverEpicJuice.Cream[1])
assert(RiverEpicJuice.tint("Red")[1] == RiverEpicJuice.Coral[1])
assert(RiverEpicJuice.shouldPaintTake(true, false, false) == true)
assert(RiverEpicJuice.shouldPaintTake(false, false, false) == false)
assert(RiverEpicJuice.holds("Blue", true, false) == true)
assert(RiverEpic.wantsHardPath("Hard", true, false) == true)
assert(RiverEpic.wantsHardPath("Hard", true, true) == false)
assert(RiverEpicJuice.wantsFloat("local") == false)
assert(RiverEpicJuice.lossLine(true, false, true) == nil)

-- Camp chips format an existing stamp. They do not pick gold or a new duration.
assert(RiverEpic.RespawnSeconds == 90, "Levi's return stays 90s")
assert(CampRespawnJuice.Gold == nil and CampRespawnJuice.RespawnSeconds == nil)
assert(CampRespawnJuice.chipRead(CampRespawnJuice.remaining(132, 100)) == "32s")
assert(CampRespawnJuice.chipRead(CampRespawnJuice.remaining(145, 100)) == "45s")
assert(CampRespawnJuice.chipRead(CampRespawnJuice.remaining(150, 100)) == "50s")
assert(CampRespawnJuice.chipRead(0.2) == "1s")
assert(CampRespawnJuice.chipRead(0) == "0s")
assert(CampRespawnJuice.shouldPaint("PigeonsNW", 132, 100, true) == true)
assert(CampRespawnJuice.shouldPaint("PigeonsNW", 132, 100, false) == false)
assert(CampRespawnJuice.shouldPaint("YarnGolemNW", 145, 100, true) == true)
assert(CampRespawnJuice.shouldPaint("RiverCrabS", 150, 100, true) == true)
assert(CampRespawnJuice.shouldPaint("CanalLevi", 290, 100, true) == false)
assert(CampRespawnJuice.justReturned(true, 132, 132) == true)
assert(CampRespawnJuice.justReturned(true, 132, 131.6) == true, "a sliver before the stamp still puffs")
assert(CampRespawnJuice.justReturned(true, 132, 131) == false)
assert(CampRespawnJuice.justReturned(true, 132, 100) == false)
assert(CampRespawnJuice.justReturned(false, 132, 140) == false)
local pigeonPainted = { PigeonsNW = 132 }
assert(#CampRespawnJuice.puffIds(pigeonPainted, {
	{ id = "PigeonsNW", name = "Pigeon Pack", x = -100, y = 2.4, z = -88, respawnAt = 132 },
}, 120) == 0)
local popped = CampRespawnJuice.puffIds(pigeonPainted, {}, 132)
assert(#popped == 1 and popped[1] == "PigeonsNW", "reaching the stamp puffs once")
assert(#CampRespawnJuice.puffIds(pigeonPainted, {}, 120) == 0, "dropping a still-waiting row does not puff")
assert(CampRespawnJuice.modeAllows("Moba", "InProgress") == true)
assert(CampRespawnJuice.modeAllows("Hub", "InProgress") == false)

-- Bought Control Yarn plants beside these map spots. It does not add a jungle goal.
local yarnSpots = BotShopLogic.visionSpots()
local function hasSpot(kind: string, x: number, z: number): boolean
	for _, spot in yarnSpots do
		if spot.kind == kind and spot.x == x and spot.z == z then
			return true
		end
	end
	return false
end
local brushN: VisionLogic.BrushSpec? = nil
local brushS: VisionLogic.BrushSpec? = nil
for _, spec in VisionLogic.Brushes do
	if spec.name == "BrushCrabN" then
		brushN = spec
	elseif spec.name == "BrushCrabS" then
		brushS = spec
	end
end
assert(brushN ~= nil and brushS ~= nil)
assert(hasSpot("river-brush", (brushN :: any).x, (brushN :: any).z))
assert(hasSpot("river-brush", (brushS :: any).x, (brushS :: any).z))
assert(hasSpot("canal", RiverEpic.X, RiverEpic.Z))
assert(hasSpot("objective", 0, -48) and hasSpot("objective", 0, 48))

local placeRange = 28
local openPosts: { BotShopLogic.Post } = {}
local northX, northZ, northKind = BotShopLogic.controlDestination(0, -48, placeRange, yarnSpots, openPosts)
assert(northKind == "river-brush" and northX == (brushN :: any).x and northZ == (brushN :: any).z)
local leviX, leviZ, leviKind = BotShopLogic.controlDestination(RiverEpic.X, RiverEpic.Z, placeRange, yarnSpots, openPosts)
assert(leviKind == "canal" and leviX == RiverEpic.X and leviZ == RiverEpic.Z)
local underPost = BotShopLogic.controlDestination(70, 0, placeRange, yarnSpots, { { x = 90, z = 0, range = 44 } })
assert(underPost == nil)
assert(BotShopLogic.shouldPlaceControl("Hard", true, true, northX ~= nil) == true)
assert(BotShopLogic.shouldPlaceControl("Easy", true, true, true) == false)
assert(BotShopLogic.shouldPlaceControl("Normal", true, true, true) == false)
assert(BotShopLogic.chargeReady(true, 0, 5) == false)
assert(BotShopLogic.releaseWardLatch(true, true, false) == false)

-- Hard ally peel. Callers already applied fog. Easy and Normal never peel.
local function cat(id: number, x: number, z: number, hp: number, alive: boolean?): BotPeelLogic.Cat
	return {
		userId = id,
		x = x,
		z = z,
		hpRatio = hp,
		alive = if alive == nil then true else alive,
	}
end

local function peelPick(partial: {
	difficulty: BotPeelLogic.Difficulty?,
	x: number?,
	z: number?,
	selfHp: number?,
	retreatHp: number?,
	unsafeDive: boolean?,
	allies: { BotPeelLogic.Cat }?,
	enemies: { BotPeelLogic.Cat }?,
}): BotPeelLogic.PeelGoal?
	return BotPeelLogic.pick({
		difficulty = partial.difficulty or "Hard",
		selfUserId = 1,
		x = partial.x or 0,
		z = partial.z or 0,
		selfHp = if partial.selfHp == nil then 1 else partial.selfHp,
		retreatHp = if partial.retreatHp == nil then 0.16 else partial.retreatHp,
		unsafeDive = partial.unsafeDive == true,
		allies = partial.allies or {},
		enemies = partial.enemies or {},
	})
end

assert(BotPeelLogic.AllyHp == 0.38 and BotPeelLogic.CriticalHp == 0.22)
assert(BotPeelLogic.FightRadius == 32 and BotPeelLogic.NearbyRadius == 48)

local lowAlly = { cat(2, 20, 0, 0.37) }
local onThem = { cat(9, 40, 0, 1) }
assert(peelPick({ difficulty = "Easy", allies = lowAlly, enemies = onThem }) == nil, "Easy does not peel")
assert(peelPick({ difficulty = "Normal", allies = lowAlly, enemies = onThem }) == nil, "Normal does not peel")
assert(peelPick({ allies = { cat(2, 20, 0, 0.39) }, enemies = onThem }) == nil, "39% is not low enough")
assert(peelPick({ allies = { cat(2, 0, 0, 0.3) }, enemies = { cat(9, 33, 0, 1) } }) == nil, "enemy outside the fight radius")
assert(peelPick({ allies = { cat(2, 0, 0, 0) }, enemies = onThem }) == nil, "a downed ally is not a peel")
assert(peelPick({ allies = { cat(2, 0, 0, 0.2, false) }, enemies = onThem }) == nil)
assert(peelPick({ selfHp = 0.16, allies = lowAlly, enemies = onThem }) == nil, "fleeing bot does not peel")
assert(peelPick({ unsafeDive = true, allies = lowAlly, enemies = onThem }) == nil, "unsafe dive does not peel")

local turned = peelPick({ allies = { cat(2, 10, 0, 0.38) }, enemies = { cat(9, 42, 0, 1) } })
assert(turned ~= nil and turned.enemyUserId == 9 and turned.x == 42, "38% ally with an enemy on them peels")
assert(turned.critical == false and turned.nearby == true)

local threat = peelPick({
	allies = { cat(2, 10, 0, 0.3) },
	enemies = { cat(8, 10, 30, 1), cat(7, 12, 4, 1) },
})
assert(threat ~= nil and threat.enemyUserId == 7, "the enemy closer to the ally is the target")

local worse = peelPick({
	x = 0,
	z = 0,
	allies = { cat(2, 40, 0, 0.3), cat(3, 10, 0, 0.2) },
	enemies = { cat(8, 40, 10, 1), cat(7, 10, 8, 1) },
})
assert(worse ~= nil and worse.allyUserId == 3 and worse.critical == true, "the lower ally wins")

local farCrit = peelPick({
	allies = { cat(2, 49, 0, 0.22) },
	enemies = { cat(9, 49, 10, 1) },
})
assert(farCrit ~= nil and farCrit.critical == true and farCrit.nearby == false, "critical but not nearby")

local hint = {
	x = -150,
	z = 8,
	critical = false,
	nearby = true,
	enemyUserId = 9,
}

local dropCamp = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -100,
	z = -88,
	campId = "PigeonsNW",
	routeIndex = 1,
	peel = hint,
})
assert(dropCamp.action == "peel" and dropCamp.focusUserId == 9, "peel beats a leftover camp")
assert(dropCamp.memory.campId == "PigeonsNW" and dropCamp.memory.routeIndex == 1, "the route waits")

local softHunt = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -70,
	z = -100,
	campId = "YarnGolemNW",
	routeIndex = 2,
	enemy = { x = -58, z = -88 },
	peel = { x = -40, z = -70, critical = false, nearby = true, enemyUserId = 6 },
})
assert(softHunt.action == "peel", "peel breaks a soft hunt on a full-HP camp")

local hurtFirst = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -70,
	z = -100,
	campId = "YarnGolemNW",
	routeIndex = 2,
	camps = without("YarnGolemNW", camp("YarnGolemNW", -70, -100, 50, 220)),
	peel = { x = -40, z = -80, critical = true, nearby = true, enemyUserId = 3 },
})
assert(hurtFirst.action == "camp" and hurtFirst.campId == "YarnGolemNW", "a hurt camp still finishes before peel")

local leviHolds = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -100,
	z = -88,
	campId = "PigeonsNW",
	routeIndex = 1,
	camps = withEpic(ALL),
	peel = { x = -90, z = -70, critical = false, nearby = true, enemyUserId = 8 },
})
assert(leviHolds.action == "camp" and leviHolds.campId == "CanalLevi", "a normal peel does not take Levi")

local leviFar = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -80,
	z = -40,
	camps = withEpic(ALL),
	peel = { x = 80, z = 80, critical = true, nearby = false, enemyUserId = 8 },
})
assert(leviFar.campId == "CanalLevi", "a far critical ally does not take Levi")

local leviTurns = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 0,
	z = 24,
	campId = "CanalLevi",
	routeIndex = 2,
	camps = withEpic(ALL),
	peel = { x = 12, z = 24, critical = true, nearby = true, enemyUserId = 8 },
})
assert(leviTurns.action == "peel" and leviTurns.focusUserId == 8, "critical nearby peel interrupts Levi")
assert(leviTurns.memory.campId == "CanalLevi", "Levi is resumed after the peel")

local laneTurn = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 40,
	z = 80,
	jungler = false,
	peel = { x = 48, z = 80, critical = false, nearby = true, enemyUserId = 4 },
})
assert(laneTurn.action == "peel" and laneTurn.focusUserId == 4, "a lane bot peels instead of shoving")

local easyHint = ask({
	difficulty = "Easy",
	team = "Red",
	x = 0,
	z = 0,
	jungler = true,
	peel = hint,
})
assert(easyHint.action == "lane", "Easy ignores a peel hint")

local normalHint = ask({
	difficulty = "Normal",
	team = "Blue",
	x = 0,
	z = 0,
	lanePushed = true,
	peel = hint,
})
assert(normalHint.action ~= "peel", "Normal ignores a peel hint")

local peelRotate = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 0,
	z = 0,
	camps = {},
	lanes = OPEN_LANES,
	peel = hint,
})
assert(peelRotate.action == "peel", "peel beats an idle rotate")

-- Hard siege. Callers already counted kittens under each post. Easy and Normal never siege.
local function post(partial: {
	id: string?,
	x: number?,
	z: number?,
	health: number?,
	maxHealth: number?,
	vulnerable: boolean?,
	kind: BotSiegeLogic.Kind?,
	tier: BotSiegeLogic.Tier?,
	allyKittens: number?,
	enemyKittens: number?,
	focused: boolean?,
}): BotSiegeLogic.StructureView
	return {
		id = partial.id or "RedMidOuter",
		x = if partial.x == nil then 90 else partial.x,
		z = if partial.z == nil then 0 else partial.z,
		health = partial.health or 1400,
		maxHealth = partial.maxHealth or 1400,
		vulnerable = if partial.vulnerable == nil then true else partial.vulnerable,
		kind = partial.kind or "Tower",
		tier = partial.tier or "Outer",
		allyKittens = partial.allyKittens or 0,
		enemyKittens = partial.enemyKittens or 0,
		focused = partial.focused == true,
	}
end

local function siegePick(partial: {
	difficulty: BotSiegeLogic.Difficulty?,
	x: number?,
	z: number?,
	selfHp: number?,
	retreatHp: number?,
	peelCritical: boolean?,
	structures: { BotSiegeLogic.StructureView }?,
}): BotSiegeLogic.SiegeGoal?
	return BotSiegeLogic.pick({
		difficulty = partial.difficulty or "Hard",
		x = if partial.x == nil then 40 else partial.x,
		z = if partial.z == nil then 0 else partial.z,
		selfHp = if partial.selfHp == nil then 1 else partial.selfHp,
		retreatHp = if partial.retreatHp == nil then 0.16 else partial.retreatHp,
		peelCritical = partial.peelCritical == true,
		structures = partial.structures or {},
	})
end

assert(BotSiegeLogic.Range == 100 and BotSiegeLogic.MinKittens == 2 and BotSiegeLogic.LowRatio == 0.5)

local wave = post({ allyKittens = 2 })
assert(siegePick({ difficulty = "Easy", structures = { wave } }) == nil, "Easy does not siege")
assert(siegePick({ difficulty = "Normal", structures = { wave } }) == nil, "Normal does not siege")
local joined = siegePick({ structures = { wave } })
assert(joined ~= nil and joined.id == "RedMidOuter" and joined.tier == "Outer", "two kittens on a healthy post")
assert(siegePick({ structures = { post({ allyKittens = 2, enemyKittens = 2 }) } }) == nil, "a tied wave is not a crash")
assert(siegePick({ structures = { post({ allyKittens = 1 }) } }) == nil, "one kitten on a full post stays back")
assert(siegePick({ structures = { post({ allyKittens = 0, focused = true, health = 400 }) } }) == nil, "an empty post is not a walk")
assert(siegePick({ structures = { post({ allyKittens = 1, focused = true }) } }) ~= nil, "one kitten on a focused post")
assert(siegePick({ structures = { post({ allyKittens = 1, health = 700 }) } }) ~= nil, "one kitten on a low post")
assert(siegePick({ structures = { post({ allyKittens = 1, health = 701 }) } }) == nil, "just above half still needs two kittens")
assert(siegePick({ structures = { post({ allyKittens = 3, vulnerable = false }) } }) == nil, "a gated stall stays closed")
assert(siegePick({ structures = { post({ allyKittens = 3, kind = "Nexus", tier = "Core", id = "RedNexus" }) } }) == nil, "the yarn core is not a siege")
local stall = siegePick({ structures = { post({ id = "RedMidInner", tier = "Inner", x = 132, allyKittens = 2 }) } })
assert(stall ~= nil and stall.id == "RedMidInner" and stall.tier == "Inner", "an open stall with a wave")
assert(siegePick({ x = -20, structures = { wave } }) == nil, "too far to join")
assert(siegePick({ selfHp = 0.16, structures = { wave } }) == nil, "fleeing bot does not siege")
assert(siegePick({ peelCritical = true, structures = { wave } }) == nil, "a critical peel is not a siege")

local nearer = siegePick({
	x = 40,
	z = 0,
	structures = {
		post({ id = "RedBotOuter", x = 90, z = 80, allyKittens = 2 }),
		post({ id = "RedMidOuter", x = 90, z = 0, allyKittens = 2 }),
	},
})
assert(nearer ~= nil and nearer.id == "RedMidOuter", "the nearer post wins")

local lower = siegePick({
	x = 0,
	z = 0,
	structures = {
		post({ id = "RedTopOuter", x = 70, z = 0, health = 1400, allyKittens = 2 }),
		post({ id = "RedBotOuter", x = -70, z = 0, health = 400, allyKittens = 1, focused = true }),
	},
})
assert(lower ~= nil and lower.id == "RedBotOuter", "the same distance prefers the lower post")

local siegeHint = { id = "RedMidOuter", x = 90, z = 0 }

local dropFarm = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 40,
	z = 0,
	campId = "PigeonsNW",
	routeIndex = 1,
	siege = siegeHint,
})
assert(dropFarm.action == "siege" and dropFarm.objectiveId == "RedMidOuter", "siege beats a full-HP camp")
assert(dropFarm.memory.campId == "PigeonsNW" and dropFarm.memory.routeIndex == 1, "the route waits")

local hurtHolds = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -70,
	z = -100,
	campId = "YarnGolemNW",
	routeIndex = 2,
	camps = without("YarnGolemNW", camp("YarnGolemNW", -70, -100, 50, 220)),
	siege = siegeHint,
})
assert(hurtHolds.action == "camp" and hurtHolds.campId == "YarnGolemNW", "a hurt camp still finishes before siege")

local peelBeatsSiege = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 40,
	z = 0,
	campId = "PigeonsNW",
	peel = hint,
	siege = siegeHint,
})
assert(peelBeatsSiege.action == "peel" and peelBeatsSiege.focusUserId == 9, "peel beats siege")

local leviBeatsSiege = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -100,
	z = -88,
	campId = "PigeonsNW",
	routeIndex = 1,
	camps = withEpic(ALL),
	siege = siegeHint,
})
assert(leviBeatsSiege.action == "camp" and leviBeatsSiege.campId == "CanalLevi", "Levi beats siege")

local leviStillPeels = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 0,
	z = 24,
	campId = "CanalLevi",
	routeIndex = 2,
	camps = withEpic(ALL),
	peel = { x = 12, z = 24, critical = true, nearby = true, enemyUserId = 8 },
	siege = siegeHint,
})
assert(leviStillPeels.action == "peel" and leviStillPeels.focusUserId == 8, "critical nearby peel still interrupts Levi")

local faceBeatsSiege = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 40,
	z = 0,
	enemy = { x = 55, z = 0 },
	camps = {},
	siege = siegeHint,
})
assert(faceBeatsSiege.action == "fight", "a cat in face range beats siege")

local siegeRotate = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 10,
	z = 0,
	camps = {},
	lanes = OPEN_LANES,
	siege = siegeHint,
})
assert(siegeRotate.action == "siege", "siege beats an idle rotate")

local laneSiege = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 50,
	z = 80,
	jungler = false,
	siege = { id = "RedBotOuter", x = 90, z = 80 },
})
assert(laneSiege.action == "siege" and laneSiege.objectiveId == "RedBotOuter", "a lane bot hits the post")

local lanePeelSiege = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 40,
	z = 80,
	jungler = false,
	peel = { x = 48, z = 80, critical = false, nearby = true, enemyUserId = 4 },
	siege = siegeHint,
})
assert(lanePeelSiege.action == "peel", "a lane bot peels before sieging")

local easySiege = ask({
	difficulty = "Easy",
	team = "Red",
	x = 40,
	z = 0,
	jungler = true,
	siege = siegeHint,
})
assert(easySiege.action == "lane", "Easy ignores a siege hint")

local normalSiege = ask({
	difficulty = "Normal",
	team = "Blue",
	x = 40,
	z = 0,
	lanePushed = true,
	siege = siegeHint,
})
assert(normalSiege.action ~= "siege", "Normal ignores a siege hint")

-- Hard finish. Callers already scored HP, range, and dive. Easy and Normal never finish-hunt.
local function foe(id: number, x: number, z: number, hp: number, diveOk: boolean?): BotFinishLogic.Cat
	return {
		userId = id,
		x = x,
		z = z,
		hpRatio = hp,
		alive = true,
		diveOk = if diveOk == nil then true else diveOk,
	}
end

local function finishPick(partial: {
	difficulty: BotFinishLogic.Difficulty?,
	x: number?,
	z: number?,
	selfHp: number?,
	retreatHp: number?,
	enemies: { BotFinishLogic.Cat }?,
}): BotFinishLogic.FinishGoal?
	return BotFinishLogic.pick({
		difficulty = partial.difficulty or "Hard",
		x = partial.x or 0,
		z = partial.z or 0,
		selfHp = if partial.selfHp == nil then 1 else partial.selfHp,
		retreatHp = if partial.retreatHp == nil then 0.16 else partial.retreatHp,
		enemies = partial.enemies or {},
	})
end

assert(BotFinishLogic.CloseHp == 0.4 and BotFinishLogic.LongHp == 0.28)
assert(BotFinishLogic.Chase == 64 and BotFinishLogic.Long == 112)
assert(BotFinishLogic.limit(64) == 0.4)
assert(BotFinishLogic.limit(65) == 0.28)
assert(BotFinishLogic.limit(112) == 0.28)
assert(BotFinishLogic.limit(113) == nil)
assert(BotFinishLogic.worth(0.4, 64) == true)
assert(BotFinishLogic.worth(0.41, 10) == false)
assert(BotFinishLogic.worth(0.28, 112) == true)
assert(BotFinishLogic.worth(0.29, 80) == false)
assert(BotFinishLogic.worth(0.1, 113) == false)
assert(BotFinishLogic.worth(0, 10) == false)
assert(BotFinishLogic.urgency(0.2, 60) ~= nil)
assert(BotFinishLogic.urgency(0.41, 10) == nil)
local closeUrgency = BotFinishLogic.urgency(0.4, 10)
local farUrgency = BotFinishLogic.urgency(0.2, 60)
assert(closeUrgency ~= nil and farUrgency ~= nil and farUrgency > closeUrgency, "a clearly lower cat outranks a closer one")

assert(finishPick({ difficulty = "Easy", enemies = { foe(9, 10, 0, 0.2) } }) == nil, "Easy does not finish-hunt")
assert(finishPick({ difficulty = "Normal", enemies = { foe(9, 10, 0, 0.2) } }) == nil, "Normal does not finish-hunt")
assert(finishPick({ selfHp = 0.16, enemies = { foe(9, 10, 0, 0.2) } }) == nil, "fleeing bot does not finish")
assert(finishPick({ enemies = { foe(9, 10, 0, 0.41) } }) == nil, "41% is not low enough")
assert(finishPick({ enemies = { foe(9, 65, 0, 0.4) } }) == nil, "40% past the short chase is not a rotate")
assert(finishPick({ enemies = { foe(9, 113, 0, 0.1) } }) == nil, "past the long chase is not a hunt")
assert(finishPick({ enemies = { foe(9, 10, 0, 0) } }) == nil, "a downed cat is not a finish")
assert(finishPick({ enemies = { foe(9, 10, 0, 0.2, false) } }) == nil, "an empty tower is not a finish")

local closeFinish = finishPick({ enemies = { foe(9, 64, 0, 0.4) } })
assert(closeFinish ~= nil and closeFinish.userId == 9 and closeFinish.long == false, "40% inside the short chase finishes")
local rotated = finishPick({ enemies = { foe(9, 112, 0, 0.28) } })
assert(rotated ~= nil and rotated.long == true, "28% takes the longer rotate")
assert(finishPick({ enemies = { foe(9, 112, 0, 0.29) } }) == nil, "just above 28% does not rotate")

local lowerWins = finishPick({
	enemies = { foe(4, 10, 0, 0.4), foe(8, 60, 0, 0.2) },
})
assert(lowerWins ~= nil and lowerWins.userId == 8, "the lower cat wins a clear HP gap")
local nearerWins = finishPick({
	enemies = { foe(4, 50, 0, 0.39), foe(8, 10, 0, 0.4) },
})
assert(nearerWins ~= nil and nearerWins.userId == 8, "a hundredth of HP does not beat a shorter walk")
local idTie = finishPick({
	enemies = { foe(8, 10, 0, 0.3), foe(3, 10, 0, 0.3) },
})
assert(idTie ~= nil and idTie.userId == 3, "equal HP and distance prefers the smaller id")
local safeDive = finishPick({
	enemies = { foe(9, 10, 0, 0.1, false), foe(4, 20, 0, 0.35, true) },
})
assert(safeDive ~= nil and safeDive.userId == 4, "an unsafe dive is skipped for a legal finish")

local finishHint = { x = -20, z = -100, userId = 9, hpRatio = 0.3 }
local leaveCamp = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -70,
	z = -100,
	campId = "YarnGolemNW",
	routeIndex = 2,
	finish = finishHint,
})
assert(leaveCamp.action == "finish" and leaveCamp.focusUserId == 9, "finish beats a full-HP camp")
assert(leaveCamp.x == -20 and leaveCamp.memory.campId == "YarnGolemNW", "the camp waits")

local hurtBeforeFinish = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -70,
	z = -100,
	campId = "YarnGolemNW",
	routeIndex = 2,
	camps = without("YarnGolemNW", camp("YarnGolemNW", -70, -100, 50, 220)),
	finish = finishHint,
})
assert(hurtBeforeFinish.action == "camp" and hurtBeforeFinish.campId == "YarnGolemNW", "a hurt camp still finishes before the chase")

local faceKeepsCamp = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -70,
	z = -100,
	campId = "YarnGolemNW",
	routeIndex = 2,
	enemy = { x = -60, z = -90 },
	finish = finishHint,
})
assert(faceKeepsCamp.action == "fight" and faceKeepsCamp.memory.campId == "YarnGolemNW", "a cat in face range still resumes the camp")

local peelBeforeFinish = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -100,
	z = -88,
	campId = "PigeonsNW",
	routeIndex = 1,
	peel = { x = -40, z = -70, critical = false, nearby = true, enemyUserId = 6 },
	finish = finishHint,
})
assert(peelBeforeFinish.action == "peel" and peelBeforeFinish.focusUserId == 6, "peel beats a wounded finish")

local siegeBeforeFinish = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -70,
	z = -100,
	campId = "YarnGolemNW",
	routeIndex = 2,
	siege = siegeHint,
	finish = finishHint,
})
assert(siegeBeforeFinish.action == "siege" and siegeBeforeFinish.objectiveId == "RedMidOuter", "an active siege beats a wounded finish")

local leviBeforeFinish = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -100,
	z = -88,
	campId = "PigeonsNW",
	routeIndex = 1,
	camps = withEpic(ALL),
	finish = finishHint,
})
assert(leviBeforeFinish.action == "camp" and leviBeforeFinish.campId == "CanalLevi", "Levi beats a wounded finish")

local leviStillPeelsFinish = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 12,
	z = 24,
	campId = "CanalLevi",
	routeIndex = 2,
	camps = withEpic(ALL),
	peel = { x = 12, z = 24, critical = true, nearby = true, enemyUserId = 8 },
	finish = finishHint,
})
assert(leviStillPeelsFinish.action == "peel" and leviStillPeelsFinish.focusUserId == 8, "critical nearby peel still interrupts Levi")

local finishRotate = ask({
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
	finish = { x = 40, z = 0, userId = 5, hpRatio = 0.25 },
})
assert(finishRotate.action == "finish" and finishRotate.focusUserId == 5, "finish beats an idle rotate")

local laneFinish = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 40,
	z = 80,
	jungler = false,
	finish = { x = 40, z = 30, userId = 7, hpRatio = 0.22 },
})
assert(laneFinish.action == "finish" and laneFinish.focusUserId == 7, "a lane bot finishes instead of last-hitting")

local laneSiegeFinish = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 40,
	z = 80,
	jungler = false,
	siege = { id = "RedBotOuter", x = 90, z = 80 },
	finish = { x = 40, z = 30, userId = 7, hpRatio = 0.2 },
})
assert(laneSiegeFinish.action == "siege", "a lane bot sieges before finishing")

local laneFaceFinish = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 40,
	z = 80,
	jungler = false,
	enemy = { x = 48, z = 80 },
	finish = { x = 40, z = 20, userId = 7, hpRatio = 0.2 },
})
assert(laneFaceFinish.action == "fight", "a cat in face range beats the longer finish")

local laneAcquireFinish = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 40,
	z = 80,
	jungler = false,
	enemy = { x = 80, z = 80 },
	finish = { x = 40, z = 20, userId = 7, hpRatio = 0.2 },
})
assert(laneAcquireFinish.action == "fight", "a champion already in hunt range beats the longer finish")

local easyFinish = ask({
	difficulty = "Easy",
	team = "Red",
	x = 40,
	z = 0,
	jungler = true,
	finish = finishHint,
})
assert(easyFinish.action == "lane", "Easy ignores a finish hint")

local normalFinishHunt = ask({
	difficulty = "Normal",
	team = "Blue",
	x = -70,
	z = -100,
	campId = "YarnGolemNW",
	routeIndex = 2,
	lanePushed = true,
	finish = finishHint,
})
assert(normalFinishHunt.action ~= "finish", "Normal ignores a finish hint")

-- Hard yarn core. Callers already applied StructureLogic's vulnerable bit.
-- Outer/stall siege still refuses a nexus. This walk is separate.
local function yarnCore(partial: {
	id: string?,
	x: number?,
	z: number?,
	health: number?,
	maxHealth: number?,
	vulnerable: boolean?,
	alive: boolean?,
	allyKittens: number?,
	enemyKittens: number?,
	allyHitters: number?,
}): BotCoreLogic.CoreView
	return {
		id = partial.id or "RedNexus",
		x = if partial.x == nil then 168 else partial.x,
		z = if partial.z == nil then 0 else partial.z,
		health = if partial.health == nil then 2200 else partial.health,
		maxHealth = if partial.maxHealth == nil then 2200 else partial.maxHealth,
		vulnerable = if partial.vulnerable == nil then true else partial.vulnerable,
		alive = if partial.alive == nil then true else partial.alive,
		allyKittens = partial.allyKittens or 0,
		enemyKittens = partial.enemyKittens or 0,
		allyHitters = partial.allyHitters or 0,
	}
end

local function corePick(partial: {
	difficulty: BotCoreLogic.Difficulty?,
	x: number?,
	z: number?,
	selfHp: number?,
	retreatHp: number?,
	peelCritical: boolean?,
	core: BotCoreLogic.CoreView?,
}): BotCoreLogic.CoreGoal?
	return BotCoreLogic.pick({
		difficulty = partial.difficulty or "Hard",
		x = if partial.x == nil then 120 else partial.x,
		z = if partial.z == nil then 0 else partial.z,
		selfHp = if partial.selfHp == nil then 1 else partial.selfHp,
		retreatHp = if partial.retreatHp == nil then 0.16 else partial.retreatHp,
		peelCritical = partial.peelCritical == true,
		core = partial.core,
	})
end

assert(BotCoreLogic.Range == 360 and BotCoreLogic.MinKittens == 2)
assert(BotCoreLogic.LowRatio == 0.5 and BotCoreLogic.AllyHitters == 2)
assert(corePick({ core = nil }) == nil, "no core is not a walk")
assert(corePick({ difficulty = "Easy", core = yarnCore({ allyKittens = 3 }) }) == nil, "Easy does not take the core")
assert(corePick({ difficulty = "Normal", core = yarnCore({ allyKittens = 3 }) }) == nil, "Normal does not take the core")
assert(corePick({ core = yarnCore({ vulnerable = false, allyKittens = 3, health = 400, allyHitters = 2 }) }) == nil, "a gated core stays closed")
assert(corePick({ core = yarnCore({ alive = false, allyKittens = 3 }) }) == nil, "a downed core is not a walk")
assert(corePick({ core = yarnCore({ health = 0, allyKittens = 3 }) }) == nil, "an empty core bar is not a walk")
assert(corePick({ core = yarnCore({}) }) == nil, "an empty full-HP core is not a solo walk")
assert(corePick({ core = yarnCore({ allyKittens = 1 }) }) == nil, "one kitten on a full core stays back")
assert(corePick({ core = yarnCore({ allyKittens = 2, enemyKittens = 2 }) }) == nil, "a tied wave is not a crash")
assert(corePick({ core = yarnCore({ allyHitters = 1 }) }) == nil, "one ally on a full core is not enough")
local winning = corePick({ core = yarnCore({ allyKittens = 2 }) })
assert(winning ~= nil and winning.id == "RedNexus" and winning.x == 168, "a winning wave takes the open core")
assert(corePick({ core = yarnCore({ allyKittens = 3, enemyKittens = 1 }) }) ~= nil, "more kittens than theirs")
assert(corePick({ core = yarnCore({ health = 1100 }) }) ~= nil, "half HP is enough without a wave")
assert(corePick({ core = yarnCore({ health = 1101 }) }) == nil, "just above half still needs a wave or allies")
assert(corePick({ core = yarnCore({ health = 400, allyKittens = 0, enemyKittens = 4 }) }) ~= nil, "a low core is sane even if their wave is bigger")
assert(corePick({ core = yarnCore({ allyHitters = 2 }) }) ~= nil, "two allies already on a full core")
assert(corePick({ x = -176, core = yarnCore({ allyKittens = 2 }) }) ~= nil, "the fountain can still join a winning wave")
assert(corePick({ x = -176, core = yarnCore({}) }) == nil, "the fountain does not solo a full core")
assert(corePick({ x = -70, z = -100, core = yarnCore({ allyKittens = 2 }) }) ~= nil, "a back camp joins an open core")
assert(corePick({ x = -193, core = yarnCore({ allyKittens = 3, health = 200, allyHitters = 3 }) }) == nil, "past the walk range stays put")
assert(corePick({ selfHp = 0.16, core = yarnCore({ allyKittens = 3 }) }) == nil, "fleeing bot does not take the core")
assert(corePick({ peelCritical = true, core = yarnCore({ allyKittens = 3 }) }) == nil, "a critical peel is not a core walk")

local coreHint = { id = "RedNexus", x = 168, z = 0 }

local coreOverCamp = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -70,
	z = -100,
	campId = "YarnGolemNW",
	routeIndex = 2,
	siege = coreHint,
})
assert(coreOverCamp.action == "siege" and coreOverCamp.objectiveId == "RedNexus", "the open core beats a full-HP camp")
assert(coreOverCamp.memory.campId == "YarnGolemNW", "the route waits")

local hurtBeforeCore = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -70,
	z = -100,
	campId = "YarnGolemNW",
	routeIndex = 2,
	camps = without("YarnGolemNW", camp("YarnGolemNW", -70, -100, 50, 220)),
	siege = coreHint,
})
assert(hurtBeforeCore.action == "camp" and hurtBeforeCore.campId == "YarnGolemNW", "a hurt camp still finishes before the core")

local peelBeforeCore = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 40,
	z = 0,
	campId = "PigeonsNW",
	peel = hint,
	siege = coreHint,
})
assert(peelBeforeCore.action == "peel" and peelBeforeCore.focusUserId == 9, "peel beats the core")

local leviBeforeCore = ask({
	difficulty = "Hard",
	team = "Blue",
	x = -100,
	z = -88,
	campId = "PigeonsNW",
	routeIndex = 1,
	camps = withEpic(ALL),
	siege = coreHint,
})
assert(leviBeforeCore.action == "camp" and leviBeforeCore.campId == "CanalLevi", "Levi beats the core while it is up")

local faceBeforeCore = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 140,
	z = 0,
	enemy = { x = 155, z = 0 },
	camps = {},
	siege = coreHint,
	finish = { x = 155, z = 0, userId = 7, hpRatio = 0.2 },
})
assert(faceBeforeCore.action == "fight", "a wounded cat in face range beats the core")

local coreBeforeFarFinish = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 40,
	z = 0,
	campId = "PigeonsNW",
	routeIndex = 1,
	siege = coreHint,
	finish = finishHint,
})
assert(coreBeforeFarFinish.action == "siege" and coreBeforeFarFinish.objectiveId == "RedNexus", "the open core beats a wounded cat outside face range")

local coreRotate = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 10,
	z = 0,
	camps = {},
	lanes = OPEN_LANES,
	siege = coreHint,
})
assert(coreRotate.action == "siege" and coreRotate.objectiveId == "RedNexus", "the open core beats an idle rotate")

local laneCore = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 140,
	z = 0,
	jungler = false,
	siege = coreHint,
})
assert(laneCore.action == "siege" and laneCore.objectiveId == "RedNexus", "a lane bot hits the open core")

local laneFaceCore = ask({
	difficulty = "Hard",
	team = "Blue",
	x = 140,
	z = 0,
	jungler = false,
	enemy = { x = 152, z = 0 },
	siege = coreHint,
	finish = { x = 152, z = 0, userId = 4, hpRatio = 0.25 },
})
assert(laneFaceCore.action == "fight", "a lane bot finishes the cat in its face before the core")

local easyCore = ask({
	difficulty = "Easy",
	team = "Red",
	x = 140,
	z = 0,
	jungler = true,
	siege = coreHint,
})
assert(easyCore.action == "lane", "Easy ignores a core hint")

local normalCore = ask({
	difficulty = "Normal",
	team = "Blue",
	x = 140,
	z = 0,
	lanePushed = true,
	siege = coreHint,
})
assert(normalCore.action ~= "siege", "Normal ignores a core hint")

print("PASS: jungle route, commit, contest, rotate, brush skirt, canal levi priority, hard ally peel, hard siege, hard yarn core, hard wounded finish, camp respawn chip, control yarn plant")
