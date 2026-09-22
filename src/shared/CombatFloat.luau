--!strict

-- Pure rules for floating combat numbers (damage / heal / shield pops).
-- CombatService emits on the existing CombatFx remote; the client paints.
-- Not a second combat system. Hub modes never show these.

local CombatFloat = {}

CombatFloat.MergeWindow = 0.12
CombatFloat.MaxOnScreen = 10
CombatFloat.Duration = 0.9
CombatFloat.RiseStuds = 2.6

-- Night-market cream/coral for damage; mint for heals/shields.
CombatFloat.DamageCream = { 255, 243, 224 }
CombatFloat.DamageCoral = { 255, 122, 98 }
CombatFloat.HealMint = { 120, 196, 150 }
CombatFloat.ShieldMint = { 150, 214, 180 }
CombatFloat.Ink = { 52, 36, 32 }
-- Last-hit gold only. Damage numbers stay cream / coral.
CombatFloat.GoldAmber = { 255, 196, 74 }
-- Bounty gold only (kill / assist / structure). Peach, not amber, not execute coral.
CombatFloat.BountyPeach = { 255, 164, 120 }
-- XP ticks only. Cream pulled into lavender. Not amber last-hit gold, not peach bounty.
CombatFloat.XpLavender = { 226, 210, 248 }

export type FloatKind = "damage" | "heal" | "shield" | "crit" | "execute" | "gold" | "bounty" | "xp"

function CombatFloat.format(amount: number): string
	if amount <= 0 then
		return "0"
	end
	return tostring(math.max(1, math.floor(amount + 0.5)))
end

function CombatFloat.caresAbout(localUserId: number, attackerUserId: number?, targetUserId: number?): boolean
	if targetUserId ~= nil and localUserId == targetUserId then
		return true
	end
	if attackerUserId ~= nil and localUserId == attackerUserId then
		return true
	end
	return false
end

-- Fog: skip numbers on fogged enemy bodies the local player cannot see.
-- Self-targeted floats (you take) always pass — your own body is never fogged to you.
function CombatFloat.fogAllows(localUserId: number, targetUserId: number?, inVision: boolean): boolean
	if targetUserId ~= nil and localUserId == targetUserId then
		return true
	end
	return inVision
end

function CombatFloat.isBold(kind: FloatKind): boolean
	return kind == "crit" or kind == "execute"
end

function CombatFloat.textSize(kind: FloatKind): number
	if kind == "crit" or kind == "execute" then
		return 28
	end
	if kind == "bounty" then
		return 22
	end
	if kind == "xp" then
		return 18
	end
	if kind == "heal" or kind == "shield" or kind == "gold" then
		return 20
	end
	return 22
end

function CombatFloat.rgb(kind: FloatKind): { number }
	if kind == "heal" then
		return CombatFloat.HealMint
	end
	if kind == "shield" then
		return CombatFloat.ShieldMint
	end
	if kind == "crit" or kind == "execute" then
		return CombatFloat.DamageCoral
	end
	if kind == "gold" then
		return CombatFloat.GoldAmber
	end
	if kind == "bounty" then
		return CombatFloat.BountyPeach
	end
	if kind == "xp" then
		return CombatFloat.XpLavender
	end
	return CombatFloat.DamageCream
end

function CombatFloat.prefix(kind: FloatKind): string
	if kind == "heal" or kind == "shield" or kind == "gold" or kind == "bounty" or kind == "xp" then
		return "+"
	end
	return ""
end

function CombatFloat.label(kind: FloatKind, amount: number): string
	local body = `{CombatFloat.prefix(kind)}{CombatFloat.format(amount)}`
	if kind == "gold" or kind == "bounty" then
		return `{body}g`
	end
	if kind == "xp" then
		return `{body} XP`
	end
	return body
end

-- Snap near-simultaneous hits on the same body/cell so Yarn Cleave does not carpet.
function CombatFloat.mergeKey(kind: FloatKind, originX: number, originZ: number, targetUserId: number?): string
	local cellX = math.floor(originX / 4 + 0.5)
	local cellZ = math.floor(originZ / 4 + 0.5)
	local who = if targetUserId ~= nil then tostring(targetUserId) else `{cellX}:{cellZ}`
	return `{kind}|{who}`
end

export type MergeSlot = {
	key: string,
	amount: number,
	kind: FloatKind,
	bornAt: number,
	-- Last-hit pops only. Damage merges leave this unset.
	count: number?,
}

-- Merge into an existing open slot, or nil if a new pop should spawn.
-- count, when passed, sums a second tally (CS) without touching damage merges.
function CombatFloat.tryMerge(
	slots: { MergeSlot },
	key: string,
	kind: FloatKind,
	amount: number,
	now: number,
	count: number?
): MergeSlot?
	for _, slot in slots do
		if slot.key == key and slot.kind == kind and (now - slot.bornAt) <= CombatFloat.MergeWindow then
			slot.amount += amount
			if count ~= nil and count > 0 then
				slot.count = (slot.count or 0) + count
			end
			return slot
		end
	end
	return nil
end

-- Soft cap: refuse a brand-new pop when the screen is already full.
-- Merges still apply (tryMerge first).
function CombatFloat.canSpawn(activeCount: number): boolean
	return activeCount < CombatFloat.MaxOnScreen
end

return CombatFloat
