--!strict

-- Practice-bot Pawmart plans. BotService still calls ShopService.buyAt
-- (fountain, gold, and stack checks — the same body humans hit with B).
-- Jungle routing stays in JungleBotLogic. This module only picks the next
-- item and when an active is worth pressing.
--
-- Hard buys at the opening fountain, then finishes the list on later visits.
-- The next unaffordable item blocks the rest of the list so a cheap lens
-- cannot spend the gold a Fang or Cleave is waiting on.
-- Easy is one Mana Treat after they have already left home. Normal is two
-- stat sticks on a fountain return. Nobody buys Control Yarn — Hard still
-- plants one free pink.

local ItemCatalog = require(script.Parent.ItemCatalog)

local BotShopLogic = {}

export type Difficulty = "Easy" | "Normal" | "Hard"
export type Line = "tank" | "assassin" | "mage"

-- Safety cap for one fountain visit. Longer than every plan below.
BotShopLogic.MaxBuysPerVisit = 6
BotShopLogic.CleaveMinEnemies = 2

local EASY: { string } = { "ManaTreat" }

local NORMAL: { [Line]: { string } } = {
	tank = { "Yarnplate", "PounceBoots" },
	assassin = { "Longclaw", "PounceBoots" },
	mage = { "ManaTreat", "Longclaw" },
}

-- Opening purse is 500. Yarnplate+Charm, Longclaw+Boots, and Treat+Longclaw
-- all fit. Stall Fang (300) and Yarn Cleave (280) wait until a later visit.
local HARD: { [Line]: { string } } = {
	tank = { "Yarnplate", "PaperCharm", "YarnCleave", "WhiskerLens" },
	assassin = { "Longclaw", "PounceBoots", "StallFang", "YarnCleave", "WhiskerLens" },
	mage = { "ManaTreat", "Longclaw", "YarnCleave", "WhiskerLens" },
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

-- First unowned item the purse can afford, in plan order. Nil when the next
-- core is too expensive or the plan is already owned. Does not skip ahead.
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

return BotShopLogic
