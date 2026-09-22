--!strict

-- Jungle goals for Cat Rift practice bots. BotService still moves and attacks.
-- Own-side camp spots and whether those camps are up are map knowledge (the alive
-- list JungleService already gave bots). That is mild camp omniscience, not a
-- champion wallhack. Enemy cats are only the one the caller marks visible.
-- Last-known lane hints score a rotate; they are never a hidden body to chase.
-- Easy never clears. Hard may peel a visible low ally above leftover camps
-- and idle lane shove. A hurt camp still finishes. Canal Levi still wins
-- unless that ally is critically low and the fight is nearby.
-- Hard may also siege a post the caller already chose. That loses to peel,
-- Levi, a hurt camp, and a cat in face range. It beats a wounded-champion
-- finish, a full-HP camp, and an idle rotate. An open yarn core BotCoreLogic
-- already accepted arrives as that same siege hint and keeps this ranking,
-- so a wounded cat in face range still wins and a full-HP camp still loses.
-- Hard may also finish a wounded enemy the caller already chose. That loses
-- to peel, Levi, a hurt camp, a cat in face range, and an active siege.
-- It beats a full-HP camp and soft lane farming. Easy and Normal ignore it.

local RiverEpic = require(script.Parent:WaitForChild("RiverEpic"))

local JungleBotLogic = {}

-- How long a team last-known enemy still biases a post-clear rotate.
JungleBotLogic.GankMemorySeconds = 8

local SIDE = 24
local NEAREST = 120
local HYSTERESIS = 24
local ARRIVE = 14
local SKIRT_PAD = 6
local HARD_CONTEST = 32
local NORMAL_CONTEST = 22
local HARD_FINISH = 0.4
local NORMAL_FINISH = 0.55

local BLUE_ROUTE = { "PigeonsNW", "YarnGolemNW", "RiverCrabN", "RiverCrabS" }
local RED_ROUTE = { "PigeonsSE", "YarnGolemSE", "RiverCrabS", "RiverCrabN" }

export type TeamId = "Blue" | "Red"
export type Difficulty = "Easy" | "Normal" | "Hard"

export type CampView = {
	id: string,
	x: number,
	z: number,
	health: number,
	maxHealth: number,
	epic: boolean?,
}

export type LaneView = {
	name: string,
	z: number,
	waveX: number?,
	lastKnownX: number?,
	lastKnownZ: number?,
}

export type EnemyView = {
	x: number,
	z: number,
}

export type BrushBox = {
	x: number,
	z: number,
	sx: number,
	sz: number,
}

export type JungleMemory = {
	campId: string?,
	routeIndex: number,
}

-- Already chosen by BotPeelLogic. Jungle only ranks it against camps and Levi.
export type PeelHint = {
	x: number,
	z: number,
	critical: boolean,
	nearby: boolean,
	enemyUserId: number?,
}

-- Already chosen by BotSiegeLogic or BotCoreLogic. Jungle only ranks it.
export type SiegeHint = {
	id: string,
	x: number,
	z: number,
}

-- Already chosen by BotFinishLogic. Jungle only ranks it. HP and range were scored there.
export type FinishHint = {
	x: number,
	z: number,
	userId: number,
	hpRatio: number,
}

export type JungleQuery = {
	difficulty: Difficulty,
	team: TeamId,
	jungler: boolean,
	x: number,
	z: number,
	lanePushed: boolean,
	attackRange: number,
	memory: JungleMemory,
	camps: { CampView },
	enemy: EnemyView?,
	lanes: { LaneView },
	brushes: { BrushBox },
	peel: PeelHint?,
	siege: SiegeHint?,
	finish: FinishHint?,
}

export type JungleAction = "camp" | "rotate" | "lane" | "fight" | "peel" | "siege" | "finish"

export type JungleDecision = {
	action: JungleAction,
	campId: string?,
	x: number?,
	z: number?,
	stepX: number?,
	stepZ: number?,
	focusUserId: number?,
	objectiveId: string?,
	memory: JungleMemory,
}

