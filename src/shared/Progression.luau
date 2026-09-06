--!strict

-- Server + client. XP, auto-ranks, and death timers. Levels 1–18.

local Types = require(script.Parent.Types)

local Progression = {}

Progression.MaxLevel = 18
Progression.RUnlockLevel = 6
Progression.MaxBasicRank = 5
Progression.MaxUltRank = 3

local R_LEVELS: { [number]: boolean } = {
	[6] = true,
	[11] = true,
	[16] = true,
}

function Progression.emptyRanks(): Types.AbilityRanks
	return { Q = 0, W = 0, E = 0, R = 0 }
end

-- XP needed to go from `level` → `level + 1`.
function Progression.xpToNext(level: number): number
	if level >= Progression.MaxLevel then
		return 0
	end
	return 40 + (level - 1) * 28
end

function Progression.totalXpForLevel(level: number): number
	local total = 0
	local cap = math.clamp(level, 1, Progression.MaxLevel)
	for i = 1, cap - 1 do
		total += Progression.xpToNext(i)
	end
	return total
end

function Progression.levelFromXp(xp: number): number
	local level = 1
	local remaining = math.max(0, math.floor(xp))
	while level < Progression.MaxLevel do
		local need = Progression.xpToNext(level)
		if remaining < need then
			break
		end
		remaining -= need
		level += 1
	end
	return level
end

function Progression.progress(xp: number): (number, number, number)
	local level = Progression.levelFromXp(xp)
	local into = math.max(0, math.floor(xp) - Progression.totalXpForLevel(level))
	local need = Progression.xpToNext(level)
	return level, into, need
end

-- One point per level, including 1. Q then W then E (max 5). R at 6 / 11 / 16.
function Progression.autoRanks(level: number): Types.AbilityRanks
	local ranks = Progression.emptyRanks()
	local cursor = 1
	local cap = math.clamp(math.floor(level), 1, Progression.MaxLevel)
	for lv = 1, cap do
		if R_LEVELS[lv] then
			ranks.R = math.min(Progression.MaxUltRank, ranks.R + 1)
		else
			for _ = 1, 3 do
				if cursor == 1 and ranks.Q < Progression.MaxBasicRank then
					ranks.Q += 1
					cursor = 2
					break
				elseif cursor == 2 and ranks.W < Progression.MaxBasicRank then
					ranks.W += 1
					cursor = 3
					break
				elseif cursor == 3 and ranks.E < Progression.MaxBasicRank then
					ranks.E += 1
					cursor = 1
					break
				else
					cursor = (cursor % 3) + 1
				end
			end
		end
	end
	return ranks
end

function Progression.statGrowth(level: number): { maxHealth: number, maxMana: number, bonusDamage: number, abilityPower: number }
	local n = math.max(0, math.clamp(level, 1, Progression.MaxLevel) - 1)
	return {
		maxHealth = n * 72,
		maxMana = n * 28,
		bonusDamage = n * 3,
		abilityPower = n * 4,
	}
end

function Progression.rankScale(rank: number): number
	if rank <= 0 then
		return 0
	end
	return 0.75 + 0.25 * rank
end

function Progression.respawnSeconds(level: number): number
	return 6 + (math.clamp(level, 1, Progression.MaxLevel) - 1) * 0.55
end

return Progression
