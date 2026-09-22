--!strict

-- Server-authoritative creep score and gold deltas for one match purse.
-- MatchService applies these onto the match player (humans and bots share the record).
-- Clients only read gold, cs, and level off the snapshot.
-- LastHitJuice may paint a local amber +Ng when a lastHit credit lands. It does not grant gold.
-- BountyJuice may paint a local peach +Ng when a bounty credit lands. It does not grant gold.
--
-- CS counts a champion's last hit:
--   lane kitten (MinionGold)
--   jungle camp (that camp's gold — same credit as the gold grant)
-- CS does not count:
--   nearby minion or camp XP (no last hit)
--   a kitten or camp that dies with no champion credit
--   champion kill or assist bounties
--   tower / nexus gold
--   ward breaks
--   spending gold at Pawmart

local FarmCredit = {}

export type Credit = {
	cs: number,
	gold: number,
}

export type Purse = {
	gold: number,
	cs: number,
}

export type CleaveTone = "ready" | "short" | "owned"

export type CleaveRead = {
	text: string,
	tone: CleaveTone,
	shortfall: number,
}

function FarmCredit.lastHit(gold: number): Credit
	return {
		cs = 1,
		gold = gold,
	}
end

function FarmCredit.bounty(gold: number): Credit
	return {
		cs = 0,
		gold = gold,
	}
end

function FarmCredit.none(): Credit
	return {
		cs = 0,
		gold = 0,
	}
end

function FarmCredit.apply(purse: Purse, credit: Credit)
	purse.cs += credit.cs
	purse.gold += credit.gold
end

-- Local purse chip. Owned wins. Otherwise compare the purse to Yarn Cleave's cost.
function FarmCredit.cleaveRead(gold: number, owned: boolean, cost: number): CleaveRead
	if owned then
		return {
			text = "Cleave owned",
			tone = "owned",
			shortfall = 0,
		}
	end
	if gold >= cost then
		return {
			text = `Cleave {cost}g · can buy`,
			tone = "ready",
			shortfall = 0,
		}
	end
	local short = cost - gold
	return {
		text = `Cleave {cost}g · {short}g short`,
		tone = "short",
		shortfall = short,
	}
end

return FarmCredit