local function dist(ax: number, az: number, bx: number, bz: number): number
	local dx = ax - bx
	local dz = az - bz
	return math.sqrt(dx * dx + dz * dz)
end

local function memoryOf(campId: string?, routeIndex: number): JungleMemory
	local index = routeIndex
	if index < 1 then
		index = 1
	end
	return { campId = campId, routeIndex = index }
end

local function laneDecision(routeIndex: number): JungleDecision
	return { action = "lane", memory = memoryOf(nil, routeIndex) }
end

local function fightDecision(campId: string?, routeIndex: number): JungleDecision
	return { action = "fight", campId = campId, memory = memoryOf(campId, routeIndex) }
end

function JungleBotLogic.route(team: TeamId): { string }
	if team == "Blue" then
		return BLUE_ROUTE
	end
	return RED_ROUTE
end

local function routeIndexOf(team: TeamId, campId: string): number?
	for index, id in JungleBotLogic.route(team) do
		if id == campId then
			return index
		end
	end
	return nil
end

local function ownSide(team: TeamId, x: number): boolean
	if team == "Blue" then
		return x <= SIDE
	end
	return x >= -SIDE
end

local function findCamp(camps: { CampView }, campId: string?): CampView?
	if not campId then
		return nil
	end
	for _, camp in camps do
		if camp.id == campId then
			return camp
		end
	end
	return nil
end

local function halfExtents(brush: BrushBox): (number, number, number, number)
	local hx = brush.sx * 0.5
	local hz = brush.sz * 0.5
	return brush.x - hx, brush.x + hx, brush.z - hz, brush.z + hz
end

local function insideBrush(x: number, z: number, brush: BrushBox): boolean
	local minX, maxX, minZ, maxZ = halfExtents(brush)
	return x >= minX and x <= maxX and z >= minZ and z <= maxZ
end

local function insideAny(x: number, z: number, brushes: { BrushBox }): boolean
	for _, brush in brushes do
		if insideBrush(x, z, brush) then
			return true
		end
	end
	return false
end

-- Liang-Barsky. t0 is the entry time along the segment.
local function clipSegment(ax: number, az: number, bx: number, bz: number, minX: number, maxX: number, minZ: number, maxZ: number): (boolean, number)
	local dx = bx - ax
	local dz = bz - az
	local t0 = 0
	local t1 = 1
	local function clip(p: number, q: number): boolean
		if math.abs(p) < 1e-8 then
			return q >= 0
		end
		local r = q / p
		if p < 0 then
			if r > t1 then
				return false
			end
			if r > t0 then
				t0 = r
			end
		else
			if r < t0 then
				return false
			end
			if r < t1 then
				t1 = r
			end
		end
		return true
	end
	if not clip(-dx, ax - minX) then
		return false, 0
	end
	if not clip(dx, maxX - ax) then
		return false, 0
	end
	if not clip(-dz, az - minZ) then
		return false, 0
	end
	if not clip(dz, maxZ - az) then
		return false, 0
	end
	return true, t0
end

local function segmentHits(ax: number, az: number, bx: number, bz: number, brush: BrushBox): boolean
	local minX, maxX, minZ, maxZ = halfExtents(brush)
	local hit, t0 = clipSegment(ax, az, bx, bz, minX, maxX, minZ, maxZ)
	return hit and t0 < 1
end

