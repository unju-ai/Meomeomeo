--!strict

-- Night-market drip. Hats + trails, yarn/points only — no Robux shop.

export type Slot = "hat" | "trail"
export type Attach = "head" | "neck" | "face" | "aura"
export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic"
export type UnlockKind = "free" | "yarn" | "runMeters" | "koiLegendary" | "partyWin" | "arcadeProfit"

export type Unlock = {
	kind: UnlockKind,
	amount: number?,
}

export type CosmeticDef = {
	id: string,
	name: string,
	slot: Slot,
	attach: Attach,
	rarity: Rarity,
	blurb: string,
	hint: string,
	color: Color3,
	unlock: Unlock,
	emoteFlair: boolean,
}

export type Stats = {
	runMeters: number,
	koiLegendary: boolean,
	partyWins: number,
	arcadeProfit: number,
}

local ITEMS: { CosmeticDef } = {
	{
		id = "CreamCap",
		name = "Cream Cap",
		slot = "hat",
		attach = "head",
		rarity = "Common",
		blurb = "Night-market starter beanie.",
		hint = "Starter drip",
		color = Color3.fromRGB(255, 243, 224),
		unlock = { kind = "free" },
		emoteFlair = false,
	},
	{
		id = "GoldBell",
		name = "Gold Bell",
		slot = "hat",
		attach = "neck",
		rarity = "Uncommon",
		blurb = "Jingling collar bell. Closet yarn only.",
		hint = "Buy for 25 closet yarn",
		color = Color3.fromRGB(255, 196, 74),
		unlock = { kind = "yarn", amount = 25 },
		emoteFlair = false,
	},
	{
		id = "CoralBeanie",
		name = "Coral Beanie",
		slot = "hat",
		attach = "head",
		rarity = "Uncommon",
		blurb = "Warm from a long Yarn Run.",
		hint = "Yarn Run 200m PB",
		color = Color3.fromRGB(255, 122, 98),
		unlock = { kind = "runMeters", amount = 200 },
		emoteFlair = false,
	},
	{
		id = "CanalCrown",
		name = "Canal Crown",
		slot = "hat",
		attach = "head",
		rarity = "Epic",
		blurb = "Coral-crown loaf, wearable.",
		hint = "Catch a legendary koi",
		color = Color3.fromRGB(255, 122, 98),
		unlock = { kind = "koiLegendary" },
		emoteFlair = true,
	},
	{
		id = "PartyTiara",
		name = "Party Tiara",
		slot = "hat",
		attach = "head",
		rarity = "Rare",
		blurb = "Crowned in the courtyard.",
		hint = "Win a Yarn Party",
		color = Color3.fromRGB(255, 160, 200),
		unlock = { kind = "partyWin", amount = 1 },
		emoteFlair = false,
	},
	{
		id = "TapeShades",
		name = "Tape Shades",
		slot = "hat",
		attach = "face",
		rarity = "Uncommon",
		blurb = "For watching the yarn tape.",
		hint = "Arcade daily +15 yarn",
		color = Color3.fromRGB(36, 24, 48),
		unlock = { kind = "arcadeProfit", amount = 15 },
		emoteFlair = false,
	},
	{
		id = "YarnPuff",
		name = "Yarn Puff",
		slot = "trail",
		attach = "aura",
		rarity = "Common",
		blurb = "A peach yarn cloud.",
		hint = "Starter trail",
		color = Color3.fromRGB(255, 184, 140),
		unlock = { kind = "free" },
		emoteFlair = false,
	},
	{
		id = "MintAura",
		name = "Mint Aura",
		slot = "trail",
		attach = "aura",
		rarity = "Rare",
		blurb = "Canal-green afterglow.",
		hint = "Yarn Run 400m PB",
		color = Color3.fromRGB(120, 196, 150),
		unlock = { kind = "runMeters", amount = 400 },
		emoteFlair = false,
	},
	{
		id = "BraincellOrbs",
		name = "Braincell Orbs",
		slot = "trail",
		attach = "aura",
		rarity = "Epic",
		blurb = "One shared thought, orbiting.",
		hint = "Arcade daily +25 yarn",
		color = Color3.fromRGB(86, 148, 230),
		unlock = { kind = "arcadeProfit", amount = 25 },
		emoteFlair = true,
	},
	{
		id = "MoonDust",
		name = "Moon Dust",
		slot = "trail",
		attach = "aura",
		rarity = "Epic",
		blurb = "Party-win sparkle. Very illegal vibes.",
		hint = "Win a Yarn Party",
		color = Color3.fromRGB(255, 220, 70),
		unlock = { kind = "partyWin", amount = 1 },
		emoteFlair = true,
	},
}

