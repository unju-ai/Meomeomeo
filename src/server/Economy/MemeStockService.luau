--!strict

-- Side system: in-match "meme stocks" on cat champions.
-- Not the core loop. Yarn is a fun currency; prices are server-authored.

local Players = game:GetService("Players")

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)

local MemeStockService = {}

local rng = Random.new()
local tickers: { [string]: Types.TickerState } = {}
local yarn: { [number]: number } = {}

local function seed()
	tickers = {}
	for _, champ in ChampionCatalog.all() do
		local symbol = champ.ticker or string.upper(string.sub(champ.name, 1, 4))
		tickers[champ.id] = {
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

local function broadcast()
	Remotes.event("MarketUpdated"):FireAllClients({
		tickers = snapshot(),
	})
end

function MemeStockService.get(player: Player)
	return {
		yarn = yarn[player.UserId] or Config.Economy.StartingYarn,
		tickers = snapshot(),
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
	local ticker = tickers[championId]
	local bump = ticker.price * Config.Economy.CheerBump
	ticker.price = math.max(1, ticker.price + bump)
	ticker.change = bump
	broadcast()
	return { ok = true }
end

function MemeStockService.bumpChampion(championId: string, magnitude: number)
	local ticker = tickers[championId]
	if not ticker then
		return
	end
	local bump = ticker.price * magnitude
	ticker.price = math.max(1, ticker.price + bump)
	ticker.change = bump
	broadcast()
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
			broadcast()
		end
	end)
end

return MemeStockService
