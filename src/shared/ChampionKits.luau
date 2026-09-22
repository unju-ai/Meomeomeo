--!strict

-- Per-champion combat hooks. CombatService is the only applier.
-- Flagship three: guard, pull, takedown reset, channel, refund, zone.
-- Original three: Settled Loaf + Charge Knock, Open Wick + Hype Candle, Second Helping + Sweater Aura.
-- Expansion three: Packet Buffer + Overclock, Honor Bleed + Shield Fortify, Alley Mark + Smoke Vanish.
-- Expansion three more: Chrome Plate + Lunge Reload, Ward Omen + Foresight Veil, Spell Charge + Charged Meteor.
-- Last two: Curse Stacks + Hex Zone, Psi Mark + Mind Nudge.

local Types = require(script.Parent.Types)

export type Look =
	"guard"
	| "pull"
	| "channel"
	| "rainbow"
	| "laser"
	| "zone"
	| "knock"
	| "wick"
	| "candle"
	| "sweater"
	| "data"
	| "overclock"
	| "bleed"
	| "fortify"
	| "mark"
	| "vanish"
	| "plate"
	| "reload"
	| "omen"
	| "charge"
	| "meteor"
	| "curse"
	| "hex"
	| "psi"
	| "nudge"

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
	dataGain: number,
	dataCap: number,
	dataSeconds: number,
	overclockPer: number,
	bleedGain: number,
	bleedCap: number,
	bleedSeconds: number,
	bleedBonus: number,
	bleedSpend: number,
	fortifySeconds: number,
	fortifyReduction: number,
	markGain: number,
	markSeconds: number,
	ambushSpend: number,
	vanishBonus: number,
	markBonus: number,
	vanishSeconds: number,
	plateGain: number,
	plateCap: number,
	plateSeconds: number,
	platePer: number,
	plateSpend: number,
	plateBonus: number,
	plateReload: number,
	wardRange: number,
	wardAmp: number,
	omenSeconds: number,
	omenCut: number,
	chargeGain: number,
	chargeCap: number,
	chargeSeconds: number,
	chargeSpend: number,
	chargeBonus: number,
	curseGain: number,
	curseCap: number,
	curseSeconds: number,
	curseTick: number,
	cursePer: number,
	hexSeconds: number,
	hexTick: number,
	hexPulses: number,
	hexShare: number,
	hexBonus: number,
	psiGain: number,
	psiSeconds: number,
	psiBonus: number,
	nudgeStuds: number,
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
local BYTE_DATA_CAP = 3
local BYTE_DATA_SECONDS = 6
local BYTE_OVERCLOCK_PER = 42
local SCRATCH_BLEED_CAP = 3
local SCRATCH_BLEED_SECONDS = 7
local SCRATCH_BLEED_BONUS = 0.18
local SCRATCH_SPEND_BONUS = 0.34
local SCRATCH_FORTIFY_SECONDS = 2
local SCRATCH_FORTIFY_CUT = 0.28
local SHADOW_MARK_SECONDS = 6
local SHADOW_VANISH_SECONDS = 2.5
local SHADOW_VANISH_BONUS = 0.4
local SHADOW_MARK_BONUS = 0.55
local CHROME_PLATE_CAP = 3
local CHROME_PLATE_SECONDS = 7
local CHROME_PLATE_PER = 0.06
local CHROME_LUNGE_BONUS = 0.22
local CHROME_LUNGE_RELOAD = 1.4
local ORACLE_WARD_RANGE = 24
local ORACLE_WARD_AMP = 0.28
local ORACLE_OMEN_SECONDS = 3.2
local ORACLE_OMEN_CUT = 0.3
local ARCH_CHARGE_CAP = 3
local ARCH_CHARGE_SECONDS = 8
local ARCH_METEOR_BONUS = 0.3
local HEX_CURSE_CAP = 3
local HEX_CURSE_SECONDS = 6
local HEX_CURSE_TICK = 1
local HEX_CURSE_PER = 8
local HEX_ZONE_SECONDS = 2.4
local HEX_ZONE_TICK = 0.8
local HEX_ZONE_PULSES = 3
local HEX_ZONE_SHARE = 0.16
local HEX_ZONE_BONUS = 0.25
local PSI_MARK_SECONDS = 6
local PSI_SEEN_BONUS = 0.35
local MIND_NUDGE_STUDS = 8

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
		dataGain = 0,
		dataCap = 0,
		dataSeconds = 0,
		overclockPer = 0,
		bleedGain = 0,
		bleedCap = 0,
		bleedSeconds = 0,
		bleedBonus = 0,
		bleedSpend = 0,
		fortifySeconds = 0,
		fortifyReduction = 0,
		markGain = 0,
		markSeconds = 0,
		ambushSpend = 0,
		vanishBonus = 0,
		markBonus = 0,
		vanishSeconds = 0,
		plateGain = 0,
		plateCap = 0,
		plateSeconds = 0,
		platePer = 0,
		plateSpend = 0,
		plateBonus = 0,
		plateReload = 0,
		wardRange = 0,
		wardAmp = 0,
		omenSeconds = 0,
		omenCut = 0,
		chargeGain = 0,
		chargeCap = 0,
		chargeSeconds = 0,
		chargeSpend = 0,
		chargeBonus = 0,
		curseGain = 0,
		curseCap = 0,
		curseSeconds = 0,
		curseTick = 0,
		cursePer = 0,
		hexSeconds = 0,
		hexTick = 0,
		hexPulses = 0,
		hexShare = 0,
		hexBonus = 0,
		psiGain = 0,
		psiSeconds = 0,
		psiBonus = 0,
		nudgeStuds = 0,
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
	if championId == "Bytekit" and slot == "Q" then
		local plan = zero()
		plan.dataGain = 1
		plan.dataCap = BYTE_DATA_CAP
		plan.dataSeconds = BYTE_DATA_SECONDS
		return plan
	end
	if championId == "Bytekit" and slot == "W" then
		local plan = zero()
		plan.overclockPer = BYTE_OVERCLOCK_PER
		return plan
	end
	if championId == "SirScratchalot" and slot == "Q" then
		local plan = zero()
		plan.bleedGain = 1
		plan.bleedCap = SCRATCH_BLEED_CAP
		plan.bleedSeconds = SCRATCH_BLEED_SECONDS
		plan.bleedBonus = SCRATCH_BLEED_BONUS
		return plan
	end
	if championId == "SirScratchalot" and slot == "E" then
		local plan = zero()
		plan.bleedSpend = 1
		plan.bleedBonus = SCRATCH_SPEND_BONUS
		plan.fortifySeconds = SCRATCH_FORTIFY_SECONDS
		plan.fortifyReduction = SCRATCH_FORTIFY_CUT
		return plan
	end
	if championId == "SirScratchalot" and slot == "R" then
		local plan = zero()
		plan.bleedBonus = SCRATCH_BLEED_BONUS
		return plan
	end
	if championId == "Shadowpounce" and slot == "Q" then
		local plan = zero()
		plan.markGain = 1
		plan.markSeconds = SHADOW_MARK_SECONDS
		plan.ambushSpend = 1
		plan.vanishBonus = SHADOW_VANISH_BONUS
		plan.markBonus = SHADOW_MARK_BONUS
		return plan
	end
	if championId == "Shadowpounce" and (slot == "E" or slot == "R") then
		local plan = zero()
		plan.ambushSpend = 1
		plan.vanishBonus = SHADOW_VANISH_BONUS
		plan.markBonus = SHADOW_MARK_BONUS
		return plan
	end
	if championId == "Shadowpounce" and slot == "W" then
		local plan = zero()
		plan.vanishSeconds = SHADOW_VANISH_SECONDS
		return plan
	end
	if championId == "Chromeclaw" and slot == "Q" then
		local plan = zero()
		plan.plateGain = 1
		plan.plateCap = CHROME_PLATE_CAP
		plan.plateSeconds = CHROME_PLATE_SECONDS
		plan.platePer = CHROME_PLATE_PER
		return plan
	end
	if championId == "Chromeclaw" and slot == "E" then
		local plan = zero()
		plan.plateSpend = 1
		plan.plateBonus = CHROME_LUNGE_BONUS
		plan.plateReload = CHROME_LUNGE_RELOAD
		return plan
	end
	if championId == "OraclePaws" and (slot == "W" or slot == "R") then
		local plan = zero()
		plan.wardRange = ORACLE_WARD_RANGE
		plan.wardAmp = ORACLE_WARD_AMP
		return plan
	end
	if championId == "OraclePaws" and slot == "E" then
		local plan = zero()
		plan.wardRange = ORACLE_WARD_RANGE
		plan.wardAmp = ORACLE_WARD_AMP
		plan.omenSeconds = ORACLE_OMEN_SECONDS
		plan.omenCut = ORACLE_OMEN_CUT
		return plan
	end
	if championId == "Archmeow" and slot == "Q" then
		local plan = zero()
		plan.chargeGain = 1
		plan.chargeCap = ARCH_CHARGE_CAP
		plan.chargeSeconds = ARCH_CHARGE_SECONDS
		return plan
	end
	if championId == "Archmeow" and slot == "R" then
		local plan = zero()
		plan.chargeSpend = 1
		plan.chargeBonus = ARCH_METEOR_BONUS
		return plan
	end
	if championId == "Hexkit" and slot == "Q" then
		local plan = zero()
		plan.curseGain = 1
		plan.curseCap = HEX_CURSE_CAP
		plan.curseSeconds = HEX_CURSE_SECONDS
		plan.curseTick = HEX_CURSE_TICK
		plan.cursePer = HEX_CURSE_PER
		return plan
	end
	if championId == "Hexkit" and slot == "R" then
		local plan = zero()
		plan.hexSeconds = HEX_ZONE_SECONDS
		plan.hexTick = HEX_ZONE_TICK
		plan.hexPulses = HEX_ZONE_PULSES
		plan.hexShare = HEX_ZONE_SHARE
		plan.hexBonus = HEX_ZONE_BONUS
		return plan
	end
	if championId == "Mindwhisker" and slot == "Q" then
		local plan = zero()
		plan.psiGain = 1
		plan.psiSeconds = PSI_MARK_SECONDS
		plan.psiBonus = PSI_SEEN_BONUS
		return plan
	end
	if championId == "Mindwhisker" and slot == "E" then
		local plan = zero()
		plan.nudgeStuds = MIND_NUDGE_STUDS
		plan.psiBonus = PSI_SEEN_BONUS
		return plan
	end
	if championId == "Mindwhisker" and slot == "R" then
		local plan = zero()
		plan.psiBonus = PSI_SEEN_BONUS
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
	if championId == "Bytekit" then
		return { passive = "Packet Buffer", signature = "Overclock" }
	end
	if championId == "SirScratchalot" then
		return { passive = "Honor Bleed", signature = "Shield Fortify" }
	end
	if championId == "Shadowpounce" then
		return { passive = "Alley Mark", signature = "Smoke Vanish" }
	end
	if championId == "Chromeclaw" then
		return { passive = "Chrome Plate", signature = "Lunge Reload" }
	end
	if championId == "OraclePaws" then
		return { passive = "Ward Omen", signature = "Foresight Veil" }
	end
	if championId == "Archmeow" then
		return { passive = "Spell Charge", signature = "Charged Meteor" }
	end
	if championId == "Hexkit" then
		return { passive = "Curse Stacks", signature = "Hex Zone" }
	end
	if championId == "Mindwhisker" then
		return { passive = "Psi Mark", signature = "Mind Nudge" }
	end
	return nil
