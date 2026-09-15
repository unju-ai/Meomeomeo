-- Run through tools/test-arcade.py against src/shared/ArcadeCatalog.luau.

assert(ArcadeCatalog.StartYarn == 100)
assert(ArcadeCatalog.RoundSeconds == 28)
assert(ArcadeCatalog.CandleCount == 8)
assert(ArcadeCatalog.MaxShares == 20)
assert(#ArcadeCatalog.all() == 5, "Five cat tickers")
assert(#ArcadeCatalog.ids() == 5)

local seen = {}
for _, row in ArcadeCatalog.all() do
	assert(row.ticker ~= nil and row.id ~= nil)
	assert(seen[row.ticker] == nil, "Duplicate ticker")
	seen[row.ticker] = true
	assert(ArcadeCatalog.get(row.id) == row)
end
assert(ArcadeCatalog.get("missing") == nil)
assert(ArcadeCatalog.get("Loaf") ~= nil and ArcadeCatalog.get("Loaf").ticker == "LOAF")
assert(ArcadeCatalog.get("Rug").ticker == "RUG")

assert(ArcadeCatalog.roundPrice(8.24) == 8.2)
assert(ArcadeCatalog.roundPrice(0) == ArcadeCatalog.MinPrice)
assert(ArcadeCatalog.tickPrice(10, 0.1) > 10)
assert(ArcadeCatalog.tickPrice(10, -0.1) < 10)

assert(ArcadeCatalog.eventLabel("moon", "LOAF") == "TO THE MOON · LOAF")
assert(ArcadeCatalog.eventLabel("rug", "RUG") == "RUG PULL · RUG")
assert(string.find(ArcadeCatalog.eventLabel("sneeze", "NYAN"), "WHALE", 1, true))

assert(ArcadeCatalog.rollEvent(0.1) == nil)
assert(ArcadeCatalog.rollEvent(0.5) == "moon")
assert(ArcadeCatalog.rollEvent(0.8) == "rug")
assert(ArcadeCatalog.rollEvent(0.95) == "sneeze")

local pumped = ArcadeCatalog.applyEvent(10, "moon", 0.2)
assert(pumped > 10)
local dumped = ArcadeCatalog.applyEvent(10, "rug", 0.3)
assert(dumped < 10)

assert(ArcadeCatalog.canBuy(100, 8.5, 0) == true)
assert(ArcadeCatalog.canBuy(8, 8.5, 0) == false)
assert(ArcadeCatalog.canBuy(100, 8.5, ArcadeCatalog.MaxShares) == false)
assert(ArcadeCatalog.canSell(0) == false)
assert(ArcadeCatalog.canSell(1) == true)

local cash, shares = ArcadeCatalog.afterBuy(100, 0, 8.5)
assert(cash == 91.5 and shares == 1)
cash, shares = ArcadeCatalog.afterSell(cash, shares, 10)
assert(cash == 101.5 and shares == 0)

local eq = ArcadeCatalog.equity(80, { Loaf = 2, Nyan = 1 }, { Loaf = 10, Nyan = 5 })
assert(eq == 105)
assert(ArcadeCatalog.profit(105, 100) == 5)
assert(ArcadeCatalog.profit(90, 100) == -10)
assert(ArcadeCatalog.signedYarn(12) == "+12")
assert(ArcadeCatalog.signedYarn(-3) == "-3")

local candles = ArcadeCatalog.pushCandle({}, 8)
for i = 1, 10 do
	candles = ArcadeCatalog.pushCandle(candles, 8 + i)
end
assert(#candles == ArcadeCatalog.CandleCount)

local day = 86400 * 21000 + 3600
assert(ArcadeCatalog.dailySeed(day) == ArcadeCatalog.dailySeed(day + 80000), "Seed must be stable for a UTC day")
assert(ArcadeCatalog.dailySeed(day) ~= ArcadeCatalog.dailySeed(day + 86400), "Next UTC day must change the tape")
assert(ArcadeCatalog.utcDay(day + 10) == ArcadeCatalog.utcDay(day))
assert(typeof(ArcadeCatalog.dayKey(day)) == "string")

assert(string.find(string.lower(ArcadeCatalog.Disclaimer), "yarn", 1, true))
assert(string.find(string.lower(ArcadeCatalog.Disclaimer), "not real", 1, true) or string.find(string.lower(ArcadeCatalog.Disclaimer), "not a broker", 1, true))

print("PASS: arcade catalog, yarn-only tape, moon/rug events, candles, daily seed")
