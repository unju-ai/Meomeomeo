--!strict

-- Pure rules for the Cat Rift ability-cast confirmation.
-- CombatService / WardService still own cooldown, mana, range, and the cast.
-- This module only reads a result that already came back ok = true.
-- It does not toast a reason line. AbilityRefuseJuice still owns the coral fail.
-- A same-slot channel cancel is not a new cast. Hub modes stay quiet.
-- Kit bolts, zones, and the scratch arc are not this module.

local AbilitySuccessJuice = {}

-- Night-market cream wash. Display only.
AbilitySuccessJuice.Cream = { 255, 243, 224 }

-- Amber rim on that same slot. Display only.
AbilitySuccessJuice.Amber = { 255, 196, 74 }

-- Brief confirmation. Shorter than the refuse wash. It does not change the cooldown clock.
AbilitySuccessJuice.PulseSeconds = 0.28

export type Rgb = { number }

-- Cat Rift fight only.
function AbilitySuccessJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

-- QWER and the active chips. Not LMB, not an attack.
function AbilitySuccessJuice.isBarSlot(slot: string): boolean
	return slot == "Q" or slot == "W" or slot == "E" or slot == "R" or slot == "4" or slot == "5" or slot == "6" or slot == "7"
end

-- ok must be the boolean the server already returned.
-- A missing flag, a refuse, and a same-slot channel cancel stay false.
function AbilitySuccessJuice.wantsCue(gameMode: string, phase: string?, ok: boolean, slot: string, cancelled: boolean?): boolean
	if ok ~= true or cancelled == true then
		return false
	end
	if not AbilitySuccessJuice.modeAllows(gameMode, phase) then
		return false
	end
	return AbilitySuccessJuice.isBarSlot(slot)
end

-- A refuse tick sits at 0.91. A hit flash sits nearer 0.78.
-- Higher means fainter. This tick stays quieter than both.
function AbilitySuccessJuice.tickPeak(): number
	return 0.955
end

-- remain is seconds left in the pulse. 1 = gone, lower = a stronger wash.
function AbilitySuccessJuice.slotTransparency(remain: number): number
	local u = 0
	if AbilitySuccessJuice.PulseSeconds > 0 then
		u = math.clamp(remain / AbilitySuccessJuice.PulseSeconds, 0, 1)
	end
	return 1 - 0.42 * u
end

function AbilitySuccessJuice.washRgb(): Rgb
	return AbilitySuccessJuice.Cream
end

function AbilitySuccessJuice.rimRgb(): Rgb
	return AbilitySuccessJuice.Amber
end

-- Success is the slot wash. There is no reason banner.
function AbilitySuccessJuice.paintsBanner(): boolean
	return false
end

return AbilitySuccessJuice
