--!strict

-- Pawmart combat hooks. CombatService is the only applier.
-- Yarn Cleave: active circle slash (key 7).
-- Stall Fang: extra champion damage at or below a health threshold.
-- Paper Charm: timed slow immunity after an enemy pink slow.
-- Flat stat sticks stay on ItemCatalog. Control Yarn stacks and Whisker Lens stay put.
--
-- Costs sit in the existing 75–300 band (Practice starts at 500 gold):
-- Yarn Cleave 280 still leaves room for one Control Yarn (75).
-- Stall Fang 300 is the band ceiling, so Longclaw plus Fang waits on a wave.
-- Paper Charm 220 sits with Mana Treat / Pounce Boots, under Yarnplate.

local ItemKits = {}

ItemKits.CleaveId = "YarnCleave"
ItemKits.FangId = "StallFang"
ItemKits.CharmId = "PaperCharm"

ItemKits.CLEAVE_COST = 280
ItemKits.CLEAVE_COOLDOWN = 12
ItemKits.CLEAVE_RADIUS = 12
ItemKits.CLEAVE_DAMAGE = 40

ItemKits.FANG_COST = 300
ItemKits.FANG_THRESHOLD = 0.2
ItemKits.FANG_BONUS = 36

ItemKits.CHARM_COST = 220
ItemKits.CHARM_WINDOW = 2.4
ItemKits.CHARM_COOLDOWN = 20

export type CharmStep = {
	mul: number,
	untilAt: number?,
	readyAt: number?,
	procced: boolean,
}

function ItemKits.owns(owned: { string }, id: string): boolean
	for _, itemId in owned do
		if itemId == id then
			return true
		end
	end
	return false
end

function ItemKits.cleaveReady(now: number, readyAt: number?): boolean
	return now >= (readyAt or 0)
end

function ItemKits.cleaveReadyAt(now: number): number
	return now + ItemKits.CLEAVE_COOLDOWN
end

function ItemKits.flatDistance(origin: Vector3, point: Vector3): number
	local dx = origin.X - point.X
	local dz = origin.Z - point.Z
	return math.sqrt(dx * dx + dz * dz)
end

function ItemKits.inCleave(origin: Vector3, point: Vector3): boolean
	return ItemKits.flatDistance(origin, point) <= ItemKits.CLEAVE_RADIUS
end

-- Bonus raw damage before armor. At or below the threshold, and only when owned.
function ItemKits.fangBonus(health: number, maxHealth: number, owns: boolean): number
	if not owns or maxHealth <= 0 or health <= 0 then
		return 0
	end
	if (health / maxHealth) > ItemKits.FANG_THRESHOLD then
		return 0
	end
	return ItemKits.FANG_BONUS
end

-- While the window is up, pink slow is ignored. A live enemy slow opens the window if the charm is ready.
function ItemKits.charmStep(slowMul: number, owns: boolean, now: number, untilAt: number?, readyAt: number?): CharmStep
	if untilAt ~= nil and now < untilAt then
		return {
			mul = 1,
			untilAt = untilAt,
			readyAt = readyAt,
			procced = false,
		}
	end
	local cooled = readyAt == nil or now >= readyAt
	if owns and slowMul < 0.999 and cooled then
		return {
			mul = 1,
			untilAt = now + ItemKits.CHARM_WINDOW,
			readyAt = now + ItemKits.CHARM_COOLDOWN,
			procced = true,
		}
	end
	return {
		mul = slowMul,
		untilAt = nil,
		readyAt = readyAt,
		procced = false,
	}
end

function ItemKits.cleaveHud(owns: boolean, now: number, readyAt: number?): string
	if not owns then
		return "7  Cleave  (buy)"
	end
	local cd = (readyAt or 0) - now
	if cd > 0.15 then
		return `7  Cleave  {string.format("%.0f", cd)}s`
	end
	return "7  Cleave  ready"
end

function ItemKits.charmHud(owns: boolean, now: number, untilAt: number?, readyAt: number?): string
	if untilAt ~= nil and now < untilAt then
		return " · Charm"
	end
	if not owns then
		return ""
	end
	local cd = (readyAt or 0) - now
	if cd > 0.15 then
		return ` · Charm {string.format("%.0f", cd)}s`
	end
	return ""
end

function ItemKits.helpRows(): { { string } }
	return {
		{ "7", "Yarn Cleave (buy). Nearby slash, then cooldown" },
		{ "Fang", "Stall Fang: bigger hit at or below 20% HP" },
		{ "Charm", "Paper Charm: 2.4s slow immunity after a pink" },
	}
end

return ItemKits
