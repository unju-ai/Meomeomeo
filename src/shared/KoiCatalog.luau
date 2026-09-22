--!strict

-- Night-market cat-koi. Cream-window QTE, not a stock fishing meter.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type FishDef = {
	id: string,
	name: string,
	rarity: Rarity,
	score: number,
	color: Color3,
	weight: number,
	sweetHalf: number,
	ticker: string?,
	blurb: string,
}

export type LogRow = {
	id: string,
	name: string,
	rarity: Rarity,
	count: number,
}

local FISH: { FishDef } = {
	{
		id = "CreamLoaf",
		name = "Cream Loaf",
		rarity = "Common",
		score = 40,
		color = Color3.fromRGB(255, 243, 224),
		weight = 38,
		sweetHalf = 0.14,
		ticker = nil,
		blurb = "A sleepy canal regular.",
	},
	{
		id = "PeachKoi",
		name = "Peach Koi",
		rarity = "Uncommon",
		score = 90,
		color = Color3.fromRGB(255, 184, 140),
		weight = 26,
		sweetHalf = 0.11,
		ticker = nil,
		blurb = "Sunset scales, night-market tax.",
	},
	{
		id = "MintWhisker",
		name = "Mint Whisker",
		rarity = "Rare",
		score = 180,
		color = Color3.fromRGB(120, 196, 150),
		weight = 16,
		sweetHalf = 0.09,
		ticker = nil,
		blurb = "Smells faintly of Pawmart tea.",
	},
	{
		id = "CobaltBraincell",
		name = "Cobalt Braincell",
		rarity = "Rare",
		score = 220,
		color = Color3.fromRGB(86, 148, 230),
		weight = 10,
		sweetHalf = 0.08,
		ticker = nil,
		blurb = "One shared thought, very wet.",
	},
	{
		id = "AmberLantern",
		name = "Amber Lantern",
		rarity = "Epic",
		score = 400,
		color = Color3.fromRGB(255, 196, 74),
		weight = 7,
		sweetHalf = 0.07,
		ticker = nil,
		blurb = "Glows like a stall lamp.",
	},
	{
		id = "CoralCrown",
		name = "Coral Crown",
		rarity = "Legendary",
		score = 900,
		color = Color3.fromRGB(255, 122, 98),
		weight = 3,
		sweetHalf = 0.055,
		ticker = "LEGENDARY KOI",
		blurb = "The canal's spoiled royalty.",
	},
}

local KoiCatalog = {
	WaitMin = 1.15,
	WaitMax = 3.7,
	BiteSeconds = 2.35,
	BarSpeed = 1.22,
	SweetMid = 0.5,
	RevealSeconds = 1.15,
	Fish = FISH,
}

function KoiCatalog.all(): { FishDef }
	return FISH
end

function KoiCatalog.get(id: string): FishDef?
	for _, fish in FISH do
		if fish.id == id then
			return fish
		end
	end
	return nil
end

function KoiCatalog.totalWeight(): number
	local sum = 0
	for _, fish in FISH do
		sum += fish.weight
	end
	return sum
end

function KoiCatalog.pick(roll: number): FishDef
	local total = KoiCatalog.totalWeight()
	local x = math.clamp(roll, 0, 0.999999) * total
	local acc = 0
	for _, fish in FISH do
		acc += fish.weight
		if x < acc then
			return fish
		end
	end
	return FISH[1]
end

function KoiCatalog.inWindow(bar: number, fish: FishDef): boolean
	return math.abs(bar - KoiCatalog.SweetMid) <= fish.sweetHalf
end

function KoiCatalog.utcDay(unix: number): number
	return math.floor(unix / 86400)
end

function KoiCatalog.dailySeed(unix: number): number
	return KoiCatalog.utcDay(unix) * 404 + 9
end

function KoiCatalog.dayKey(unix: number): string
	local ok, text = pcall(function()
		return os.date("!%Y-%m-%d", math.floor(unix))
	end)
	if ok and typeof(text) == "string" then
		return text
	end
	return `UTC-{KoiCatalog.utcDay(unix)}`
end

function KoiCatalog.parseRarity(value: string): Rarity
	if value == "Legendary" or value == "Epic" or value == "Rare" or value == "Uncommon" then
		return value
	end
	return "Common"
end

function KoiCatalog.rarityTint(rarity: Rarity): Color3
	if rarity == "Legendary" then
		return Color3.fromRGB(255, 122, 98)
	elseif rarity == "Epic" then
		return Color3.fromRGB(255, 196, 74)
	elseif rarity == "Rare" then
		return Color3.fromRGB(86, 148, 230)
	elseif rarity == "Uncommon" then
		return Color3.fromRGB(255, 184, 140)
	end
	return Color3.fromRGB(255, 243, 224)
end

-- Exact fish color when we know the catch (mint vs cobalt both Rare).
function KoiCatalog.catchTint(name: string?, rarity: Rarity): Color3
	if typeof(name) == "string" and name ~= "" then
		for _, fish in FISH do
			if fish.name == name or fish.id == name then
				return fish.color
			end
		end
	end
	return KoiCatalog.rarityTint(rarity)
end

function KoiCatalog.rarityTag(rarity: Rarity): string
	if rarity == "Legendary" then
		return "CROWN"
	elseif rarity == "Epic" then
		return "EPIC"
	elseif rarity == "Rare" then
		return "RARE"
	elseif rarity == "Uncommon" then
		return "UNCM"
	end
	return "CREAM"
end

function KoiCatalog.logRows(counts: { [string]: number }): { LogRow }
	local rows: { LogRow } = {}
	for _, fish in FISH do
		local n = counts[fish.id]
		if typeof(n) == "number" and n > 0 then
			table.insert(rows, {
				id = fish.id,
				name = fish.name,
				rarity = fish.rarity,
				count = math.floor(n),
			})
		end
	end
	return rows
end

return KoiCatalog
