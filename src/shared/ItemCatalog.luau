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
}

local ORDER = { "Longclaw", "Yarnplate", "ManaTreat", "PounceBoots", "WhiskerLens" }

local ItemCatalog = {}

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
