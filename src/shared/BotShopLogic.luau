--!strict

-- Practice-bot Pawmart plans. BotService still calls ShopService.buyAt
-- (fountain, gold, and stack checks — the same body humans hit with B).
-- Jungle routing stays in JungleBotLogic. This module only picks the next
-- item and when an active is worth pressing.
--
-- Hard buys at the opening fountain, then finishes the list on later visits.
-- The next unaffordable item blocks the rest of the list so a cheap lens
-- or Control Yarn cannot spend the gold a Fang or Cleave is waiting on.
-- Easy is one Mana Treat after they have already left home. Normal is two
-- stat sticks on a fountain return. Only Hard buys Control Yarn.
-- Humans can pawn a copy at the fountain (ShopService.sellAt). Bots do not.
-- A full-build swap is not a sell plan. maySell stays false.

local ItemCatalog = require(script.Parent.ItemCatalog)

local BotShopLogic = {}

export type Difficulty = "Easy" | "Normal" | "Hard"
export type Line = "tank" | "assassin" | "mage"
export type SpotKind = "river-brush" | "canal" | "objective"

export type VisionSpot = {
	x: number,
	z: number,
	kind: SpotKind,
}

export type Post = {
	x: number,
	z: number,
	range: number,
}

-- Safety cap for one fountain visit. Longer than a Hard plan, counting
-- Control Yarn's two charges (an assassin buys seven times).
BotShopLogic.MaxBuysPerVisit = 8
BotShopLogic.CleaveMinEnemies = 2
-- A spot farther than the place range can still take the charge if it is
-- within this many place-lengths. The plant itself stays inside place range.
BotShopLogic.ControlApproachMul = 2

local EASY: { string } = { "ManaTreat" }

local NORMAL: { [Line]: { string } } = {
	tank = { "Yarnplate", "PounceBoots" },
	assassin = { "Longclaw", "PounceBoots" },
	mage = { "ManaTreat", "Longclaw" },
}

-- Opening purse is 500. Yarnplate+Charm, Longclaw+Boots, and Treat+Longclaw
-- all fit. Stall Fang (300) and Yarn Cleave (280) wait until a later visit.
-- Control Yarn is 75, but it sits after those actives so a short purse cannot
-- skip them. Two charges block Whisker Lens until both are owned or unaffordable.
-- Spot coordinates match BrushCrabN / BrushCrabS, Canal Levi, and the river crabs.
local HARD: { [Line]: { string } } = {
	tank = { "Yarnplate", "PaperCharm", "YarnCleave", "ControlYarn", "WhiskerLens" },
	assassin = { "Longclaw", "PounceBoots", "StallFang", "YarnCleave", "ControlYarn", "WhiskerLens" },
	mage = { "ManaTreat", "Longclaw", "YarnCleave", "ControlYarn", "WhiskerLens" },
}

local VISION_SPOTS: { VisionSpot } = {
	{ x = -22, z = -48, kind = "river-brush" },
	{ x = 22, z = 48, kind = "river-brush" },
	{ x = 0, z = 24, kind = "canal" },
	{ x = 0, z = -48, kind = "objective" },
	{ x = 0, z = 48, kind = "objective" },
}

function BotShopLogic.lineFor(role: string): Line
	if role == "Tank" or role == "Bruiser" then
		return "tank"
	end
	if role == "Assassin" or role == "Marksman" then
		return "assassin"
	end
	return "mage"
end

function BotShopLogic.plan(difficulty: Difficulty, role: string): { string }
	if difficulty == "Easy" then
		local copy = {}
		for _, id in EASY do
			table.insert(copy, id)
		end
		return copy
	end
	local line = BotShopLogic.lineFor(role)
	local source = if difficulty == "Hard" then HARD[line] else NORMAL[line]
	local copy = {}
	for _, id in source do
		table.insert(copy, id)
	end
	return copy
end

function BotShopLogic.visionSpots(): { VisionSpot }
	local copy = {}
	for _, spot in VISION_SPOTS do
		table.insert(copy, { x = spot.x, z = spot.z, kind = spot.kind })
	end
	return copy
end

-- First unowned item the purse can afford, in plan order. Nil when the next
-- core is too expensive or the plan is already owned. Does not skip ahead.
-- Control Yarn stays "unowned" until both charges are in the bag.
function BotShopLogic.nextItem(difficulty: Difficulty, role: string, gold: number, owned: { string }): string?
	for _, id in BotShopLogic.plan(difficulty, role) do
		if ItemCatalog.canBuy(owned, id) then
			local def = ItemCatalog.get(id)
			if not def or gold < def.cost then
				return nil
			end
			return id
		end
	end
	return nil
