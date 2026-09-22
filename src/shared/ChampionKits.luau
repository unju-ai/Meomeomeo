--!strict

-- Per-champion combat hooks. CombatService is the only applier.
-- Flagship three: guard, pull, takedown reset, channel, refund, zone.
-- Original three: Settled Loaf + Charge Knock, Open Wick + Hype Candle, Second Helping + Sweater Aura.
-- The eight expansion champions stay on the zero plan.

local Types = require(script.Parent.Types)

export type Look = "guard" | "pull" | "channel" | "rainbow" | "laser" | "zone" | "knock" | "wick" | "candle" | "sweater"

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
	knockStuds: number,
	knockStun: number,
	wickGain: number,
	wickCap: number,
	wickSeconds: number,
	wickBonus: number,
	auraGuardSeconds: number,
	auraGuardReduction: number,
}

export type Identity = {
	passive: string,
	signature: string,
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
local CHONK_GUARD_SECONDS = 2.2
local CHONK_GUARD_CUT = 0.3
local CHONK_KNOCK_STUDS = 10
local CHONK_KNOCK_STUN = 0.45
local SCAMMY_WICK_CAP = 3
local SCAMMY_WICK_SECONDS = 8
local SCAMMY_WICK_BONUS = 0.4
local GRANDMA_HEAL_AMP = 1.22
local GRANDMA_AURA_SECONDS = 2.4
local GRANDMA_AURA_CUT = 0.22

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
		knockStuds = 0,
		knockStun = 0,
		wickGain = 0,
		wickCap = 0,
		wickSeconds = 0,
		wickBonus = 0,
		auraGuardSeconds = 0,
		auraGuardReduction = 0,
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
	if championId == "ChonkKnight" and slot == "E" then
		local plan = zero()
		plan.guardSeconds = CHONK_GUARD_SECONDS
		plan.guardReduction = CHONK_GUARD_CUT
		return plan
	end
	if championId == "ChonkKnight" and slot == "Q" then
		local plan = zero()
		plan.knockStuds = CHONK_KNOCK_STUDS
		plan.knockStun = CHONK_KNOCK_STUN
		return plan
	end
	if championId == "ScammyMcMittens" and slot == "Q" then
		local plan = zero()
		plan.wickGain = 1
		plan.wickCap = SCAMMY_WICK_CAP
		plan.wickSeconds = SCAMMY_WICK_SECONDS
		return plan
	end
	if championId == "ScammyMcMittens" and slot == "E" then
		local plan = zero()
		plan.wickBonus = SCAMMY_WICK_BONUS
		return plan
	end
	if championId == "GrandmaFluff" and slot == "W" then
		local plan = zero()
		plan.auraGuardSeconds = GRANDMA_AURA_SECONDS
		plan.auraGuardReduction = GRANDMA_AURA_CUT
		return plan
	end
	return zero()
end

function ChampionKits.identity(championId: string): Identity?
	if championId == "ChonkKnight" then
		return { passive = "Settled Loaf", signature = "Charge Knock" }
	end
	if championId == "ScammyMcMittens" then
		return { passive = "Open Wick", signature = "Hype Candle" }
	end
	if championId == "GrandmaFluff" then
		return { passive = "Second Helping", signature = "Sweater Aura" }
	end
	return nil
end

function ChampionKits.refundMana(championId: string, slot: Types.AbilitySlot): number
	if championId == "ProfessorWhiskers" and slot == "Q" then
		return WHISK_REFUND
	end
	return 0
end

function ChampionKits.healMultiplier(championId: string): number
	if championId == "GrandmaFluff" then
		return GRANDMA_HEAL_AMP
	end
	return 1
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

-- Keep a stronger guard that is still up. An equal cut refreshes.
function ChampionKits.preferGuard(currentReduction: number, active: boolean, nextReduction: number): boolean
	if nextReduction <= 0 then
		return false
	end
	if not active then
		return true
	end
	return nextReduction + 1e-4 >= currentReduction
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

-- Shove along the charge, from the target, by a fixed step. A tiny roll does not move anyone.
function ChampionKits.knockPosition(from: Vector3, origin: Vector3, dest: Vector3, studs: number): Vector3
	if studs <= 0 then
		return from
	end
	local flat = Vector3.new(dest.X - origin.X, 0, dest.Z - origin.Z)
	if flat.Magnitude < 0.5 then
		return from
	end
	local unit = flat.Unit
	return Vector3.new(from.X + unit.X * studs, from.Y, from.Z + unit.Z * studs)
end

function ChampionKits.addWick(stacks: number, cap: number): number
	if cap <= 0 then
		return 0
	end
	return math.min(cap, math.max(0, stacks) + 1)
end

function ChampionKits.wickPower(stacks: number, bonus: number): number
	if stacks <= 0 or bonus <= 0 then
		return 1
	end
	return 1 + stacks * bonus
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
	if championId == "ChonkKnight" and slot == "Q" then
		return "knock"
	end
	if championId == "ChonkKnight" and slot == "E" then
		return "guard"
	end
	if championId == "ScammyMcMittens" and slot == "Q" then
		return "wick"
	end
	if championId == "ScammyMcMittens" and slot == "E" then
		return "candle"
	end
	if championId == "GrandmaFluff" and slot == "W" then
		return "sweater"
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
	elseif look == "knock" then
		return 0.72
	elseif look == "wick" then
		return 1.28
	elseif look == "candle" then
		return 1.12
	elseif look == "sweater" then
		return 0.82
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
		{ "Chonk", "E: loaf · Q: knock" },
		{ "Scammy", "Q: wick · E: candle" },
		{ "Grandma", "Heals amp · W: aura" },
	}
end

function ChampionKits.practiceTip(): string
	return "Meow — W: short damage cut. R: pull + stun. Nyan — a takedown resets Q W E. R: beam you can cancel. Whiskers — Q hit refunds mana. E: zone that keeps ticking."
end

function ChampionKits.practiceTipMore(): string
	return "Chonk — Settled Loaf: E cuts damage after the flop. Charge Knock: Q bowls champs. Scammy — Open Wick stacks on Q (max 3). Hype Candle spends them. Grandma — Second Helping boosts heals. Sweater Aura on W cuts damage."
end

return ChampionKits