-- Immediate walk target. Inside a pocket, leave on a straight line.
-- A segment that would cut a brush walks an outside corner that is closer to the camp.
function JungleBotLogic.stepPoint(ax: number, az: number, bx: number, bz: number, brushes: { BrushBox }): (number, number)
	if insideAny(ax, az, brushes) then
		return bx, bz
	end
	local blocking: BrushBox? = nil
	local bestT = 2
	for _, brush in brushes do
		local minX, maxX, minZ, maxZ = halfExtents(brush)
		local hit, t0 = clipSegment(ax, az, bx, bz, minX, maxX, minZ, maxZ)
		if hit and t0 < bestT and t0 < 1 and not insideBrush(bx, bz, brush) then
			bestT = t0
			blocking = brush
		end
	end
	if not blocking then
		return bx, bz
	end
	local goalDist = dist(ax, az, bx, bz)
	local bestX, bestZ = bx, bz
	local bestCost = 1e9
	local hx = blocking.sx * 0.5 + SKIRT_PAD
	local hz = blocking.sz * 0.5 + SKIRT_PAD
	local corners = {
		{ blocking.x - hx, blocking.z - hz },
		{ blocking.x - hx, blocking.z + hz },
		{ blocking.x + hx, blocking.z - hz },
		{ blocking.x + hx, blocking.z + hz },
	}
	for _, corner in corners do
		local cx, cz = corner[1], corner[2]
		local remain = dist(cx, cz, bx, bz)
		if remain < goalDist - 0.5 and not insideAny(cx, cz, brushes) and not segmentHits(ax, az, cx, cz, blocking) then
			local cost = dist(ax, az, cx, cz) + remain
			if cost < bestCost then
				bestCost = cost
				bestX, bestZ = cx, cz
			end
		end
	end
	return bestX, bestZ
end

local function approach(query: JungleQuery, goalX: number, goalZ: number): (number, number)
	local stepX, stepZ = JungleBotLogic.stepPoint(query.x, query.z, goalX, goalZ, query.brushes)
	if dist(stepX, stepZ, goalX, goalZ) <= 4 then
		return goalX, goalZ
	end
	return stepX, stepZ
end

local function campDecision(query: JungleQuery, camp: CampView, routeIndex: number): JungleDecision
	local stepX, stepZ = approach(query, camp.x, camp.z)
	return {
		action = "camp",
		campId = camp.id,
		x = camp.x,
		z = camp.z,
		stepX = stepX,
		stepZ = stepZ,
		memory = memoryOf(camp.id, routeIndex),
	}
end

local function engaged(query: JungleQuery, camp: CampView): boolean
	if camp.health < camp.maxHealth - 0.5 then
		return true
	end
	return dist(query.x, query.z, camp.x, camp.z) <= query.attackRange + 4
end

local function contesting(query: JungleQuery, camp: CampView?): boolean
	local enemy = query.enemy
	if not enemy then
		return false
	end
	local gap = dist(query.x, query.z, enemy.x, enemy.z)
	local limit = if query.difficulty == "Hard" then HARD_CONTEST else NORMAL_CONTEST
	if gap > limit then
		return false
	end
	if camp and engaged(query, camp) then
		local ratio = camp.health / math.max(camp.maxHealth, 1)
		local finishAt = if query.difficulty == "Hard" then HARD_FINISH else NORMAL_FINISH
		if ratio <= finishAt then
			return false
		end
	end
	return true
end

local function advanceIndex(team: TeamId, campId: string?, routeIndex: number): number
	local found = if campId then routeIndexOf(team, campId) else nil
	local route = JungleBotLogic.route(team)
	local nextIndex = if found then found + 1 else routeIndex
	if nextIndex < 1 or nextIndex > #route then
		nextIndex = 1
	end
	return nextIndex
end

