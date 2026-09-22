--!strict

-- Per-champion combat hooks for the three flagship cats.
-- CombatService is the only applier. Other champions get a zero plan.
-- Numbers here are the identity pass: guard, pull, takedown reset, channel, refund, zone.

local Types = require(script.Parent.Types)

export type Look = "guard" | "pull" | "channel" | "rainbow" | "laser" | "zone"

export type CastPlan = {
	guardSeconds: number,
	guardReduction: number,
	channelSeconds: number,
	interruptCooldown: number,
	interruptMana: number,
	pullStuds: number,
	zoneSeconds: number,
	zoneTick: number,
	zonePulses: number,
}

local MEOW_GUARD_SECONDS = 2.5
local MEOW_GUARD_CUT = 0.35
local MEOW_PULL_STUDS = 12
local NYAN_CHANNEL_SECONDS = 0.55
local NYAN_INTERRUPT_COOLDOWN = 10
local NYAN_INTERRUPT_MANA = 60
local WHISK_REFUND = 22
local WHISK_ZONE_SECONDS = 2.4
local WHISK_ZONE_TICK = 0.8
local WHISK_ZONE_PULSES = 3

local ChampionKits = {}

local function zero(): CastPlan
	return {
		guardSeconds = 0,
		guardReduction = 0,
		channelSeconds = 0,
		interruptCooldown = 0,
		interruptMana = 0,
		pullStuds = 0,
		zoneSeconds = 0,
		zoneTick = 0,
		zonePulses = 0,
	}
end

function ChampionKits.plan(championId: string, slot: Types.AbilitySlot, stunSeconds: number): CastPlan
	if championId == "ChairmanMeow" and slot == "W" then
		local plan = zero()
		plan.guardSeconds = MEOW_GUARD_SECONDS
		plan.guardReduction = MEOW_GUARD_CUT
		return plan
	end
	if championId == "ChairmanMeow" and slot == "R" then
		local plan = zero()
		if stunSeconds > 0 then
			plan.pullStuds = MEOW_PULL_STUDS
		end
		return plan
	end
	if championId == "NyanRocket" and slot == "R" then
		local plan = zero()
		plan.channelSeconds = NYAN_CHANNEL_SECONDS
		plan.interruptCooldown = NYAN_INTERRUPT_COOLDOWN
		plan.interruptMana = NYAN_INTERRUPT_MANA
		return plan
	end
	if championId == "ProfessorWhiskers" and slot == "E" then
		local plan = zero()
		plan.zoneSeconds = WHISK_ZONE_SECONDS
		plan.zoneTick = WHISK_ZONE_TICK
		plan.zonePulses = WHISK_ZONE_PULSES
		return plan
	end
	return zero()
end

function ChampionKits.refundMana(championId: string, slot: Types.AbilitySlot): number
	if championId == "ProfessorWhiskers" and slot == "Q" then
		return WHISK_REFUND
	end
	return 0
end

function ChampionKits.onTakedown(championId: string): { Types.AbilitySlot }?
	if championId == "NyanRocket" then
		return { "Q", "W", "E" }
	end
	return nil
end

function ChampionKits.guardMultiplier(reduction: number, active: boolean): number
	if not active or reduction <= 0 then
		return 1
	end
	return 1 - math.clamp(reduction, 0, 0.75)
end

-- Flat pull toward the decree center. Stops short of the point so targets do not stack inside it.
function ChampionKits.pullPosition(origin: Vector3, center: Vector3, studs: number): Vector3
	if studs <= 0 then
		return origin
	end
	local flat = Vector3.new(center.X - origin.X, 0, center.Z - origin.Z)
	local mag = flat.Magnitude
	if mag < 1.25 then
		return origin
	end
	local step = math.min(studs, mag - 0.5)
	local unit = flat.Unit
	return Vector3.new(origin.X + unit.X * step, origin.Y, origin.Z + unit.Z * step)
end

function ChampionKits.pulsePower(total: number, pulses: number): number
	if pulses <= 1 then
		return total
	end
	return total / pulses
end

function ChampionKits.look(championId: string, slot: Types.AbilitySlot): Look?
	if championId == "ChairmanMeow" and slot == "W" then
		return "guard"
	end
	if championId == "ChairmanMeow" and slot == "R" then
		return "pull"
	end
	if championId == "NyanRocket" and slot == "Q" then
		return "rainbow"
	end
	if championId == "NyanRocket" and slot == "R" then
		return "channel"
	end
	if championId == "ProfessorWhiskers" and slot == "Q" then
		return "laser"
	end
	if championId == "ProfessorWhiskers" and slot == "E" then
		return "zone"
	end
	return nil
end

function ChampionKits.castPitch(championId: string, slot: Types.AbilitySlot): number
	local look = ChampionKits.look(championId, slot)
	if look == "pull" then
		return 0.68
	elseif look == "channel" then
		return 1.42
	elseif look == "zone" then
		return 0.86
	end
	return 1
end

function ChampionKits.breakPitch(championId: string, slot: Types.AbilitySlot): number?
	if championId == "NyanRocket" and slot == "R" then
		return 0.55
	end
	return nil
end

function ChampionKits.helpRows(): { { string } }
	return {
		{ "Meow", "W: guard · R: pull stun" },
		{ "Nyan", "Kill resets QWE · R can break" },
		{ "Whisk", "Q mana back · E zone ticks" },
	}
end

function ChampionKits.practiceTip(): string
	return "Meow — W: short damage cut. R: pull + stun. Nyan — a takedown resets Q W E. R: beam you can cancel. Whiskers — Q hit refunds mana. E: zone that keeps ticking."
end

return ChampionKits