end

-- Draft-card kit teaser. Flagships keep identity() nil (combat hooks only);
-- this labels all 14 for ChampionSelect without dumping full guides.
function ChampionKits.teaser(championId: string): Identity?
	local known = ChampionKits.identity(championId)
	if known then
		return known
	end
	if championId == "ChairmanMeow" then
		return { passive = "Golden Parachute", signature = "Executive Order" }
	end
	if championId == "NyanRocket" then
		return { passive = "Encore", signature = "Hyperbeam" }
	end
	if championId == "ProfessorWhiskers" then
		return { passive = "Office Hours", signature = "Pop Quiz" }
	end
	return nil
end

function ChampionKits.teaserLine(championId: string): string
	local kit = ChampionKits.teaser(championId)
	if not kit then
		return ""
	end
	return `{kit.passive} · {kit.signature}`
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

function ChampionKits.addData(stacks: number, cap: number): number
	if cap <= 0 then
		return 0
	end
	return math.min(cap, math.max(0, stacks) + 1)
end

function ChampionKits.overclockShield(stacks: number, per: number): number
	if stacks <= 0 or per <= 0 then
		return 0
	end
	return stacks * per
end

function ChampionKits.addBleed(stacks: number, cap: number): number
	if cap <= 0 then
		return 0
	end
	return math.min(cap, math.max(0, stacks) + 1)
