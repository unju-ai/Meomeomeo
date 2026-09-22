--!strict

-- Pure rules for painting a local bounty gold float.
-- FarmCredit still owns the purse. This module only decides whether a
-- bounty credit should be shown, and how to label / tint / merge it.
-- A bounty is gold with no CS (FarmCredit.bounty): champion kill, assist,
-- tower / nexus. Last hits (cs > 0) stay on LastHitJuice and stay amber.
-- Hub / Yarn Run / Koi / Party / Arcade stay quiet.

local CombatFloat = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CombatFloat"))

local BountyJuice = {}

-- Night-market peach, pulled toward coral. Not amber last-hit gold.
BountyJuice.Peach = CombatFloat.BountyPeach
BountyJuice.Ink = CombatFloat.Ink

-- Sit above the killing-blow number on the same cat. Display only.
BountyJuice.Lift = 4.4
BountyJuice.TextSize = 22

function BountyJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

-- FarmCredit.bounty is the only credit with gold and no CS.
-- Last hits and nearby XP (no gold) do not use this float.
function BountyJuice.wantsFloat(cs: number, gold: number): boolean
	return cs == 0 and gold > 0
end

function BountyJuice.isLocal(localUserId: number, creditedUserId: number?): boolean
	return creditedUserId ~= nil and localUserId == creditedUserId
end

function BountyJuice.goldLabel(gold: number): string
	return CombatFloat.label("bounty", gold)
end

function BountyJuice.rgb(): { number }
	return BountyJuice.Peach
end

-- Same 4-stud cell as CombatFloat, with a bounty prefix so a takedown
-- never merges into a last-hit coin or a damage number.
function BountyJuice.mergeKey(originX: number, originZ: number): string
	return CombatFloat.mergeKey("bounty", originX, originZ, nil)
end

function BountyJuice.tryMerge(
	slots: { CombatFloat.MergeSlot },
	key: string,
	gold: number,
	now: number
): CombatFloat.MergeSlot?
	return CombatFloat.tryMerge(slots, key, "bounty", gold, now)
end

function BountyJuice.canSpawn(activeCount: number): boolean
	return CombatFloat.canSpawn(activeCount)
end

-- One soft tick per new pop. A merge inside the window stays quiet.
function BountyJuice.wantsCoin(merged: boolean): boolean
	return not merged
end

return BountyJuice
