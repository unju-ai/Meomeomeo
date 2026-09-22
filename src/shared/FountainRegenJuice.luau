--!strict

-- Pure helpers for Cat Rift fountain regen juice.
-- CombatService already ticks HP/mana when ShopService.nearFountain;
-- the client only detects that edge and paints. Not a second regen system.

local FountainRegenJuice = {}

-- Matches Config.Shop.FountainRadius + MapBuilder Blue/Red fountain pads.
FountainRegenJuice.Radius = 32
FountainRegenJuice.BlueX = -176
FountainRegenJuice.RedX = 176
FountainRegenJuice.PadZ = 0

-- Soft sustained ring / occasional floats — calm rest, not a level-up banner.
FountainRegenJuice.RingRefresh = 1.35
FountainRegenJuice.FloatGap = 0.95
FountainRegenJuice.AllyRingGap = 0.8
FountainRegenJuice.WashSeconds = 0.28

-- Fountain ticks are ~48 HP / ~56 mana; lane regen is ~4 / ~6.
FountainRegenJuice.FountainHpFloor = 20
FountainRegenJuice.FountainManaFloor = 20

-- Night-market mint (aligned with CombatFloat heal / Theme.mint).
FountainRegenJuice.Mint = { 120, 196, 150 }
FountainRegenJuice.MintSoft = { 150, 214, 180 }
FountainRegenJuice.Ink = { 52, 36, 32 }

FountainRegenJuice.RegenPulseSeconds = 1.05

export type TeamId = "Blue" | "Red"
export type CueKind = "local" | "ally" | "enemy" | "none"
export type FloatKind = "hp" | "mana"

function FountainRegenJuice.padX(team: TeamId): number
	if team == "Red" then
		return FountainRegenJuice.RedX
	end
	return FountainRegenJuice.BlueX
end

-- Flat XZ distance vs the team fountain pad (Y ignored — pad is ground).
function FountainRegenJuice.nearFountain(team: TeamId, x: number, z: number): boolean
	local dx = x - FountainRegenJuice.padX(team)
	local dz = z - FountainRegenJuice.PadZ
	return (dx * dx + dz * dz) <= (FountainRegenJuice.Radius * FountainRegenJuice.Radius)
end

function FountainRegenJuice.needsHp(health: number, maxHealth: number): boolean
	return maxHealth > 0 and health < maxHealth - 0.05
end

function FountainRegenJuice.needsMana(mana: number, maxMana: number): boolean
	return maxMana > 0 and mana < maxMana - 0.05
end

-- Alive + on pad + missing HP and/or mana → fountain is actually topping you up.
function FountainRegenJuice.isRegenerating(
	alive: boolean,
	atFountain: boolean,
	health: number,
	maxHealth: number,
	mana: number,
	maxMana: number
): boolean
	if not alive or not atFountain then
		return false
	end
	return FountainRegenJuice.needsHp(health, maxHealth) or FountainRegenJuice.needsMana(mana, maxMana)
end

function FountainRegenJuice.hpGain(prevHealth: number, nextHealth: number): number
	return nextHealth - prevHealth
end

function FountainRegenJuice.manaGain(prevMana: number, nextMana: number): number
	return nextMana - prevMana
end

function FountainRegenJuice.isFountainHpTick(gain: number): boolean
	return gain >= FountainRegenJuice.FountainHpFloor
end

function FountainRegenJuice.isFountainManaTick(gain: number): boolean
	return gain >= FountainRegenJuice.FountainManaFloor
end

-- Fountain rest stays calm: skip the loud ScreenJuice.healFlash / Heal SFX on pad ticks.
function FountainRegenJuice.suppressHealFlash(atFountain: boolean, hpGain: number): boolean
	return atFountain and FountainRegenJuice.isFountainHpTick(hpGain)
end

function FountainRegenJuice.formatAmount(amount: number): string
	if amount <= 0 then
		return "0"
	end
	return tostring(math.max(1, math.floor(amount + 0.5)))
end

function FountainRegenJuice.floatLabel(kind: FloatKind, amount: number): string
	local n = FountainRegenJuice.formatAmount(amount)
	if kind == "mana" then
		return `+{n} MP`
	end
	return `+{n}`
end

function FountainRegenJuice.rgb(kind: FloatKind): { number }
	if kind == "mana" then
		return FountainRegenJuice.MintSoft
	end
	return FountainRegenJuice.Mint
end

-- Cat Rift fight only. Hub / Yarn Run / Koi / Party / Arcade stay quiet.
function FountainRegenJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

-- Who may paint a fountain cue for a body.
-- Local: always. Ally: light shared ring. Enemy: fog-gated like other combat FX.
function FountainRegenJuice.cueKind(
	localUserId: number,
	targetUserId: number,
	sameTeam: boolean,
	inVision: boolean
): CueKind
	if localUserId == targetUserId then
		return "local"
	end
	if sameTeam then
		return "ally"
	end
	if inVision then
		return "enemy"
	end
	return "none"
end

function FountainRegenJuice.shouldPaint(cue: CueKind): boolean
	return cue == "local" or cue == "ally" or cue == "enemy"
end

-- Soft mint pulse for HP/mana strokes while regenerating (0 = off, 1 = peak).
function FountainRegenJuice.regenGlowPulse(now: number, active: boolean): number
	if not active then
		return 0
	end
	local period = FountainRegenJuice.RegenPulseSeconds
	local phase = (now % period) / period
	return 0.28 + 0.55 * (0.5 + 0.5 * math.sin(phase * math.pi * 2))
end

-- Ally / enemy rings stay faint; local is a bit clearer.
function FountainRegenJuice.ringTransparency(cue: CueKind): number
	if cue == "local" then
		return 0.52
	end
	if cue == "ally" then
		return 0.72
	end
	return 0.78
end

function FountainRegenJuice.ringSize(cue: CueKind): number
	if cue == "local" then
		return 5.6
	end
	return 4.8
end

return FountainRegenJuice