end

-- Humans pawn. Practice bots only buy, including a finished Hard plan.
function BotShopLogic.maySell(): boolean
	return false
end

-- Hard shops on the spawn fountain (visitedLane still false). Easy and Normal
-- wait until they have walked out once, then buy on a later visit.
function BotShopLogic.shouldShop(difficulty: Difficulty, atFountain: boolean, visitedLane: boolean): boolean
	if not atFountain then
		return false
	end
	if difficulty == "Hard" then
		return true
	end
	return visitedLane
end

function BotShopLogic.shouldCleave(visibleEnemies: number, owns: boolean, ready: boolean): boolean
	return owns and ready and visibleEnemies >= BotShopLogic.CleaveMinEnemies
end

function BotShopLogic.shouldLens(owns: boolean, ready: boolean, enemyWardNearby: boolean): boolean
	return owns and ready and enemyWardNearby
end

-- `planted` is the existing warded latch. `readyAt` is the existing trinket
-- ready stamp. One charge per open latch; Easy and Normal never reach this.
function BotShopLogic.chargeReady(planted: boolean, readyAt: number, now: number): boolean
	return not planted and now >= readyAt
end

-- Drop the latch once that pink is gone, so the next owned charge can plant.
-- The opening early window stays shut: a sniped free pink does not replant.
function BotShopLogic.releaseWardLatch(planted: boolean, ownPinkLive: boolean, earlyWindow: boolean): boolean
	return planted and not ownPinkLive and not earlyWindow
end

-- Hard only. `ready` is chargeReady (and the caller folds in visitedLane).
-- `hasSpot` means controlDestination returned a plant that is not a dive.
function BotShopLogic.shouldPlaceControl(difficulty: Difficulty, owns: boolean, ready: boolean, hasSpot: boolean): boolean
	return difficulty == "Hard" and owns and ready and hasSpot
end

function BotShopLogic.underEnemyPost(x: number, z: number, posts: { Post }): boolean
	for _, post in posts do
		local dx = x - post.x
		local dz = z - post.z
		if dx * dx + dz * dz <= post.range * post.range then
			return true
		end
	end
	return false
end

local function flatSq(ax: number, az: number, bx: number, bz: number): number
	local dx = ax - bx
	local dz = az - bz
	return dx * dx + dz * dz
end

local function spotRank(kind: SpotKind): number
	if kind == "river-brush" then
		return 1
	end
	if kind == "canal" then
		return 2
	end
	return 3
end

-- Plant on a river brush, the canal, or a crab approach inside place range.
-- A farther spot in the approach band is stepped toward, still inside range.
-- Nil while standing under an enemy post, or when the plant point would be.
function BotShopLogic.controlDestination(
	x: number,
	z: number,
	placeRange: number,
	spots: { VisionSpot },
	posts: { Post }
): (number?, number?, SpotKind?)
	if placeRange <= 0 or BotShopLogic.underEnemyPost(x, z, posts) then
		return nil, nil, nil
	end
	local approach = placeRange * BotShopLogic.ControlApproachMul
	local approachSq = approach * approach
	local rangeSq = placeRange * placeRange
	local bestRank = 99
	local bestDist = math.huge
	local bestX: number? = nil
	local bestZ: number? = nil
	local bestKind: SpotKind? = nil
	local function consider(spot: VisionSpot, distSq: number, px: number, pz: number)
		if BotShopLogic.underEnemyPost(px, pz, posts) then
			return
		end
		local rank = spotRank(spot.kind)
		if rank > bestRank or (rank == bestRank and distSq >= bestDist) then
			return
		end
		bestRank = rank
		bestDist = distSq
		bestX = px
		bestZ = pz
		bestKind = spot.kind
	end
	-- A spot already inside place range beats a step toward a farther one.
	for _, spot in spots do
		if BotShopLogic.underEnemyPost(spot.x, spot.z, posts) then
			continue
		end
		local distSq = flatSq(x, z, spot.x, spot.z)
		if distSq <= rangeSq then
			consider(spot, distSq, spot.x, spot.z)
		end
	end
	if bestX == nil then
		for _, spot in spots do
			if BotShopLogic.underEnemyPost(spot.x, spot.z, posts) then
				continue
			end
			local distSq = flatSq(x, z, spot.x, spot.z)
			if distSq > approachSq or distSq <= rangeSq then
				continue
			end
			local dist = math.sqrt(distSq)
			local scale = placeRange / dist
			consider(spot, distSq, x + (spot.x - x) * scale, z + (spot.z - z) * scale)
		end
	end
	return bestX, bestZ, bestKind
end

return BotShopLogic
