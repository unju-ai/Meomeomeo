--!strict

-- Pure helpers for Cat Rift local level-up juice (banner copy, cream/amber
-- palette, which ability slot gained a rank). XP curves stay in Progression.
-- Client paints from the existing combat level-change edge.

local LevelUpJuice = {}

LevelUpJuice.RingSeconds = 0.85
LevelUpJuice.FloatSeconds = 1.05
LevelUpJuice.RankFlashSeconds = 0.55
LevelUpJuice.BannerHold = 1.35

-- Night-market cream / amber (not mint) so LEVEL UP reads distinct from heals.
LevelUpJuice.Cream = { 255, 243, 224 }
LevelUpJuice.Amber = { 255, 196, 74 }
LevelUpJuice.Peach = { 255, 184, 140 }
LevelUpJuice.Ink = { 52, 36, 32 }

export type RankMap = { [string]: number }

local SLOT_ORDER: { string } = { "Q", "W", "E", "R" }

function LevelUpJuice.bannerTitle(): string
	return "LEVEL UP"
end

function LevelUpJuice.bannerLine(level: number): string
	local n = math.max(1, math.floor(level))
	return `LEVEL {n}`
end

function LevelUpJuice.floatLabel(level: number): string
	return `LEVEL {math.max(1, math.floor(level))}`
end

function LevelUpJuice.rgbCream(): { number }
	return LevelUpJuice.Cream
end

function LevelUpJuice.rgbAmber(): { number }
	return LevelUpJuice.Amber
end

-- Slots that gained a rank between two auto-rank snapshots (QWER only).
-- Empty when ranks are missing or unchanged — no invented skill-point UI.
function LevelUpJuice.gainedSlots(before: RankMap?, after: RankMap?): { string }
	local gained: { string } = {}
	if not after then
		return gained
	end
	local prev: RankMap = before or { Q = 0, W = 0, E = 0, R = 0 }
	for _, slot in SLOT_ORDER do
		local nextRank = after[slot]
		local prior = prev[slot]
		local a = if typeof(nextRank) == "number" then nextRank else 0
		local b = if typeof(prior) == "number" then prior else 0
		if a > b then
			table.insert(gained, slot)
		end
	end
	return gained
end

function LevelUpJuice.hasRankGain(before: RankMap?, after: RankMap?): boolean
	return #LevelUpJuice.gainedSlots(before, after) > 0
end

return LevelUpJuice