local CosmeticCatalog = {
	StartYarn = 40,
	Disclaimer = "Closet yarn is play points — not real money, not Robux.",
	Items = ITEMS,
}

function CosmeticCatalog.all(): { CosmeticDef }
	return ITEMS
end

function CosmeticCatalog.get(id: any): CosmeticDef?
	if typeof(id) ~= "string" then
		return nil
	end
	for _, row in ITEMS do
		if row.id == id then
			return row
		end
	end
	return nil
end

function CosmeticCatalog.starters(): { string }
	local out = {}
	for _, row in ITEMS do
		if row.unlock.kind == "free" then
			table.insert(out, row.id)
		end
	end
	return out
end

function CosmeticCatalog.meets(def: CosmeticDef, stats: Stats): boolean
	local kind = def.unlock.kind
	local amount = def.unlock.amount or 0
	if kind == "free" then
		return true
	elseif kind == "yarn" then
		return false
	elseif kind == "runMeters" then
		return stats.runMeters >= amount
	elseif kind == "koiLegendary" then
		return stats.koiLegendary == true
	elseif kind == "partyWin" then
		return stats.partyWins >= math.max(1, amount)
	elseif kind == "arcadeProfit" then
		return stats.arcadeProfit >= amount
	end
	return false
end

function CosmeticCatalog.yarnCost(def: CosmeticDef): number
	if def.unlock.kind == "yarn" then
		return def.unlock.amount or 0
	end
	return 0
end

function CosmeticCatalog.canBuy(def: CosmeticDef, yarn: number, owned: boolean): boolean
	return not owned and CosmeticCatalog.yarnCost(def) > 0 and yarn >= CosmeticCatalog.yarnCost(def)
end

function CosmeticCatalog.ownedSet(ids: { string }): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, id in CosmeticCatalog.starters() do
		set[id] = true
	end
	for _, id in ids do
		if CosmeticCatalog.get(id) then
			set[id] = true
		end
	end
	return set
end

function CosmeticCatalog.ownedList(ids: { string }): { string }
	local set = CosmeticCatalog.ownedSet(ids)
	local out = {}
	for _, row in ITEMS do
		if set[row.id] then
			table.insert(out, row.id)
		end
	end
	return out
end

function CosmeticCatalog.parseSlot(value: any): Slot?
	if value == "hat" or value == "trail" then
		return value
	end
	return nil
end

function CosmeticCatalog.rarityTint(rarity: Rarity): Color3
	if rarity == "Epic" then
		return Color3.fromRGB(255, 122, 98)
	elseif rarity == "Rare" then
		return Color3.fromRGB(255, 196, 74)
	elseif rarity == "Uncommon" then
		return Color3.fromRGB(255, 184, 140)
	end
	return Color3.fromRGB(255, 243, 224)
end

function CosmeticCatalog.emoteTint(hatId: string?, trailId: string?): Color3?
	for _, id in { trailId, hatId } do
		local def = CosmeticCatalog.get(id)
		if def and def.emoteFlair then
			return def.color
		end
	end
	return nil
end

return CosmeticCatalog
