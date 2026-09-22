--!strict

-- Pure rules for the Cat Rift ability-refuse cue.
-- CombatService / WardService still own cooldown, mana, range, and the cast.
-- This module only classifies an error string the server already returned.
-- It does not invent a silence rule or a "no target" rule — those are not ability refuses.
-- A successful cast is not this path. Hub / Yarn Run / Koi / Party / Arcade stay quiet.
-- Auto-attack scratch, aim rings, and the cooldown sweep are not this module.

local AbilityRefuseJuice = {}

-- Night-market coral. Display only.
AbilityRefuseJuice.Coral = { 255, 118, 104 }

-- How long the slot wash stays up. It does not change the cooldown clock.
AbilityRefuseJuice.PulseSeconds = 0.34

-- Rapid Q/W/E/R or 4–7 mashing paints once, then waits.
AbilityRefuseJuice.Gap = 0.45

export type Reason = "cooldown" | "mana" | "range"
export type Rgb = { number }

-- Exact strings UseAbility / PlaceWard / UseLens / UseCleave already return.
local COOLDOWN = {
	["Ability on cooldown."] = true,
	["Trinket on cooldown."] = true,
	["Lens on cooldown."] = true,
	["Yarn Cleave is cooling down."] = true,
}

local RANGE = {
	["Out of range."] = true,
	["Ward out of range."] = true,
}

-- Cat Rift fight only.
function AbilityRefuseJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

-- Nil when the string is not one of the existing cast refuses.
-- "You are down", "not learned", "buy at Pawmart", and attack misses stay nil.
function AbilityRefuseJuice.reason(text: string?): Reason?
	if typeof(text) ~= "string" then
		return nil
	end
	if COOLDOWN[text] then
		return "cooldown"
	end
	if text == "Not enough mana." then
		return "mana"
	end
	if RANGE[text] then
		return "range"
	end
	return nil
end

function AbilityRefuseJuice.line(kind: string): string
	if kind == "cooldown" then
		return "On cooldown"
	end
	if kind == "mana" then
		return "Need mana"
	end
	if kind == "range" then
		return "Out of range"
	end
	return ""
end

function AbilityRefuseJuice.wantsCue(gameMode: string, phase: string?, text: string?): boolean
	if not AbilityRefuseJuice.modeAllows(gameMode, phase) then
		return false
	end
	return AbilityRefuseJuice.reason(text) ~= nil
end

-- QWER and the active chips. Not LMB, not a successful cast.
function AbilityRefuseJuice.isBarSlot(slot: string): boolean
	return slot == "Q" or slot == "W" or slot == "E" or slot == "R" or slot == "4" or slot == "5" or slot == "6" or slot == "7"
end

-- lastAt <= 0 means nothing has painted yet.
function AbilityRefuseJuice.due(lastAt: number, now: number): boolean
	if lastAt <= 0 then
		return true
	end
	return now - lastAt + 1e-6 >= AbilityRefuseJuice.Gap
end

-- A hit flash sits nearer 0.78. This tick stays fainter.
function AbilityRefuseJuice.tickPeak(): number
	return 0.91
end

-- remain is seconds left in the pulse. 1 = gone, lower = a stronger wash.
function AbilityRefuseJuice.slotTransparency(remain: number): number
	local u = 0
	if AbilityRefuseJuice.PulseSeconds > 0 then
		u = math.clamp(remain / AbilityRefuseJuice.PulseSeconds, 0, 1)
	end
	return 1 - 0.55 * u
end

function AbilityRefuseJuice.rgb(): Rgb
	return AbilityRefuseJuice.Coral
end

-- Successful casts keep their own juice. This path is the refuse only.
function AbilityRefuseJuice.paintsOnSuccess(): boolean
	return false
end

return AbilityRefuseJuice
