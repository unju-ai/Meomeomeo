--!strict

-- Stall tape HUD: giant PnL, neon candles, yarn-only disclaimer. Not a trading app.

local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local ArcadeCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ArcadeCatalog"))

local ArcadeHud = {}

export type ArcadeHudApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (snap: Types.ArcadeSnapshot) -> (),
	onHub: (() -> ()) -> (),
	onRetry: (() -> ()) -> (),
	onTrade: ((tickerId: string, action: "buy" | "sell") -> ()) -> (),
}

local function changeTint(change: number): Color3
	if change > 0 then
		return Theme.good
	elseif change < 0 then
		return Theme.bad
	end
	return Theme.peach
end

function ArcadeHud.create(parent: Instance): ArcadeHudApi
	local root = Instance.new("Frame")
	root.Name = "ArcadeHud"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = parent

	local title = Theme.text(root, "Title", "MEME ARCADE", 42, Theme.amber, Theme.fontTitle)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 64)
	title.Size = UDim2.fromOffset(560, 46)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextStrokeTransparency = 0.28

	local pnl = Theme.text(root, "Pnl", "+0 yarn", 56, Theme.good, Theme.fontTitle)
	pnl.AnchorPoint = Vector2.new(0.5, 0)
	pnl.Position = UDim2.new(0.5, 0, 0, 108)
	pnl.Size = UDim2.fromOffset(640, 58)
	pnl.TextXAlignment = Enum.TextXAlignment.Center
	pnl.TextStrokeTransparency = 0.22

	local event = Theme.text(root, "Event", "", 30, Theme.foam, Theme.fontTitle)
	event.AnchorPoint = Vector2.new(0.5, 0)
	event.Position = UDim2.new(0.5, 0, 0, 164)
	event.Size = UDim2.fromOffset(680, 34)
	event.TextXAlignment = Enum.TextXAlignment.Center
	event.TextStrokeTransparency = 0.28

	local meta = Theme.text(root, "Meta", "yarn 100  ·  28s", 14, Theme.cream, Theme.fontMono)
	meta.AnchorPoint = Vector2.new(0.5, 0)
	meta.Position = UDim2.new(0.5, 0, 0, 198)
	meta.Size = UDim2.fromOffset(560, 18)
	meta.TextXAlignment = Enum.TextXAlignment.Center

	local toast = Theme.text(root, "Toast", "", 16, Theme.peach, Theme.fontMono)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 216)
	toast.Size = UDim2.fromOffset(480, 18)
	toast.TextXAlignment = Enum.TextXAlignment.Center

	local tape = Instance.new("Frame")
	tape.Name = "Tape"
	tape.AnchorPoint = Vector2.new(0.5, 1)
	tape.Position = UDim2.new(0.5, 0, 1, -92)
	tape.Size = UDim2.fromOffset(740, 196)
	tape.BackgroundTransparency = 1
	tape.Parent = root
	Theme.list(tape, 8, Enum.FillDirection.Horizontal)

	local disclaimer = Theme.text(root, "Disclaimer", ArcadeCatalog.Disclaimer, 12, Theme.muted, Theme.fontMono)
	disclaimer.AnchorPoint = Vector2.new(0.5, 1)
	disclaimer.Position = UDim2.new(0.5, 0, 1, -58)
	disclaimer.Size = UDim2.fromOffset(640, 16)
	disclaimer.TextXAlignment = Enum.TextXAlignment.Center

	local hint = Theme.text(root, "Hint", "1–5 buy  ·  Shift+1–5 sell  ·  tap the stall tape", 13, Theme.peach)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -18)
	hint.Size = UDim2.fromOffset(620, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Center

	local recap = Instance.new("Frame")
	recap.Name = "Recap"
	recap.AnchorPoint = Vector2.new(0.5, 0.5)
	recap.Position = UDim2.fromScale(0.5, 0.52)
	recap.Size = UDim2.fromOffset(400, 268)
	recap.BackgroundColor3 = Theme.panel
	recap.Visible = false
	recap.ZIndex = 8
	recap.Parent = root
	Theme.corner(recap, 20)
	Theme.stroke(recap, Theme.amber, 3, 0.12)
	Theme.pad(recap, 18)

	local recapTitle = Theme.text(recap, "Title", "TAPE SETTLED", 26, Theme.amber, Theme.fontTitle)
	recapTitle.Size = UDim2.new(1, 0, 0, 30)
	recapTitle.TextXAlignment = Enum.TextXAlignment.Center
	recapTitle.ZIndex = 9

	local recapPnl = Theme.text(recap, "Pnl", "+0 yarn", 28, Theme.good, Theme.fontTitle)
	recapPnl.Position = UDim2.fromOffset(0, 40)
	recapPnl.Size = UDim2.new(1, 0, 0, 32)
	recapPnl.TextXAlignment = Enum.TextXAlignment.Center
	recapPnl.ZIndex = 9

	local recapMeta = Theme.text(recap, "Meta", "", 13, Theme.peach)
	recapMeta.Position = UDim2.fromOffset(0, 78)
	recapMeta.Size = UDim2.new(1, 0, 0, 52)
	recapMeta.TextXAlignment = Enum.TextXAlignment.Center
	recapMeta.ZIndex = 9

	local recapDisc = Theme.text(recap, "Disc", ArcadeCatalog.Disclaimer, 11, Theme.muted, Theme.fontMono)
	recapDisc.Position = UDim2.fromOffset(0, 132)
	recapDisc.Size = UDim2.new(1, 0, 0, 28)
	recapDisc.TextXAlignment = Enum.TextXAlignment.Center
	recapDisc.ZIndex = 9

	local retry = Theme.button(recap, "Retry", "Play again", Theme.amber)
	retry.Position = UDim2.new(0, 0, 1, -88)
	retry.Size = UDim2.new(1, 0, 0, 38)
	retry.ZIndex = 9

	local hub = Theme.button(recap, "Hub", "Back to hub", Theme.peach)
	hub.Position = UDim2.new(0, 0, 1, -42)
	hub.Size = UDim2.new(1, 0, 0, 36)
	hub.ZIndex = 9

	local leave = Theme.button(root, "Leave", "Back to hub", Theme.peach)
	leave.AnchorPoint = Vector2.new(1, 1)
	leave.Position = UDim2.new(1, -18, 1, -18)
	leave.Size = UDim2.fromOffset(150, 36)

	local hubHandler: (() -> ())? = nil
	local retryHandler: (() -> ())? = nil
	local tradeHandler: ((string, "buy" | "sell") -> ())? = nil

	leave.MouseButton1Click:Connect(function()
		if hubHandler then
			hubHandler()
		end
	end)
	hub.MouseButton1Click:Connect(function()
		if hubHandler then
			hubHandler()
		end
	end)
	retry.MouseButton1Click:Connect(function()
		if retryHandler then
			retryHandler()
		end
	end)

	local cards: {
		{
			root: Frame,
			id: string,
			ticker: TextLabel,
			price: TextLabel,
			change: TextLabel,
			shares: TextLabel,
			candles: Frame,
			buy: TextButton,
			sell: TextButton,
		}
	} =
		{}

	local function paintCandles(host: Frame, values: { number }, tint: Color3)
		for _, child in host:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		if #values == 0 then
			return
		end
		local lo = values[1]
		local hi = values[1]
		for _, v in values do
			if v < lo then
				lo = v
			end
			if v > hi then
				hi = v
			end
		end
		local span = math.max(0.4, hi - lo)
		for i, v in values do
			local h = 0.22 + 0.72 * ((v - lo) / span)
			local bar = Instance.new("Frame")
			bar.Name = "C" .. i
			bar.AnchorPoint = Vector2.new(0, 1)
			bar.Position = UDim2.new((i - 1) / ArcadeCatalog.CandleCount, 2, 1, 0)
			bar.Size = UDim2.new(1 / ArcadeCatalog.CandleCount, -3, h, 0)
			bar.BackgroundColor3 = tint
			bar.BorderSizePixel = 0
			bar.Parent = host
			Theme.corner(bar, 3)
		end
	end

	local function ensureCards(tickers: { Types.ArcadeTickerView })
		if #cards == #tickers then
			return
		end
		for _, card in cards do
			card.root:Destroy()
		end
		cards = {}
		for i, row in tickers do
			local card = Instance.new("Frame")
			card.Name = row.id
			card.Size = UDim2.new(0, 136, 1, 0)
			card.BackgroundColor3 = Theme.panel
			card.LayoutOrder = i
			card.Parent = tape
			Theme.corner(card, 12)
			Theme.stroke(card, Theme.peach, 2, 0.28)
			Theme.pad(card, 8)

			local ticker = Theme.text(card, "Ticker", row.ticker, 18, Theme.amber, Theme.fontTitle)
			ticker.Size = UDim2.new(1, 0, 0, 20)

			local price = Theme.text(card, "Price", tostring(row.price), 16, Theme.cream, Theme.fontMono)
			price.Position = UDim2.fromOffset(0, 20)
			price.Size = UDim2.new(1, 0, 0, 18)

			local change = Theme.text(card, "Change", "0", 12, Theme.peach, Theme.fontMono)
			change.Position = UDim2.fromOffset(0, 38)
			change.Size = UDim2.new(1, 0, 0, 14)

			local candles = Instance.new("Frame")
			candles.Name = "Candles"
			candles.BackgroundColor3 = Theme.panelAlt
			candles.Position = UDim2.fromOffset(0, 54)
			candles.Size = UDim2.new(1, 0, 0, 42)
			candles.Parent = card
			Theme.corner(candles, 6)

			local shares = Theme.text(card, "Shares", "0 yarn bags", 11, Theme.muted, Theme.fontMono)
			shares.Position = UDim2.fromOffset(0, 98)
			shares.Size = UDim2.new(1, 0, 0, 14)

			local buy = Theme.button(card, "Buy", "Buy", Theme.mint)
			buy.Position = UDim2.fromOffset(0, 116)
			buy.Size = UDim2.new(0.48, 0, 0, 26)
			buy.TextSize = 13

			local sell = Theme.button(card, "Sell", "Sell", Theme.coral)
			sell.Position = UDim2.new(0.52, 0, 0, 116)
			sell.Size = UDim2.new(0.48, 0, 0, 26)
			sell.TextSize = 13

			local id = row.id
			buy.MouseButton1Click:Connect(function()
				if tradeHandler then
					tradeHandler(id, "buy")
				end
			end)
			sell.MouseButton1Click:Connect(function()
				if tradeHandler then
					tradeHandler(id, "sell")
				end
			end)

			table.insert(cards, {
				root = card,
				id = id,
				ticker = ticker,
				price = price,
				change = change,
				shares = shares,
				candles = candles,
				buy = buy,
				sell = sell,
			})
		end
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if not visible then
				recap.Visible = false
			end
		end,
		update = function(snap: Types.ArcadeSnapshot)
			ensureCards(snap.tickers)
			local signed = ArcadeCatalog.signedYarn(snap.profit)
			pnl.Text = `{signed} yarn`
			pnl.TextColor3 = if snap.profit > 0 then Theme.good elseif snap.profit < 0 then Theme.bad else Theme.amber
			event.Text = snap.eventBanner
			if snap.eventKind == "rug" or string.find(snap.eventBanner, "RUG", 1, true) then
				event.TextColor3 = Theme.coral
			elseif snap.eventKind == "moon" or string.find(snap.eventBanner, "MOON", 1, true) then
				event.TextColor3 = Theme.mint
			elseif snap.eventKind == "sneeze" then
				event.TextColor3 = Theme.amber
			else
				event.TextColor3 = Theme.foam
			end
			local clock = if snap.phase == "Playing" then `{math.ceil(snap.remaining)}s` else "settled"
			local daily = if snap.bestProfit > 0 then `  ·  daily {ArcadeCatalog.signedYarn(snap.bestProfit)}` else ""
			meta.Text = `wallet {snap.cash}  ·  mark {snap.equity}  ·  {clock}{daily}`
			toast.Text = snap.toast
			disclaimer.Text = snap.disclaimer
			if snap.dayKey ~= "" then
				title.Text = "MEME ARCADE"
				meta.Text ..= `  ·  {snap.dayKey}`
			end
			for i, card in cards do
				local row = snap.tickers[i]
				if row then
					card.ticker.Text = row.ticker
					card.price.Text = tostring(row.price)
					local arrow = if row.change > 0 then "▲" elseif row.change < 0 then "▼" else "·"
					card.change.Text = `{arrow} {ArcadeCatalog.signedYarn(row.change)}`
					card.change.TextColor3 = changeTint(row.change)
					card.shares.Text = `{row.shares} bags`
					local tint = if row.eventKind == "rug"
						then Theme.coral
						elseif row.eventKind == "moon" then Theme.mint
						elseif row.change < 0 then Theme.coral
						else Theme.mint
					paintCandles(card.candles, row.candles, tint)
					local playing = snap.phase == "Playing"
					card.buy.Active = playing
					card.sell.Active = playing
					card.buy.AutoButtonColor = playing
					card.sell.AutoButtonColor = playing
				end
			end
			local done = snap.phase == "Settled"
			recap.Visible = done
			leave.Visible = not done
			tape.Visible = true
			if done then
				recapTitle.Text = if snap.profit >= 0 then "BOOM" else "BUST"
				recapPnl.Text = `{signed} yarn`
				recapPnl.TextColor3 = if snap.profit >= 0 then Theme.good else Theme.bad
				recapMeta.Text = `wallet {snap.cash}\ndaily high {ArcadeCatalog.signedYarn(snap.bestProfit)} yarn`
			end
		end,
		onHub = function(fn)
			hubHandler = fn
		end,
		onRetry = function(fn)
			retryHandler = fn
		end,
		onTrade = function(fn)
			tradeHandler = fn
		end,
	}
end

return ArcadeHud
