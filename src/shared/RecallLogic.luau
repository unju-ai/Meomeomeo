--!strict

-- Which intents cancel a Cat Rift recall channel.
-- CombatService applies this. The client uses the move-order rule so a direction
-- already held when F was pressed is not a new command. Not vision, not replicated.

local RecallLogic = {}

-- Camera, help, emotes, pings, and opening the shop are intentionally absent.
local BREAKS_CHANNEL: { [string]: boolean } = {
	move = true,
	attack = true,
	attackMove = true,
	ability = true,
	stop = true,
	ward = true,
	control = true,
	lens = true,
	damage = true,
}

function RecallLogic.breaksChannel(order: string): boolean
	return BREAKS_CHANNEL[order] == true
end

-- A stick or key already held when the channel started is the old order.
-- Recall cancels when a new one begins: a fresh press, or the stick returns
-- to rest and then deflects again.
function RecallLogic.isNewMoveOrder(heldAtStart: boolean, movingNow: boolean, sawRest: boolean): boolean
	if not movingNow then
		return false
	end
	if not heldAtStart then
		return true
	end
	return sawRest
end

-- Shove / knockback fallback. Orders cancel before this distance matters.
function RecallLogic.movedTooFar(distance: number, limit: number): boolean
	return distance > limit
end

return RecallLogic
