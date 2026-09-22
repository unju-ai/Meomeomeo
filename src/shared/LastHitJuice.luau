--!strict

-- Pure rules for painting a local last-hit gold float.
-- FarmCredit still owns CS and purse math. This module only decides
-- whether a credit should be shown, and how to label / tint / merge it.
-- A last hit is cs > 0 (FarmCredit.lastHit). Bounties and nearby XP stay quiet.
-- Hub / Yarn Run / Koi / Party / Arcade stay quiet.

local CombatFloat = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CombatFloat"))

local LastHitJuice = {}

-- Night-market amber number, cream CS tick. Not a damage float.
LastHitJuice.Cream = CombatFloat.DamageCream
LastHitJuice.Amber = CombatFloat.GoldAmber
LastHitJuice.Ink = CombatFloat.Ink

-- Sit above the damage number on the same corpse. Display only.
LastHitJuice.Lift = 3.7
LastHitJuice.TextSize = 20

function LastHitJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

-- FarmCredit.lastHit is the only credit with cs > 0.
-- Kill / assist / tower bounties and nearby XP (cs 0) do not float.
function LastHitJuice.wantsFloat(cs: number, gold: number): boolean
	return cs > 0 and gold > 0
end

function LastHitJuice.isLocal(localUserId: number, creditedUserId: number?): boolean
	return creditedUserId ~= nil and localUserId == creditedUserId
end

function LastHitJuice.goldLabel(gold: number): string
	return CombatFloat.label("gold", gold)
end

function LastHitJuice.csLabel(cs: number): string
	local n = math.max(0, math.floor(cs + 0.5))
	return `+{n} CS`
end

-- Amber gold line, tiny cream CS tick. Rich text so the tick stays small.
function LastHitJuice.label(gold: number, cs: number): string
	local cream = LastHitJuice.Cream
	local hex = string.format("%02X%02X%02X", cream[1], cream[2], cream[3])
	return `<font size="{LastHitJuice.TextSize}">{LastHitJuice.goldLabel(gold)}</font>\n<font size="12" color="#{hex}">{LastHitJuice.csLabel(cs)}</font>`
end

function LastHitJuice.rgb(): { number }
	return LastHitJuice.Amber
end

-- Same 4-stud cell and kind prefix as CombatFloat, so a cleave stacks
-- and a gold pop never merges into a damage number.
function LastHitJuice.mergeKey(originX: number, originZ: number): string
	return CombatFloat.mergeKey("gold", originX, originZ, nil)
end

function LastHitJuice.tryMerge(
	slots: { CombatFloat.MergeSlot },
	key: string,
	gold: number,
	cs: number,
	now: number
): CombatFloat.MergeSlot?
	return CombatFloat.tryMerge(slots, key, "gold", gold, now, cs)
end

function LastHitJuice.canSpawn(activeCount: number): boolean
	return CombatFloat.canSpawn(activeCount)
end

-- One soft tick per new pop. A merge inside the window stays quiet.
function LastHitJuice.wantsCoin(merged: boolean): boolean
	return not merged
end

return LastHitJuice
