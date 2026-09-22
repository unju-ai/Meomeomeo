--!strict

-- Pure helpers for Cat Rift HUD HP / mana / XP paints. Values stay on the
-- match combat snapshot; the client only formats and warns. No regen math.

local ResourceBars = {}

ResourceBars.LowHpRatio = 0.3
ResourceBars.WarnPulseSeconds = 0.72

-- Night-market RGB for client Theme.fromRGB mirrors (tests stay Color3-free).
ResourceBars.HpFill = { 255, 122, 98 } -- coral
ResourceBars.HpTrack = { 72, 48, 42 }
ResourceBars.ManaFill = { 72, 132, 220 } -- cobalt
ResourceBars.ManaTrack = { 40, 52, 78 }
ResourceBars.ManaOkStroke = { 120, 196, 150 } -- mint
ResourceBars.XpFill = { 255, 196, 74 } -- amber
ResourceBars.XpTrack = { 62, 42, 38 }

function ResourceBars.ratio(current: number, maxValue: number): number
	if maxValue <= 0 then
		return 0
	end
	return math.clamp(current / maxValue, 0, 1)
end

function ResourceBars.formatPair(current: number, maxValue: number): string
	local cur = math.max(0, math.floor(current + 1e-6))
	local cap = math.max(0, math.floor(maxValue + 1e-6))
	return `{cur} / {cap}`
end

function ResourceBars.isLowHp(health: number, maxHealth: number): boolean
	if maxHealth <= 0 then
		return false
	end
	return health > 0 and ResourceBars.ratio(health, maxHealth) < ResourceBars.LowHpRatio
end

-- True when mana cannot pay at least one castable ability cost (mirrors slot tint).
function ResourceBars.isManaGated(mana: number, costs: { number }): boolean
	for _, cost in costs do
		if cost > 0 and mana < cost then
			return true
		end
	end
	return false
end

function ResourceBars.xpLabel(level: number, into: number, need: number): string
	if need <= 0 then
		return `Lv {level} · MAX`
	end
	return `Lv {level} · {math.floor(into + 1e-6)} / {math.floor(need + 1e-6)}`
end

-- 0 = calm, 1 = peak warn. Drive stroke / flash transparency from this.
function ResourceBars.warnPulse(now: number, active: boolean): number
	if not active then
		return 0
	end
	local period = ResourceBars.WarnPulseSeconds
	local phase = (now % period) / period
	return 0.35 + 0.65 * (0.5 + 0.5 * math.sin(phase * math.pi * 2))
end

return ResourceBars