end

function ChampionKits.bleedPower(stacks: number, bonus: number): number
	if stacks <= 0 or bonus <= 0 then
		return 1
	end
	return 1 + stacks * bonus
end

function ChampionKits.marksFromBrush(markGain: number, inBrush: boolean): boolean
	return markGain > 0 and inBrush
end

function ChampionKits.addPlate(stacks: number, cap: number): number
	if cap <= 0 then
		return 0
	end
	return math.min(cap, math.max(0, stacks) + 1)
end

-- Each live plate shaves a slice of incoming damage. Capped so it stays under a real guard.
function ChampionKits.plateMultiplier(stacks: number, per: number): number
	if stacks <= 0 or per <= 0 then
		return 1
	end
	return 1 - math.clamp(stacks * per, 0, 0.45)
end

function ChampionKits.platePower(stacks: number, bonus: number): number
	if stacks <= 0 or bonus <= 0 then
		return 1
	end
	return 1 + stacks * bonus
end

function ChampionKits.plateRefund(stacks: number, per: number): number
	if stacks <= 0 or per <= 0 then
		return 0
	end
	return stacks * per
end

function ChampionKits.shortenReady(readyAt: number, at: number, refund: number): number
	if refund <= 0 then
		return readyAt
	end
	return math.max(at, readyAt - refund)
