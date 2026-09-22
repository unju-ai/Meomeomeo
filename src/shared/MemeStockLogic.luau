--!strict

-- Playful in-match meme tape. Not gold, not Closet yarn, not the Meme Arcade
-- board, and not a broker. Lane kittens and jungle camps stay quiet. A short
-- per-cat gap stops a stuck loop from pumping one symbol.

local MemeStockLogic = {}

-- Fractions of the current price. Big enough to read, small enough to stay a joke.
MemeStockLogic.Kill = 0.08
MemeStockLogic.Death = -0.03
MemeStockLogic.Post = 0.14
MemeStockLogic.Stall = 0.17
MemeStockLogic.Core = 0.22
-- Lane kittens took the structure: a smaller nudge on each attacking cat.
MemeStockLogic.TeamPost = 0.045
MemeStockLogic.TeamStall = 0.055
MemeStockLogic.TeamCore = 0.07

-- Seconds. Kills stay short so a real double still prints. Structures are slower.
MemeStockLogic.KillGap = 0.25
MemeStockLogic.EventGap = 1.75

export type Admit = {
	magnitude: number,
	gap: number,
}

local RULES: { [string]: Admit } = {
	kill = { magnitude = MemeStockLogic.Kill, gap = MemeStockLogic.KillGap },
	death = { magnitude = MemeStockLogic.Death, gap = MemeStockLogic.KillGap },
	post = { magnitude = MemeStockLogic.Post, gap = MemeStockLogic.EventGap },
	stall = { magnitude = MemeStockLogic.Stall, gap = MemeStockLogic.EventGap },
	core = { magnitude = MemeStockLogic.Core, gap = MemeStockLogic.EventGap },
	teamPost = { magnitude = MemeStockLogic.TeamPost, gap = MemeStockLogic.EventGap },
	teamStall = { magnitude = MemeStockLogic.TeamStall, gap = MemeStockLogic.EventGap },
	teamCore = { magnitude = MemeStockLogic.TeamCore, gap = MemeStockLogic.EventGap },
}

function MemeStockLogic.structureKind(tier: string, teamPulse: boolean): string?
	local base: string? = nil
	if tier == "Outer" then
		base = "post"
	elseif tier == "Inner" then
		base = "stall"
	elseif tier == "Core" then
		base = "core"
	end
	if not base then
		return nil
	end
	if not teamPulse then
		return base
	end
	return "team" .. string.upper(string.sub(base, 1, 1)) .. string.sub(base, 2)
end

-- nil means stay quiet (minions, camps, assists) or the gap has not elapsed.
function MemeStockLogic.admit(kind: string, now: number, lastAt: number?): Admit?
	local rule = RULES[kind]
	if not rule then
		return nil
	end
	if lastAt and now - lastAt < rule.gap then
		return nil
	end
	return rule
end

function MemeStockLogic.nextPrice(price: number, magnitude: number): (number, number)
	local delta = price * magnitude
	local nextPrice = math.max(1, price + delta)
	return nextPrice, nextPrice - price
end

function MemeStockLogic.tone(change: number): string
	if change > 0.049 then
		return "up"
	elseif change < -0.049 then
		return "down"
	end
	return "flat"
end

function MemeStockLogic.priceText(price: number): string
	return string.format("%.1f", price)
end

function MemeStockLogic.signed(change: number): string
	if change > 0.049 then
		return "+" .. string.format("%.1f", change)
	elseif change < -0.049 then
		return string.format("%.1f", change)
	end
	return "0.0"
end

return MemeStockLogic
