--!strict

local Types = require(script.Parent.Types)

local ITEMS: { [string]: Types.ItemDef } = {
	Longclaw = {
		id = "Longclaw",
		name = "Longclaw",
		blurb = "A sharper stick. +ability damage.",
		cost = 250,
		bonusDamage = 18,
		armor = 0,
		maxHealth = 0,
		maxMana = 0,
		walkSpeed = 0,
	},
	Yarnplate = {
		id = "Yarnplate",
		name = "Yarnplate",
		blurb = "Knitted armor. Extra HP and damage reduction.",
		cost = 250,
		bonusDamage = 0,
		armor = 0.12,
		maxHealth = 90,
		maxMana = 0,
		walkSpeed = 0,
	},
	ManaTreat = {
		id = "ManaTreat",
		name = "Mana Treat",
		blurb = "Crunchy focus snack. Bigger mana pool.",
		cost = 200,
		bonusDamage = 0,
		armor = 0,
		maxHealth = 0,
		maxMana = 90,
		walkSpeed = 0,
	},
	PounceBoots = {
		id = "PounceBoots",
		name = "Pounce Boots",
		blurb = "Squeaky sneakers. Move faster.",
		cost = 200,
		bonusDamage = 0,
		armor = 0,
		maxHealth = 0,
		maxMana = 0,
		walkSpeed = 6,
	},
	WhiskerLens = {
		id = "WhiskerLens",
		name = "Whisker Lens",
		blurb = "Press 5: reveal and scratch enemy wards in a short radius.",
		cost = 180,
		bonusDamage = 0,
		armor = 0,
		maxHealth = 0,
		maxMana = 0,
		walkSpeed = 0,
	},
	ControlYarn = {
		id = "ControlYarn",
		name = "Control Yarn",
		blurb = "Press 6: magenta pink ward. Vision + slow. Reveals enemy trinkets nearby. 2 charges.",
		cost = 75,
		bonusDamage = 0,
		armor = 0,
		maxHealth = 0,
		maxMana = 0,
		walkSpeed = 0,
		stackMax = 2,
	},
	-- Night-market effects live in Shared.ItemKits (not flat stats).
	-- 280 still leaves a Control Yarn inside the 500 start gold.
	YarnCleave = {
		id = "YarnCleave",
		name = "Yarn Cleave",
		blurb = "Press 7: slash nearby enemies, then a 12s cooldown.",
		cost = 280,
		bonusDamage = 0,
		armor = 0,
		maxHealth = 0,
		maxMana = 0,
		walkSpeed = 0,
	},
	-- Band ceiling. Longclaw (250) plus this waits on a wave of farm.
	StallFang = {
		id = "StallFang",
		name = "Stall Fang",
		blurb = "Champion hits bite harder at or below 20% HP.",
		cost = 300,
		bonusDamage = 0,
		armor = 0,
		maxHealth = 0,
		maxMana = 0,
		walkSpeed = 0,
	},
	-- Sits with Mana Treat / Pounce Boots. Under Yarnplate.
	PaperCharm = {
		id = "PaperCharm",
		name = "Paper Charm",
		blurb = "An enemy pink opens 2.4s of slow immunity, then 20s.",
		cost = 220,
		bonusDamage = 0,
		armor = 0,
		maxHealth = 0,
		maxMana = 0,
		walkSpeed = 0,
	},
}

local ORDER = {
	"Longclaw",
	"Yarnplate",
	"ManaTreat",
	"PounceBoots",
	"WhiskerLens",
	"ControlYarn",
	"YarnCleave",
	"StallFang",
	"PaperCharm",
}

local ItemCatalog = {}

ItemCatalog.ControlYarnId = "ControlYarn"

function ItemCatalog.get(id: string): Types.ItemDef?
	return ITEMS[id]
end

function ItemCatalog.all(): { Types.ItemDef }
	local list = {}
	for _, id in ORDER do
		table.insert(list, ITEMS[id])
	end
	return list
end

function ItemCatalog.maxStack(id: string): number
	local item = ITEMS[id]
	if item and typeof(item.stackMax) == "number" and item.stackMax > 1 then
		return item.stackMax
	end
	return 1
end

function ItemCatalog.count(owned: { string }, id: string): number
	local n = 0
	for _, itemId in owned do
		if itemId == id then
			n += 1
		end
	end
	return n
end

function ItemCatalog.canBuy(owned: { string }, id: string): boolean
	return ItemCatalog.count(owned, id) < ItemCatalog.maxStack(id)
end

function ItemCatalog.bonuses(owned: { string }): Types.ItemBonuses
	local sum: Types.ItemBonuses = {
		bonusDamage = 0,
		armor = 0,
		maxHealth = 0,
		maxMana = 0,
		walkSpeed = 0,
	}
	for _, id in owned do
		local item = ITEMS[id]
		if item then
			sum.bonusDamage += item.bonusDamage
			sum.armor += item.armor
			sum.maxHealth += item.maxHealth
			sum.maxMana += item.maxMana
			sum.walkSpeed += item.walkSpeed
		end
	end
	if sum.armor > 0.4 then
		sum.armor = 0.4
	end
	return sum
end

return ItemCatalog
