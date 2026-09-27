--!strict

-- Pure display helpers for the Cat Rift Pawmart (B) panel.
-- Prices and grants stay on ItemCatalog / ShopService; this only styles the register.
-- RGB tables stay Color3-free so smokes can assert without Theme / Instance.

local ShopPaint = {}

ShopPaint.Cream = { 255, 243, 224 }
ShopPaint.Muted = { 122, 92, 80 }
ShopPaint.Peach = { 255, 184, 140 }
ShopPaint.Amber = { 255, 196, 74 }
ShopPaint.Mint = { 120, 196, 150 }
ShopPaint.Coral = { 255, 122, 98 }
ShopPaint.Ink = { 52, 36, 32 }
ShopPaint.Panel = { 44, 30, 28 }
ShopPaint.PanelAlt = { 62, 42, 38 }
ShopPaint.Pink = { 255, 92, 196 }

export type Section = "Stats" | "Vision" | "Actives"

export type CardKind = "buyable" | "short" | "owned" | "full" | "away" | "sellable" | "sellAway"

export type CardPaint = {
	kind: CardKind,
	fill: { number },
	stroke: { number },
	text: { number },
	fillAlpha: number,
	strokeAlpha: number,
	textAlpha: number,
	active: boolean,
}

-- Catalog ids grouped for the register (display only — costs unchanged).
local SECTION_OF: { [string]: Section } = {
	Longclaw = "Stats",
	Yarnplate = "Stats",
	ManaTreat = "Stats",
	PounceBoots = "Stats",
	WhiskerLens = "Vision",
	ControlYarn = "Vision",
	YarnCleave = "Actives",
	StallFang = "Actives",
	PaperCharm = "Actives",
}

local KEYBIND: { [string]: string } = {
	WhiskerLens = "5",
	ControlYarn = "6",
	YarnCleave = "7",
}

local SECTION_ORDER: { Section } = { "Stats", "Vision", "Actives" }

local SECTION_TITLE: { [Section]: string } = {
	Stats = "STATS · sticks",
	Vision = "VISION · lens & pink",
	Actives = "ACTIVES · night market",
}

local SECTION_TAG: { [Section]: string } = {
	Stats = "STATS",
	Vision = "VISION",
	Actives = "ACTIVES",
}

function ShopPaint.sectionOf(itemId: string): Section
	return SECTION_OF[itemId] or "Stats"
end

function ShopPaint.sectionOrder(): { Section }
	return table.clone(SECTION_ORDER)
end

function ShopPaint.sectionTitle(section: Section): string
	return SECTION_TITLE[section] or section
end

function ShopPaint.sectionTag(section: Section): string
	return SECTION_TAG[section] or section
end

-- Active key chips for Lens / Control Yarn / Yarn Cleave. Nil for passives / sticks.
function ShopPaint.keybind(itemId: string): string?
	return KEYBIND[itemId]
end

-- Matches the purse chip gold fragment (`{n}g`).
function ShopPaint.goldLine(gold: number): string
	local n = math.floor(gold)
	if n < 0 then
		n = 0
	end
	return `{n}g`
end

function ShopPaint.fountainLine(atFountain: boolean): string
	if atFountain then
		return "at fountain"
	end
	return "must be at fountain"
end

function ShopPaint.headerLine(gold: number, atFountain: boolean): string
	return `{ShopPaint.goldLine(gold)} · {ShopPaint.fountainLine(atFountain)}`
end

function ShopPaint.hintLine(): string
	return "4 trinket · Stats / Vision / Actives · 5 lens · 6 pink · 7 cleave"
end

function ShopPaint.sellHint(): string
	return "Sell · 70% back · one click · fountain only"
end

function ShopPaint.awayLine(selling: boolean): string
	if selling then
		return "Pawn only at your fountain"
	end
	return "Shop open — buy only at your fountain"
end

