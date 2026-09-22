--!strict

-- Pure rules for painting a local XP float.
-- MatchService still owns the grant (nearby kitten / camp, last-hit XP,
-- kill, assist). This module only decides whether that same delta should
-- be shown, and how to label / tint / merge it.
-- Level-up stays on LevelUpJuice. A grant that tips a level may still paint.
-- Hub / Yarn Run / Koi / Party / Arcade stay quiet.

local CombatFloat = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CombatFloat"))

local XpJuice = {}

-- Night-market cream/lavender. Not amber last-hit gold, not peach bounty.
XpJuice.Lavender = CombatFloat.XpLavender
XpJuice.Ink = CombatFloat.Ink

-- Sit above gold and bounty when a corpse pays both. Display only.
XpJuice.Lift = 5.15
XpJuice.TextSize = 18

function XpJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

-- The granted delta. Zero credits stay quiet. Gold and CS are not this float.
function XpJuice.wantsFloat(xp: number): boolean
	return xp > 0
end

function XpJuice.isLocal(localUserId: number, creditedUserId: number?): boolean
	return creditedUserId ~= nil and localUserId == creditedUserId
end

function XpJuice.label(xp: number): string
	return CombatFloat.label("xp", xp)
end

function XpJuice.rgb(): { number }
	return XpJuice.Lavender
end

-- Same 4-stud cell as CombatFloat, with an xp prefix so a share never
-- merges into last-hit gold, bounty gold, or a damage number.
function XpJuice.mergeKey(originX: number, originZ: number): string
	return CombatFloat.mergeKey("xp", originX, originZ, nil)
end

function XpJuice.tryMerge(
	slots: { CombatFloat.MergeSlot },
	key: string,
	xp: number,
	now: number
): CombatFloat.MergeSlot?
	return CombatFloat.tryMerge(slots, key, "xp", xp, now)
end

function XpJuice.canSpawn(activeCount: number): boolean
	return CombatFloat.canSpawn(activeCount)
end

-- Gold pops tick a coin. XP stays silent so a wave does not chirp.
function XpJuice.wantsCoin(_merged: boolean): boolean
	return false
end

-- LevelUpJuice owns the banner and the LEVEL n float. This tick never does.
function XpJuice.paintsLevelBanner(): boolean
	return false
end

return XpJuice