end

-- Flat distance to the nearest allied ward. math.huge means none.
function ChampionKits.wardNear(distance: number, range: number): boolean
	return range > 0 and distance >= 0 and distance <= range
end

function ChampionKits.wardPower(bonus: number): number
	if bonus <= 0 then
		return 1
	end
	return 1 + bonus
end

-- One hit, then the veil is gone. Not a damage-cut window.
function ChampionKits.omenMultiplier(cut: number): number
	if cut <= 0 then
		return 1
	end
	return 1 - math.clamp(cut, 0, 0.6)
end

function ChampionKits.addCharge(stacks: number, cap: number): number
	if cap <= 0 then
		return 0
	end
	return math.min(cap, math.max(0, stacks) + 1)
end

function ChampionKits.chargePower(stacks: number, bonus: number): number
	if stacks <= 0 or bonus <= 0 then
		return 1
	end
	return 1 + stacks * bonus
end

function ChampionKits.addCurse(stacks: number, cap: number): number
	if cap <= 0 then
		return 0
	end
	return math.min(cap, math.max(0, stacks) + 1)
end

-- Flat burn per tick. Armor still applies when the server deals it.
function ChampionKits.curseDamage(stacks: number, per: number): number
	if stacks <= 0 or per <= 0 then
		return 0
	end
	return stacks * per
end

-- Zone ticks only. The nova's first hit stays on the printed number.
function ChampionKits.hexPower(stacks: number, bonus: number): number
	if stacks <= 0 or bonus <= 0 then
		return 1
	end
	return 1 + stacks * bonus
end

-- The mark only amplifies a hit the caster can currently see.
function ChampionKits.psiPower(bonus: number, seen: boolean): number
	if not seen or bonus <= 0 then
		return 1
	end
	return 1 + bonus
end