-- Title under the item name: cost, stack, or owned.
function ShopPaint.nameLine(name: string, cost: number, owned: number, maxStack: number, kind: CardKind): string
	if maxStack > 1 then
		return `{name}  ·  {owned}/{maxStack}  ·  {cost}g`
	end
	if kind == "full" or kind == "owned" then
		return `{name}  ·  owned`
	end
	return `{name}  ·  {cost}g`
end

function ShopPaint.buyToast(name: string): string
	return `Bought {name} · Pawmart`
end

-- Sell-mode title. `refund` is ShopSell.refundGold(cost) for one copy.
function ShopPaint.sellNameLine(name: string, refund: number, owned: number, maxStack: number): string
	local n = math.floor(refund)
	if n < 0 then
		n = 0
	end
	if maxStack > 1 then
		return `{name}  ·  {owned}/{maxStack}  ·  sell +{n}g`
	end
	return `{name}  ·  sell +{n}g`
end

-- Resolve register state. Prices untouched — only whether the card looks buyable.
-- `selling` flips owned rows into a one-click pawn. Unowned rows stay quiet.
function ShopPaint.cardKind(gold: number, atFountain: boolean, owned: number, maxStack: number, cost: number, selling: boolean?): CardKind
	if selling == true then
		if owned <= 0 then
			return "away"
		end
		if not atFountain then
			return "sellAway"
		end
		return "sellable"
	end
	local cap = if maxStack > 1 then maxStack else 1
	if owned >= cap and owned > 0 then
		return if cap > 1 then "full" else "owned"
	end
	if not atFountain then
		return "away"
	end
	if gold < cost then
		return "short"
	end
	return "buyable"
end

function ShopPaint.cardPaint(kind: CardKind): CardPaint
	if kind == "buyable" then
		return {
			kind = kind,
			fill = ShopPaint.Ink,
			stroke = ShopPaint.Amber,
			text = ShopPaint.Cream,
			fillAlpha = 0,
			strokeAlpha = 0.35,
			textAlpha = 0,
			active = true,
		}
	elseif kind == "short" then
		return {
			kind = kind,
			fill = ShopPaint.PanelAlt,
			stroke = ShopPaint.Coral,
			text = ShopPaint.Peach,
			fillAlpha = 0.15,
			strokeAlpha = 0.45,
			textAlpha = 0.15,
			active = false,
		}
	elseif kind == "owned" or kind == "full" then
		return {
			kind = kind,
			fill = ShopPaint.PanelAlt,
			stroke = ShopPaint.Mint,
			text = ShopPaint.Mint,
			fillAlpha = 0.05,
			strokeAlpha = 0.4,
			textAlpha = 0,
			active = false,
		}
	elseif kind == "sellable" then
		return {
			kind = kind,
			fill = ShopPaint.Ink,
			stroke = ShopPaint.Mint,
			text = ShopPaint.Cream,
			fillAlpha = 0,
			strokeAlpha = 0.25,
			textAlpha = 0,
			active = true,
		}
	elseif kind == "sellAway" then
		-- Muted, but the click still asks the server so the refuse toast fires.
		return {
			kind = kind,
			fill = ShopPaint.Panel,
			stroke = ShopPaint.Muted,
			text = ShopPaint.Muted,
			fillAlpha = 0.25,
			strokeAlpha = 0.55,
			textAlpha = 0.35,
			active = true,
		}
	else
		-- away from fountain
		return {
			kind = kind,
			fill = ShopPaint.Panel,
			stroke = ShopPaint.Muted,
			text = ShopPaint.Muted,
			fillAlpha = 0.25,
			strokeAlpha = 0.55,
			textAlpha = 0.35,
			active = false,
		}
	end
end

function ShopPaint.sectionFill(section: Section): { number }
	if section == "Vision" then
		return ShopPaint.Pink
	elseif section == "Actives" then
		return ShopPaint.Coral
	end
	return ShopPaint.Amber
end

return ShopPaint
