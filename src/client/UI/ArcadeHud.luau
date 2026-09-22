--!strict

-- Stall tape HUD: giant PnL, neon candles, yarn-only disclaimer. Not a trading app.

local TweenService = game:GetService("TweenService")

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
	onBoard: (() -> ()) -> (),
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

local function eventTint(kind: string, banner: string): Color3
	if kind == "rug" or string.find(banner, "RUG", 1, true) or string.find(banner, "BUST", 1, true) then
		return Theme.coral
	elseif kind == "moon" or string.find(banner, "MOON", 1, true) or string.find(banner, "BOOM", 1, true) then
		return Theme.mint
	elseif kind == "sneeze" or string.find(banner, "WHALE", 1, true) then
		return Theme.amber
	end
	return Theme.foam
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

	local eventPlate = Instance.new("Frame")
	eventPlate.Name = "EventPlate"
	eventPlate.AnchorPoint = Vector2.new(0.5, 0)
	eventPlate.Position = UDim2.new(0.5, 0, 0, 164)
	eventPlate.Size = UDim2.fromOffset(720, 48)
	eventPlate.BackgroundColor3 = Theme.coral
	eventPlate.BackgroundTransparency = 1
	eventPlate.BorderSizePixel = 0
	eventPlate.ZIndex = 2
	eventPlate.Parent = root
	Theme.corner(eventPlate, 12)
	Theme.stroke(eventPlate, Theme.foam, 2, 1)

	local event = Theme.text(eventPlate, "Event", "", 36, Theme.foam, Theme.fontTitle)
	event.Size = UDim2.fromScale(1, 1)
	event.TextXAlignment = Enum.TextXAlignment.Center
	event.TextStrokeTransparency = 0.18
	event.ZIndex = 3

	local meta = Theme.text(root, "Meta", "yarn 100  ·  28s", 14, Theme.cream, Theme.fontMono)
	meta.AnchorPoint = Vector2.new(0.5, 0)
	meta.Position = UDim2.new(0.5, 0, 0, 218)
	meta.Size = UDim2.fromOffset(560, 18)
	meta.TextXAlignment = Enum.TextXAlignment.Center

	local toast = Theme.text(root, "Toast", "", 22, Theme.peach, Theme.fontTitle)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 236)
	toast.Size = UDim2.fromOffset(560, 26)
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.TextStrokeTransparency = 0.28
	toast.ZIndex = 3

	local tape = Instance.new("Frame")
	tape.Name = "Tape"
	tape.AnchorPoint = Vector2.new(0.5, 1)
	tape.Position = UDim2.new(0.5, 0, 1, -92)
	tape.Size = UDim2.fromOffset(760, 210)
	tape.BackgroundTransparency = 1
	tape.Parent = root
	Theme.list(tape, 8, Enum.FillDirection.Horizontal)

	local disclaimer = Theme.text(root, "Disclaimer", ArcadeCatalog.Disclaimer, 13, Theme.peach, Theme.fontMono)
	disclaimer.AnchorPoint = Vector2.new(0.5, 1)
	disclaimer.Position = UDim2.new(0.5, 0, 1, -58)
	disclaimer.Size = UDim2.fromOffset(680, 18)
	disclaimer.TextXAlignment = Enum.TextXAlignment.Center
	disclaimer.TextStrokeTransparency = 0.45
	disclaimer.ZIndex = 4

	local hint = Theme.text(root, "Hint", "1–5 buy  ·  Shift+1–5 sell  ·  tap the stall tape", 13, Theme.peach)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -18)
	hint.Size = UDim2.fromOffset(620, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Center

	local recap = Instance.new("Frame")
	recap.Name = "Recap"
	recap.AnchorPoint = Vector2.new(0.5, 0.5)
	recap.Position = UDim2.fromScale(0.5, 0.52)
	recap.Size = UDim2.fromOffset(420, 300)
	recap.BackgroundColor3 = Theme.panel
	recap.Visible = false
	recap.ZIndex = 8
	recap.Parent = root
	Theme.corner(recap, 20)
	Theme.stroke(recap, Theme.amber, 3, 0.12)
	Theme.pad(recap, 18)

	local recapTitle = Theme.text(recap, "Title", "TAPE SETTLED", 28, Theme.amber, Theme.fontTitle)
	recapTitle.Size = UDim2.new(1, 0, 0, 32)
	recapTitle.TextXAlignment = Enum.TextXAlignment.Center
	recapTitle.ZIndex = 9

	local recapPnl = Theme.text(recap, "Pnl", "+0 yarn", 30, Theme.good, Theme.fontTitle)
	recapPnl.Position = UDim2.fromOffset(0, 38)
	recapPnl.Size = UDim2.new(1, 0, 0, 34)
	recapPnl.TextXAlignment = Enum.TextXAlignment.Center
	recapPnl.ZIndex = 9

	local recapScore = Theme.text(recap, "Score", "", 15, Theme.cream, Theme.fontMono)
	recapScore.Position = UDim2.fromOffset(0, 76)
	recapScore.Size = UDim2.new(1, 0, 0, 22)
	recapScore.TextXAlignment = Enum.TextXAlignment.Center
	recapScore.BackgroundColor3 = Theme.panelAlt
	recapScore.BackgroundTransparency = 0.35
	recapScore.ZIndex = 9
	Theme.corner(recapScore, 8)

	local recapRank = Theme.text(recap, "Rank", "", 18, Theme.amber, Theme.fontTitle)
	recapRank.Position = UDim2.fromOffset(0, 106)
	recapRank.Size = UDim2.new(1, 0, 0, 30)
	recapRank.TextXAlignment = Enum.TextXAlignment.Center
	recapRank.BackgroundColor3 = Theme.amber
	recapRank.BackgroundTransparency = 0.82
	recapRank.ZIndex = 9
	Theme.corner(recapRank, 10)
	Theme.stroke(recapRank, Theme.amber, 2, 0.35)

	local recapDisc = Theme.text(recap, "Disc", ArcadeCatalog.Disclaimer, 12, Theme.peach, Theme.fontMono)
	recapDisc.Position = UDim2.fromOffset(0, 144)
	recapDisc.Size = UDim2.new(1, 0, 0, 28)
	recapDisc.TextXAlignment = Enum.TextXAlignment.Center
	recapDisc.ZIndex = 9

	local retry = Theme.button(recap, "Retry", "Play again", Theme.amber)
	retry.Position = UDim2.new(0, 0, 1, -88)
	retry.Size = UDim2.new(1, 0, 0, 38)
	retry.ZIndex = 9

	local hub = Theme.button(recap, "Hub", "Back to hub", Theme.peach)
	hub.Position = UDim2.new(0, 0, 1, -42)
	hub.Size = UDim2.new(0.48, 0, 0, 36)
	hub.ZIndex = 9

	local recapBoard = Theme.button(recap, "Board", "Board", Theme.amber)
	recapBoard.Position = UDim2.new(0.52, 0, 1, -42)
	recapBoard.Size = UDim2.new(0.48, 0, 0, 36)
	recapBoard.ZIndex = 9

	local leave = Theme.button(root, "Leave", "Back to hub", Theme.peach)
	leave.AnchorPoint = Vector2.new(1, 1)
	leave.Position = UDim2.new(1, -18, 1, -18)
	leave.Size = UDim2.fromOffset(150, 36)

	local playBoard = Theme.button(root, "PlayBoard", "Board", Theme.amber)
	playBoard.AnchorPoint = Vector2.new(1, 1)
	playBoard.Position = UDim2.new(1, -178, 1, -18)
	playBoard.Size = UDim2.fromOffset(110, 36)

	local hubHandler: (() -> ())? = nil
	local retryHandler: (() -> ())? = nil
	local boardHandler: (() -> ())? = nil
	local tradeHandler: ((string, "buy" | "sell") -> ())? = nil
	local lastEvent = ""
	local lastToast = ""
	local lastTradeKey = ""

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
	recapBoard.MouseButton1Click:Connect(function()
		if boardHandler then
			boardHandler()
		end
	end)
	playBoard.MouseButton1Click:Connect(function()
		if boardHandler then
			boardHandler()
		end
	end)

	local cards: {
		{
			root: Frame,
			id: string,
			stroke: UIStroke,
			ticker: TextLabel,
			price: TextLabel,
			change: TextLabel,
			shares: TextLabel,
			candles: Frame,
			buy: TextButton,
			sell: TextButton,
			lastEventKind: string,
		}
	} =
		{}

	local function pulseCard(card: {
		root: Frame,
		stroke: UIStroke,
		buy: TextButton,
		sell: TextButton,
	}, color: Color3)
		card.stroke.Color = color
		card.stroke.Thickness = 5
		card.stroke.Transparency = 0
		card.root.BackgroundColor3 = color:Lerp(Theme.panel, 0.72)
		TweenService:Create(card.stroke, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = 2,
			Transparency = 0.28,
		}):Play()
		TweenService:Create(card.root, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = Theme.panel,
		}):Play()
	end

	local function pulseToast(color: Color3)
		toast.TextColor3 = color
		toast.TextSize = 28
		TweenService:Create(toast, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			TextSize = 22,
		}):Play()
	end

	local function shoutEvent(banner: string, kind: string)
		local tint = eventTint(kind, banner)
		event.Text = banner
		event.TextColor3 = Theme.ink
		eventPlate.BackgroundColor3 = tint
		eventPlate.BackgroundTransparency = 0.12
		local stroke = eventPlate:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Theme.foam
			stroke.Transparency = 0.05
			stroke.Thickness = 3
		end
		event.TextSize = 44
		TweenService:Create(event, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			TextSize = 36,
		}):Play()
		TweenService:Create(eventPlate, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.28,
		}):Play()
	end

	local function clearEventPlate()
		event.Text = ""
		eventPlate.BackgroundTransparency = 1
		local stroke = eventPlate:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 1
		end
	end

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
			local h = 0.3 + 0.68 * ((v - lo) / span)
			local bar = Instance.new("Frame")
			bar.Name = "C" .. i
			bar.AnchorPoint = Vector2.new(0, 1)
			bar.Position = UDim2.new((i - 1) / ArcadeCatalog.CandleCount, 2, 1, -2)
			bar.Size = UDim2.new(1 / ArcadeCatalog.CandleCount, -4, h, 0)
			bar.BackgroundColor3 = tint
			bar.BorderSizePixel = 0
			bar.Parent = host
			Theme.corner(bar, 3)
			Theme.stroke(bar, Theme.foam, 1, 0.55)
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
			card.Size = UDim2.new(0, 140, 1, 0)
			card.BackgroundColor3 = Theme.panel
			card.LayoutOrder = i
			card.Parent = tape
			Theme.corner(card, 12)
			local stroke = Theme.stroke(card, Theme.peach, 2, 0.28)
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
			candles.BackgroundColor3 = Color3.fromRGB(28, 18, 16)
			candles.Position = UDim2.fromOffset(0, 54)
			candles.Size = UDim2.new(1, 0, 0, 52)
			candles.Parent = card
			Theme.corner(candles, 6)
			Theme.stroke(candles, Theme.ink, 1, 0.4)

			local shares = Theme.text(card, "Shares", "0 yarn bags", 11, Theme.muted, Theme.fontMono)
			shares.Position = UDim2.fromOffset(0, 110)
			shares.Size = UDim2.new(1, 0, 0, 14)

			local buy = Theme.button(card, "Buy", "Buy", Theme.mint)
			buy.Position = UDim2.fromOffset(0, 128)
			buy.Size = UDim2.new(0.48, 0, 0, 28)
			buy.TextSize = 13

			local sell = Theme.button(card, "Sell", "Sell", Theme.coral)
			sell.Position = UDim2.new(0.52, 0, 0, 128)
			sell.Size = UDim2.new(0.48, 0, 0, 28)
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
				stroke = stroke,
				ticker = ticker,
				price = price,
				change = change,
				shares = shares,
				candles = candles,
				buy = buy,
				sell = sell,
				lastEventKind = "",
			})
		end
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if not visible then
				recap.Visible = false
				clearEventPlate()
				lastEvent = ""
				lastToast = ""
				lastTradeKey = ""
			end
		end,
		update = function(snap: Types.ArcadeSnapshot)
			ensureCards(snap.tickers)
			local signed = ArcadeCatalog.signedYarn(snap.profit)
			pnl.Text = `{signed} yarn`
			pnl.TextColor3 = if snap.profit > 0 then Theme.good elseif snap.profit < 0 then Theme.bad else Theme.amber

			if snap.eventBanner ~= "" then
				if snap.eventBanner ~= lastEvent then
					shoutEvent(snap.eventBanner, snap.eventKind)
				else
					event.Text = snap.eventBanner
					event.TextColor3 = Theme.ink
					eventPlate.BackgroundColor3 = eventTint(snap.eventKind, snap.eventBanner)
					eventPlate.BackgroundTransparency = math.min(eventPlate.BackgroundTransparency, 0.32)
				end
			else
				clearEventPlate()
			end
			lastEvent = snap.eventBanner

			local clock = if snap.phase == "Playing" then `{math.ceil(snap.remaining)}s` else "settled"
			local daily = if snap.bestProfit ~= 0 then `  ·  daily {ArcadeCatalog.signedYarn(snap.bestProfit)}` else ""
			meta.Text = `wallet {snap.cash}  ·  mark {snap.equity}  ·  {clock}{daily}`
			toast.Text = snap.toast
			if snap.toast ~= "" and snap.toast ~= lastToast then
				if string.find(snap.toast, "BOUGHT", 1, true) then
					pulseToast(Theme.mint)
				elseif string.find(snap.toast, "SOLD", 1, true) then
					pulseToast(Theme.coral)
				elseif string.find(snap.toast, "Settled", 1, true) then
					pulseToast(if snap.profit >= 0 then Theme.mint else Theme.coral)
				else
					pulseToast(Theme.peach)
				end
			end
			lastToast = snap.toast
			disclaimer.Text = snap.disclaimer
			disclaimer.TextColor3 = if snap.eventBanner ~= "" then Theme.cream else Theme.peach
			if snap.dayKey ~= "" then
				title.Text = "MEME ARCADE"
				meta.Text ..= `  ·  {snap.dayKey}`
			end

			local tradeKey = if snap.tradeFlashId ~= "" then `{snap.tradeFlashId}:{snap.tradeAction}` else ""
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
						elseif row.eventKind == "sneeze" then Theme.amber
						elseif row.change < 0 then Theme.coral
						else Theme.mint
					paintCandles(card.candles, row.candles, tint)
					local playing = snap.phase == "Playing"
					card.buy.Active = playing
					card.sell.Active = playing
					card.buy.AutoButtonColor = playing
					card.sell.AutoButtonColor = playing

					if row.eventKind ~= "" and row.eventKind ~= card.lastEventKind then
						pulseCard(card, tint)
					end
					card.lastEventKind = row.eventKind

					if tradeKey ~= "" and tradeKey ~= lastTradeKey and card.id == snap.tradeFlashId then
						local tradeColor = if snap.tradeAction == "buy" then Theme.mint else Theme.coral
						pulseCard(card, tradeColor)
						local btn = if snap.tradeAction == "buy" then card.buy else card.sell
						btn.TextSize = 16
						TweenService:Create(btn, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
							TextSize = 13,
						}):Play()
					end
				end
			end
			if tradeKey ~= "" then
				lastTradeKey = tradeKey
			elseif snap.tradeFlashId == "" then
				lastTradeKey = ""
			end

			local done = snap.phase == "Settled"
			recap.Visible = done
			leave.Visible = not done
			playBoard.Visible = not done
			tape.Visible = true
			if done then
				local boom = snap.profit >= 0
				recapTitle.Text = if boom then "BOOM" else "BUST"
				recapTitle.TextColor3 = if boom then Theme.mint else Theme.coral
				recapPnl.Text = `{signed} yarn`
				recapPnl.TextColor3 = if boom then Theme.good else Theme.bad
				recapScore.Text = ArcadeCatalog.settleScoreLine(snap.profit, snap.cash)
				recapRank.Text = ArcadeCatalog.settleRankLine(snap.dailyRank, snap.bestProfit)
				if snap.dailyRank then
					recapRank.TextColor3 = Theme.ink
					recapRank.BackgroundColor3 = Theme.amber
					recapRank.BackgroundTransparency = 0.12
				else
					recapRank.TextColor3 = Theme.cream
					recapRank.BackgroundColor3 = Theme.panelAlt
					recapRank.BackgroundTransparency = 0.45
				end
				recapDisc.Text = snap.disclaimer
			end
		end,
		onHub = function(fn)
			hubHandler = fn
		end,
		onRetry = function(fn)
			retryHandler = fn
		end,
		onBoard = function(fn)
			boardHandler = fn
		end,
		onTrade = function(fn)
			tradeHandler = fn
		end,
	}
end

return ArcadeHud