function ChampionKits.ambushPower(vanishBonus: number, markBonus: number): number
	local bonus = 0
	if vanishBonus > 0 then
		bonus += vanishBonus
	end
	if markBonus > 0 then
		bonus += markBonus
	end
	if bonus <= 0 then
		return 1
	end
	return 1 + bonus
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
	if championId == "Bytekit" and slot == "Q" then
		return "data"
	end
	if championId == "Bytekit" and slot == "W" then
		return "overclock"
	end
	if championId == "SirScratchalot" and slot == "Q" then
		return "bleed"
	end
	if championId == "SirScratchalot" and slot == "E" then
		return "fortify"
	end
	if championId == "Shadowpounce" and slot == "Q" then
		return "mark"
	end
	if championId == "Shadowpounce" and slot == "W" then
		return "vanish"
	end
	if championId == "Chromeclaw" and slot == "Q" then
		return "plate"
	end
	if championId == "Chromeclaw" and slot == "E" then
		return "reload"
	end
	if championId == "OraclePaws" and slot == "E" then
		return "omen"
	end
	if championId == "Archmeow" and slot == "Q" then
		return "charge"
	end
	if championId == "Archmeow" and slot == "R" then
		return "meteor"
	end
	if championId == "Hexkit" and slot == "Q" then
		return "curse"
	end
	if championId == "Hexkit" and slot == "R" then
		return "hex"
	end
	if championId == "Mindwhisker" and slot == "Q" then
		return "psi"
	end
	if championId == "Mindwhisker" and slot == "E" then
		return "nudge"
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
	elseif look == "data" then
		return 1.36
	elseif look == "overclock" then
		return 0.9
	elseif look == "bleed" then
		return 0.76
	elseif look == "fortify" then
		return 0.7
	elseif look == "mark" then
		return 1.16
	elseif look == "vanish" then
		return 0.62
	elseif look == "plate" then
		return 0.8
	elseif look == "reload" then
		return 1.24
	elseif look == "omen" then
		return 0.88
	elseif look == "charge" then
		return 1.34
	elseif look == "meteor" then
		return 0.64
	elseif look == "curse" then
		return 1.22
	elseif look == "hex" then
		return 0.7
	elseif look == "psi" then
		return 1.3
	elseif look == "nudge" then
		return 0.74
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
		{ "Byte", "Q: data · W: overclock" },
		{ "Scratch", "Q: bleed · E: fortify" },
		{ "Shadow", "Brush Q: mark · W: vanish" },
		{ "Chrome", "Q: plate · E: reload" },
		{ "Oracle", "Near ward: amp · E: omen" },
		{ "Arch", "Q: charge · R: meteor" },
		{ "Hex", "Q: curse · R: hex" },
		{ "Mind", "Q: psi · E: nudge" },
	}
end

function ChampionKits.practiceTip(): string
	return "Meow — W: short damage cut. R: pull + stun. Nyan — a takedown resets Q W E. R: beam you can cancel. Whiskers — Q hit refunds mana. E: zone that keeps ticking."
end

function ChampionKits.practiceTipMore(): string
	return "Chonk — Settled Loaf: E cuts damage after the flop. Charge Knock: Q bowls champs. Scammy — Open Wick stacks on Q (max 3). Hype Candle spends them. Grandma — Second Helping boosts heals. Sweater Aura on W cuts damage."
end

function ChampionKits.practiceTipExpansion(): string
	return "Byte — Packet Buffer: Q on a cat stores Data (max 3). Overclock: W spends it as a shield. Scratch — Honor Bleed: Q stacks a cut (max 3). Shield Fortify: E cashes it and you take less. Shadow — Alley Mark: Q from brush. Smoke Vanish: W, then the next cat hit hits harder."
end

function ChampionKits.practiceTipExpansionMore(): string
	return "Chrome — Chrome Plate: Q on a cat stores Plate (max 3) and you take less. Lunge Reload: E spends it, hits harder, and the dash returns sooner. Oracle — Ward Omen: heals and shields are stronger beside your ward. Foresight Veil: E, then the next hit is lighter. Arch — Spell Charge: Q stores Charge (max 3). Charged Meteor: R spends it."
end

function ChampionKits.practiceTipLast(): string
	return "Hex — Curse Stacks: Q on a cat stores Curse (max 3) and it burns. Hex Zone: R leaves a hex that ticks harder on cursed cats. Mind — Psi Mark: Q marks a cat; hits hurt more while you can see them. Mind Nudge: E spends the mark and pulls them in."
end

return ChampionKits
