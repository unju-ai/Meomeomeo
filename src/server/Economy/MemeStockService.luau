--!strict

-- Side system: in-match meme prices on the cats actually fighting.
-- Not the core loop. Cheer yarn is not Closet yarn and not the Meme Arcade wallet.
-- Prices are server-authored fiction. Lane kittens and camps do not move them.

local Players = game:GetService("Players")

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local MemeStockLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("MemeStockLogic"))
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)

local MemeStockService = {}

export type TapeHit = {
	id: string,
	kind: string,
}

local rng = Random.new()
local tickers: { [string]: Types.TickerState } = {}
local yarn: { [number]: number } = {}
-- Per champion, per kind. A kill does not eat the death or post gap.
local lastBump: { [string]: { [string]: number } } = {}

local function seed()
	tickers = {}
	lastBump = {}
	for _, champ in ChampionCatalog.all() do
		local symbol = champ.ticker or string.upper(string.sub(champ.name, 1, 4))
		tickers[champ.id] = {
			id = champ.id,
			symbol = symbol,
			name = champ.name,
			price = 10 + rng:NextNumber(0, 8),
			change = 0,
		}
	end
end

local function snapshot()
	local list = {}
	for _, ticker in tickers do
		table.insert(list, ticker)
	end
	table.sort(list, function(a, b)
		return a.symbol < b.symbol
	end)
	return list
end

local function broadcast(flash: { string }?)
	Remotes.event("MarketUpdated"):FireAllClients({
		tickers = snapshot(),
		enabled = Config.Economy.Enabled,
		flash = flash,
	})
end

local function applyMagnitude(championId: string, magnitude: number): string?
	local ticker = tickers[championId]
	if not ticker then
		return nil
	end
	local price, delta = MemeStockLogic.nextPrice(ticker.price, magnitude)
	ticker.price = price
	ticker.change = delta
	if math.abs(delta) < 0.001 then
		return nil
	end
	return ticker.symbol
end

function MemeStockService.get(player: Player)
	return {
		yarn = yarn[player.UserId] or Config.Economy.StartingYarn,
		tickers = snapshot(),
		enabled = Config.Economy.Enabled,
	}
end

function MemeStockService.cheer(player: Player, championId: unknown): Types.TradeResult
	if not Config.Economy.Enabled then
		return { ok = false, error = "Meme stocks are disabled." }
	end
	if typeof(championId) ~= "string" or not tickers[championId] then
		return { ok = false, error = "Unknown ticker." }
	end
	local wallet = yarn[player.UserId] or Config.Economy.StartingYarn
	if wallet < Config.Economy.CheerCost then
		return { ok = false, error = "Not enough yarn." }
	end
	yarn[player.UserId] = wallet - Config.Economy.CheerCost
	local symbol = applyMagnitude(championId, Config.Economy.CheerBump)
	broadcast(if symbol then { symbol } else nil)
	return { ok = true }
end

-- One broadcast for every cat that actually moved.
function MemeStockService.reactMany(events: { TapeHit })
	if not Config.Economy.Enabled then
		return
	end
	local flashed = {}
	local seen: { [string]: boolean } = {}
	local now = os.clock()
	for _, event in events do
		local championId = event.id
		if tickers[championId] then
			local book = lastBump[championId]
			if not book then
				book = {}
				lastBump[championId] = book
			end
			local decision = MemeStockLogic.admit(event.kind, now, book[event.kind])
			if decision then
				book[event.kind] = now
				local symbol = applyMagnitude(championId, decision.magnitude)
				if symbol and not seen[symbol] then
					seen[symbol] = true
					table.insert(flashed, symbol)
				end
			end
		end
	end
	if #flashed > 0 then
		broadcast(flashed)
	end
end

-- Personal last hit uses the bigger step. No champion means lane kittens: team nudge.
function MemeStockService.reactStructure(championId: string?, tier: string, allyIds: { string })
	local events: { TapeHit } = {}
	if championId then
		local kind = MemeStockLogic.structureKind(tier, false)
		if kind then
			table.insert(events, { id = championId, kind = kind })
		end
	else
		local kind = MemeStockLogic.structureKind(tier, true)
		if kind then
			local seen: { [string]: boolean } = {}
			for _, allyId in allyIds do
				if not seen[allyId] then
					seen[allyId] = true
					table.insert(events, { id = allyId, kind = kind })
				end
			end
		end
	end
	MemeStockService.reactMany(events)
end

function MemeStockService.init()
	seed()
	Players.PlayerAdded:Connect(function(player)
		yarn[player.UserId] = Config.Economy.StartingYarn
	end)
	Players.PlayerRemoving:Connect(function(player)
		yarn[player.UserId] = nil
	end)
	for _, player in Players:GetPlayers() do
		yarn[player.UserId] = Config.Economy.StartingYarn
	end

	task.spawn(function()
		while true do
			task.wait(4)
			if not Config.Economy.Enabled then
				continue
			end
			for _, ticker in tickers do
				local drift = rng:NextNumber(-0.06, 0.06)
				local delta = ticker.price * drift
				ticker.price = math.max(1, ticker.price + delta)
				ticker.change = delta
			end
			broadcast(nil)
		end
	end)
end

return MemeStockService