local function nextOnRoute(query: JungleQuery, routeIndex: number): CampView?
	local route = JungleBotLogic.route(query.team)
	local start = routeIndex
	if start < 1 or start > #route then
		start = 1
	end
	for offset = 0, #route - 1 do
		local index = ((start - 1 + offset) % #route) + 1
		local camp = findCamp(query.camps, route[index])
		if camp and ownSide(query.team, camp.x) then
			return camp
		end
	end
	return nil
end

local function betterNearest(team: TeamId, originX: number, originZ: number, candidate: CampView, current: CampView): boolean
	local left = dist(originX, originZ, candidate.x, candidate.z)
	local right = dist(originX, originZ, current.x, current.z)
	if math.abs(left - right) > 0.5 then
		return left < right
	end
	local leftRank = routeIndexOf(team, candidate.id) or 100
	local rightRank = routeIndexOf(team, current.id) or 100
	if leftRank ~= rightRank then
		return leftRank < rightRank
	end
	return candidate.id < current.id
end

local function findEpic(camps: { CampView }): CampView?
	for _, camp in camps do
		if camp.epic == true then
			return camp
		end
	end
	return nil
end

-- Visible enemy standing on / next to the pit. Same fog rule as other enemies:
-- the caller only passes a champ they can already see.
local function enemyOnEpic(query: JungleQuery, epic: CampView): boolean
	local enemy = query.enemy
	if not enemy then
		return false
	end
	return dist(enemy.x, enemy.z, epic.x, epic.z) <= HARD_CONTEST + 8
end

-- Engaged non-epic camp blocks a Levi walk only once the camp is hurt.
-- In-range healthy leftover walks (and sticky opens) still lose to Levi.
local function startedCamp(camp: CampView): boolean
	return camp.health < camp.maxHealth - 0.5
end

local function holdingForLevi(query: JungleQuery, hold: CampView?): boolean
	if not hold or hold.epic == true then
		return false
	end
	return startedCamp(hold)
end

local function nearestCamp(query: JungleQuery, sticky: CampView?): CampView?
	if sticky and ownSide(query.team, sticky.x) then
		local keep = dist(query.x, query.z, sticky.x, sticky.z)
		if keep <= NEAREST + HYSTERESIS then
			local challenger: CampView? = nil
			for _, camp in query.camps do
				if camp.id ~= sticky.id and camp.epic ~= true and ownSide(query.team, camp.x) then
					local gap = dist(query.x, query.z, camp.x, camp.z)
					if gap <= NEAREST and (not challenger or betterNearest(query.team, query.x, query.z, camp, challenger)) then
						challenger = camp
					end
				end
			end
			if not challenger or keep <= dist(query.x, query.z, challenger.x, challenger.z) + HYSTERESIS then
				return sticky
			end
		end
	end
	local best: CampView? = nil
	for _, camp in query.camps do
		if camp.epic ~= true and ownSide(query.team, camp.x) and dist(query.x, query.z, camp.x, camp.z) <= NEAREST then
			if not best or betterNearest(query.team, query.x, query.z, camp, best) then
				best = camp
			end
		end
	end
	return best
end

local function rotateTarget(query: JungleQuery): (number?, number?)
	local sign = if query.team == "Blue" then 1 else -1
	local bestScore = -1e9
	local bestX: number? = nil
	local bestZ: number? = nil
	local bestLane = 1e9
	for _, lane in query.lanes do
		local score = -1e6
		local destX = if query.team == "Blue" then -24 else 24
		local destZ = lane.z
		if lane.waveX then
			score = lane.waveX * sign
			destX = math.clamp(lane.waveX, -150, 150)
		end
		if lane.lastKnownX and lane.lastKnownZ and math.abs(lane.lastKnownZ - lane.z) <= 36 then
			score += 90
			if not lane.waveX then
				destX = math.clamp(lane.lastKnownX, -150, 150)
			end
		end
		local laneBias = math.abs(lane.z - query.z)
		if score > bestScore + 0.01 or (math.abs(score - bestScore) <= 0.01 and laneBias < bestLane) then
			bestScore = score
			bestLane = laneBias
			bestX = destX
			bestZ = destZ
		end
	end
	return bestX, bestZ
end

local function siegeDecision(query: JungleQuery, routeIndex: number): JungleDecision
	local hint = query.siege
	local goalX = query.x
	local goalZ = query.z
	local objectiveId: string? = nil
	if hint then
		goalX = hint.x
		goalZ = hint.z
		objectiveId = hint.id
	end
	local stepX, stepZ = approach(query, goalX, goalZ)
	local resume = if findCamp(query.camps, query.memory.campId) then query.memory.campId else nil
	return {
		action = "siege",
		objectiveId = objectiveId,
		x = goalX,
		z = goalZ,
		stepX = stepX,
		stepZ = stepZ,
		memory = memoryOf(resume, routeIndex),
	}
end

local function finishDecision(query: JungleQuery, routeIndex: number): JungleDecision
	local hint = query.finish
	local goalX = query.x
	local goalZ = query.z
	local focus: number? = nil
	if hint then
		goalX = hint.x
		goalZ = hint.z
		focus = hint.userId
	end
	local stepX, stepZ = approach(query, goalX, goalZ)
	local resume = if findCamp(query.camps, query.memory.campId) then query.memory.campId else nil
	return {
		action = "finish",
		x = goalX,
		z = goalZ,
		stepX = stepX,
		stepZ = stepZ,
		focusUserId = focus,
		memory = memoryOf(resume, routeIndex),
	}
end

local function peelDecision(query: JungleQuery, routeIndex: number): JungleDecision
	local hint = query.peel
	local goalX = query.x
	local goalZ = query.z
	local focus: number? = nil
	if hint then
		goalX = hint.x
		goalZ = hint.z
		focus = hint.enemyUserId
	end
	local stepX, stepZ = approach(query, goalX, goalZ)
	local resume = if findCamp(query.camps, query.memory.campId) then query.memory.campId else nil
	return {
		action = "peel",
		x = goalX,
		z = goalZ,
		stepX = stepX,
		stepZ = stepZ,
		focusUserId = focus,
		memory = memoryOf(resume, routeIndex),
	}
end

function JungleBotLogic.decide(query: JungleQuery): JungleDecision
	local routeIndex = query.memory.routeIndex
	if routeIndex < 1 then
		routeIndex = 1
	end
	-- Top and bot stay in lane. A Hard peel still beats that shove, then a siege,
	-- then a wounded-champion finish. Easy never peels, sieges, or finish-hunts.
	local peel = if query.difficulty == "Hard" then query.peel else nil
	local siege = if query.difficulty == "Hard" then query.siege else nil
	local finish = if query.difficulty == "Hard" then query.finish else nil
	if not query.jungler or query.difficulty == "Easy" then
		if peel then
			return peelDecision(query, routeIndex)
		end
		if siege then
			-- A cat in face range still falls through to the normal hunt.
			if contesting(query, nil) then
				return fightDecision(nil, routeIndex)
			end
			return siegeDecision(query, routeIndex)
		end
		if finish then
			-- A champion already inside the normal hunt stays on that hunt.
			-- Finish only pulls a lane bot off last-hitting when the wounded
			-- cat is outside that bubble.
			if query.enemy then
				return fightDecision(nil, routeIndex)
			end
			return finishDecision(query, routeIndex)
		end
		return laneDecision(routeIndex)
	end

	local committed = findCamp(query.camps, query.memory.campId)
	if query.memory.campId and not committed then
		routeIndex = advanceIndex(query.team, query.memory.campId, routeIndex)
	end
	if committed and not ownSide(query.team, committed.x) then
		committed = nil
	end
	if committed and committed.epic == true and query.difficulty ~= "Hard" then
		committed = nil
	end

	local epic = findEpic(query.camps)

	-- Hard sticks to the route camp until it dies — unless Canal Levi is up and
	-- this camp is only a leftover (full HP) walk, a Hard peel is calling, a
	-- siege is already on a post, or a wounded champion is worth finishing.
	-- A hurt camp still finishes. A face-range fight still resumes this camp.
	-- Normal only locks in once the fight has started.
	local hold = committed
	if hold and hold.epic ~= true then
		if query.difficulty == "Hard" and epic and RiverEpic.wantsHardPath(query.difficulty, query.jungler, false) then
			if not startedCamp(hold) then
				hold = nil
			end
		elseif peel and not startedCamp(hold) then
			hold = nil
		elseif siege and not startedCamp(hold) then
			hold = nil
		elseif query.difficulty ~= "Hard" and not engaged(query, hold) then
			hold = nil
		end
	elseif hold and hold.epic == true and peel and peel.critical and peel.nearby then
		hold = nil
	elseif hold and query.difficulty ~= "Hard" and not engaged(query, hold) then
		hold = nil
	end

	if hold and contesting(query, hold) then
		local index = routeIndexOf(query.team, hold.id) or routeIndex
		return fightDecision(hold.id, index)
	end
	-- Drop a full-HP camp for a wounded champion only after the face-range
	-- fight above has had a chance to keep the camp id.
	if hold and finish and hold.epic ~= true and not startedCamp(hold) then
		hold = nil
	end
	if hold then
		local index = routeIndexOf(query.team, hold.id) or routeIndex
		return campDecision(query, hold, index)
	end

	-- Canal Levi beats leftover camps and rotates while it is up. Hard mid must
	-- contest. A visible enemy on the pit is tagged when in face range, else
	-- walk the canal. A critical nearby ally peel is the one interrupt.
	-- Normal only tags along if already mid-river.
	local hardGo = epic ~= nil and RiverEpic.wantsHardPath(query.difficulty, query.jungler, holdingForLevi(query, committed))
	local normalGo = epic ~= nil and RiverEpic.wantsNormalAssist(query.difficulty, query.jungler, query.x, query.z)
	local leviGo = epic ~= nil and (hardGo or normalGo)
	local interruptLevi = peel ~= nil and peel.critical and peel.nearby
	if epic and leviGo and not interruptLevi then
		if enemyOnEpic(query, epic) and contesting(query, epic) then
			local index = routeIndexOf(query.team, epic.id) or routeIndex
			return fightDecision(epic.id, index)
		end
	end

	-- Peel beats leftover camps, a soft face-range hunt, and the post-clear rotate.
	if peel and (not leviGo or interruptLevi) then
		return peelDecision(query, routeIndex)
	end

	if contesting(query, nil) then
		return fightDecision(nil, routeIndex)
	end

	if epic and leviGo and not interruptLevi then
		return campDecision(query, epic, routeIndex)
	end

	-- Siege beats a wounded finish, a full-HP route camp, and the post-clear
	-- rotate. Peel, Levi, a hurt camp, and a face-range fight already returned.
	if siege then
		return siegeDecision(query, routeIndex)
	end

	-- A wounded champion beats a full-HP route camp and the idle rotate.
	if finish then
		return finishDecision(query, routeIndex)
	end

	if query.difficulty == "Hard" then
		local camp = nextOnRoute(query, routeIndex)
		if camp then
			local index = routeIndexOf(query.team, camp.id) or routeIndex
			return campDecision(query, camp, index)
		end
	elseif query.lanePushed then
		local camp = nearestCamp(query, committed)
		if camp then
			local index = routeIndexOf(query.team, camp.id) or routeIndex
			return campDecision(query, camp, index)
		end
	end

	if query.difficulty ~= "Hard" then
		return laneDecision(routeIndex)
	end

	local destX, destZ = rotateTarget(query)
	if not destX or not destZ then
		local homeX = if query.team == "Blue" then -24 else 24
		return {
			action = "rotate",
			x = homeX,
			z = 0,
			stepX = homeX,
			stepZ = 0,
			memory = memoryOf(nil, routeIndex),
		}
	end
	if dist(query.x, query.z, destX, destZ) <= ARRIVE then
		return laneDecision(routeIndex)
	end
	local stepX, stepZ = approach(query, destX, destZ)
	return {
		action = "rotate",
		x = destX,
		z = destZ,
		stepX = stepX,
		stepZ = stepZ,
		memory = memoryOf(nil, routeIndex),
	}
end

return JungleBotLogic
