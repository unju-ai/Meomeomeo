--!strict

-- Night-market meme stall. Play yarn only — isolated from in-match MemeStockService.

export type EventKind = "moon" | "rug" | "sneeze"

export type TickerDef = {
	id: string,
	ticker: string,
	name: string,
	blurb: string,
	basePrice: number,
	color: Color3,
}

local TICKERS: { TickerDef } = {
	{
		id = "Loaf",
		ticker = "LOAF",
		name = "Cream Loaf Inc",
		blurb = "Sleeps through the pump. Still prints.",
		basePrice = 8.5,
		color = Color3.fromRGB(255, 243, 224),
	},
	{
		id = "Nyan",
		ticker = "NYAN",
		name = "Nyan Rocket Ltd",
		blurb = "Already in the stratosphere. Maybe.",
		basePrice = 14.2,
		color = Color3.fromRGB(86, 148, 230),
	},
	{
		id = "Chonk",
		ticker = "CHNK",
		name = "Chonk Knight Co",
		blurb = "Heavy. Slow. Occasionally flies.",
		basePrice = 11.0,
		color = Color3.fromRGB(255, 184, 140),
	},
	{
		id = "Brain",
		ticker = "BRAIN",
		name = "One Braincell",
		blurb = "Shared thought. Volatile.",
		basePrice = 6.4,
		color = Color3.fromRGB(120, 196, 150),
	},
	{
		id = "Rug",
		ticker = "RUG",
		name = "Scammy Yarns",
		blurb = "The floor is yarn. Until it isn't.",
		basePrice = 9.8,
		color = Color3.fromRGB(255, 122, 98),
	},
}

local ArcadeCatalog = {
	StartYarn = 100,
	RoundSeconds = 28,
	TickSeconds = 0.32,
	CandleCount = 8,
	MinPrice = 1.5,
	MaxPrice = 88,
	MaxShares = 20,
	EventEveryTicks = 8,
	Disclaimer = "Play yarn only · not real money · not a broker",
	Tickers = TICKERS,
}

function ArcadeCatalog.all(): { TickerDef }
	return TICKERS
end

function ArcadeCatalog.get(id: string): TickerDef?
	for _, row in TICKERS do
		if row.id == id then
			return row
		end
	end
	return nil
end

function ArcadeCatalog.ids(): { string }
	local out = {}
	for _, row in TICKERS do
		table.insert(out, row.id)
	end
	return out
end

function ArcadeCatalog.roundPrice(price: number): number
	return math.clamp(math.floor(price * 10 + 0.5) / 10, ArcadeCatalog.MinPrice, ArcadeCatalog.MaxPrice)
end

function ArcadeCatalog.tickPrice(price: number, drift: number): number
	return ArcadeCatalog.roundPrice(price * (1 + drift))
end

function ArcadeCatalog.eventLabel(kind: EventKind, ticker: string): string
	if kind == "moon" then
		return `TO THE MOON · {ticker}`
	elseif kind == "rug" then
		return `RUG PULL · {ticker}`
	end
	return `WHALE SNEEZE · {ticker}`
end

function ArcadeCatalog.rollEvent(roll: number): EventKind?
	if roll < 0.42 then
		return nil
	elseif roll < 0.68 then
		return "moon"
	elseif roll < 0.9 then
		return "rug"
	end
	return "sneeze"
end

function ArcadeCatalog.eventMag(kind: EventKind, roll: number): number
	local x = math.clamp(roll, 0, 1)
	if kind == "moon" then
		return 0.18 + x * 0.2
	elseif kind == "rug" then
		return 0.26 + x * 0.2
	end
	return (x - 0.5) * 0.28
end

function ArcadeCatalog.applyEvent(price: number, kind: EventKind, mag: number): number
	if kind == "moon" then
		return ArcadeCatalog.roundPrice(price * (1 + mag))
	elseif kind == "rug" then
		return ArcadeCatalog.roundPrice(price * (1 - mag))
	end
	return ArcadeCatalog.roundPrice(price * (1 + mag))
end

function ArcadeCatalog.canBuy(cash: number, price: number, shares: number): boolean
	return cash + 1e-6 >= price and shares < ArcadeCatalog.MaxShares
end

function ArcadeCatalog.canSell(shares: number): boolean
	return shares >= 1
end

function ArcadeCatalog.afterBuy(cash: number, shares: number, price: number): (number, number)
	return cash - price, shares + 1
end

function ArcadeCatalog.afterSell(cash: number, shares: number, price: number): (number, number)
	return cash + price, shares - 1
end

function ArcadeCatalog.equity(cash: number, holdings: { [string]: number }, prices: { [string]: number }): number
	local e = cash
	for id, n in holdings do
		local p = prices[id]
		if typeof(p) == "number" then
			e += n * p
		end
	end
	return e
end

function ArcadeCatalog.profit(equity: number, startYarn: number): number
	return math.floor((equity - startYarn) * 10 + 0.5) / 10
end

function ArcadeCatalog.pushCandle(candles: { number }, price: number): { number }
	local nextCandles = {}
	for _, value in candles do
		table.insert(nextCandles, value)
	end
	table.insert(nextCandles, price)
	while #nextCandles > ArcadeCatalog.CandleCount do
		table.remove(nextCandles, 1)
	end
	return nextCandles
end

function ArcadeCatalog.signedYarn(value: number): string
	local n = ArcadeCatalog.profit(value, 0)
	if n > 0 then
		return `+{n}`
	end
	return tostring(n)
end

function ArcadeCatalog.utcDay(unix: number): number
	return math.floor(unix / 86400)
end

function ArcadeCatalog.dailySeed(unix: number): number
	return ArcadeCatalog.utcDay(unix) * 404 + 17
end

function ArcadeCatalog.dayKey(unix: number): string
	local ok, text = pcall(function()
		return os.date("!%Y-%m-%d", math.floor(unix))
	end)
	if ok and typeof(text) == "string" then
		return text
	end
	return `UTC-{ArcadeCatalog.utcDay(unix)}`
end

return ArcadeCatalog
