--!strict

-- Fountain pawn for Pawmart. Buy prices stay on ItemCatalog.
-- ShopService.sellAt is the only grant. This module is the math and the gate.
--
-- Refund is floor(catalog price * 70 / 100) gold, once per bag copy.
-- The purse gets that gold. CS is not touched.
--
-- Control Yarn: the bag does not store a charge count on one slot. Each
-- remaining charge is its own copy, bought at the full sticker (75g). One
-- click pawns one copy, so a half-used stack refunds the full 70% of that
-- one charge — not a fraction of the two-charge cap. A planted ward is
-- already consumed and is not in the bag.
--
-- If a future slot stored `remaining` of `cap` charges, refundIfChargeSlot
-- is that other rule. Live sell does not call it.
--
-- Actives on cooldown stay sellable. Gold only. The cooldown stamp stays
-- on the cat: it is not cleared, moved, or paid extra for.

local ShopSell = {}

ShopSell.RefundPercent = 70
-- Live bag is a list of item ids. False means "full item 70% once" per copy.
ShopSell.BagStoresChargeCount = false
ShopSell.IgnoresCooldown = true

ShopSell.AwayError = "Sell at your fountain (or press B there)."
ShopSell.EmptyError = "Nothing to pawn."

function ShopSell.refundGold(cost: number): number
	local price = math.floor(cost)
	if price <= 0 then
		return 0
	end
	return (price * ShopSell.RefundPercent) // 100
end

-- Not the live path. One slot holding `remaining` of `cap` charges would
-- refund floor(price * remaining / cap * 70%). A full slot matches refundGold.
function ShopSell.refundIfChargeSlot(cost: number, remaining: number, cap: number): number
	if remaining <= 0 or cap <= 0 then
		return 0
	end
	if cap <= 1 or remaining >= cap then
		return ShopSell.refundGold(cost)
	end
	local price = math.floor(cost)
	if price <= 0 then
		return 0
	end
	return (price * remaining * ShopSell.RefundPercent) // (cap * 100)
end

-- `atFountain` is ShopService.nearFountain — the same disk as buy.
-- Cooldown is not an input. Owning a copy is enough.
function ShopSell.gate(atFountain: boolean, ownedCount: number): (boolean, string?)
	if not atFountain then
		return false, ShopSell.AwayError
	end
	if ownedCount < 1 then
		return false, ShopSell.EmptyError
	end
	return true, nil
end

function ShopSell.toast(name: string, gold: number): string
	local n = math.floor(gold)
	if n < 0 then
		n = 0
	end
	return `Sold {name} · +{n}g`
end

return ShopSell
