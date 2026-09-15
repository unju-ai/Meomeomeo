--!strict

-- Server-authoritative yarn tape. Isolated from in-match MemeStockService wallets.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ArcadeCatalog = require(Shared:WaitForChild("ArcadeCatalog"))
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local ModeService = require(script.Parent.Parent.Mode.ModeService)
local CosmeticService = require(script.Parent.Parent.Cosmetics.CosmeticService)
local ArcadeBuilder = require(script.Parent.ArcadeBuilder)

type LiveTicker = {
	def: ArcadeCatalog.TickerDef,
	price: number,
	last: number,
	change: number,
	candles: { number },
	eventKind: string,
	eventUntil: number,
}

type Session = {
	player: Player,
	phase: Types.ArcadePhase,
	round: number,
	startYarn: number,
	cash: number,
	holdings: { [string]: number },
	tickers: { LiveTicker },
	phaseEnds: number,
	eventBanner: string,
	eventKind: string,
	eventUntil: number,
	toast: string,
	toastUntil: number,
	profit: number,
	bestProfit: number,
	dayKey: string,
	walkSpeed: number,
	sendAcc: number,
	tickAcc: number,
	ticks: number,
	rng: Random,
	charConn: RBXScriptConnection?,
}

local ArcadeService = {}

local sessions: { [number]: Session } = {}
local bound = false

local function clockNow(): number
	return os.clock()
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function shout(session: Session, text: string, kind: string, hold: number?)
	session.eventBanner = text
	session.eventKind = kind
	session.eventUntil = clockNow() + (hold or 1.6)
end

local function toast(session: Session, text: string, hold: number?)
	session.toast = text
	session.toastUntil = clockNow() + (hold or 1.1)
end

local function pricesOf(session: Session): { [string]: number }
	local map = {}
	for _, row in session.tickers do
		map[row.def.id] = row.price
	end
	return map
end

local function equityOf(session: Session): number
	return ArcadeCatalog.equity(session.cash, session.holdings, pricesOf(session))
end

local function viewsOf(session: Session): { Types.ArcadeTickerView }
	local t = clockNow()
	local out: { Types.ArcadeTickerView } = {}
	for _, row in session.tickers do
		local candles = {}
		for _, p in row.candles do
			table.insert(candles, p)
		end
		table.insert(out, {
			id = row.def.id,
			name = row.def.name,
			ticker = row.def.ticker,
			price = row.price,
			last = row.last,
			change = row.change,
			shares = session.holdings[row.def.id] or 0,
			candles = candles,
			eventKind = if t < row.eventUntil then row.eventKind else "",
		})
	end
	return out
end

local function snapshotOf(session: Session): Types.ArcadeSnapshot
	local t = clockNow()
	local remain = math.max(0, session.phaseEnds - t)
	local equity = equityOf(session)
	local profit = if session.phase == "Settled" then session.profit else ArcadeCatalog.profit(equity, session.startYarn)
	return {
		phase = session.phase,
		round = session.round,
		remaining = remain,
		startYarn = session.startYarn,
		cash = ArcadeCatalog.roundPrice(session.cash),
		equity = ArcadeCatalog.roundPrice(equity),
		profit = profit,
		bestProfit = session.bestProfit,
		tickers = viewsOf(session),
		eventBanner = if t < session.eventUntil then session.eventBanner else "",
		eventKind = if t < session.eventUntil then session.eventKind else "",
		toast = if t < session.toastUntil then session.toast else "",
		disclaimer = ArcadeCatalog.Disclaimer,
		dayKey = session.dayKey,
	}
end

local function paintWorld(session: Session)
	local rows = {}
	for _, view in viewsOf(session) do
		table.insert(rows, {
			id = view.id,
			ticker = view.ticker,
			price = view.price,
			change = view.change,
			eventKind = view.eventKind,
		})
	end
	local banner = if clockNow() < session.eventUntil then session.eventBanner else ""
	ArcadeBuilder.setTape(rows, banner)
end

local function fire(session: Session)
	paintWorld(session)
	Remotes.event("MemeArcadeUpdated"):FireClient(session.player, snapshotOf(session))
end

local function freezeCharacter(player: Player, on: boolean, walkSpeed: number?)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if on then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
	else
		humanoid.WalkSpeed = walkSpeed or 16
		humanoid.JumpPower = 50
		humanoid.AutoRotate = true
	end
end

local function place(session: Session)
	local character = session.player.Character
	if not character then
		return
	end
	local cf = ArcadeBuilder.counterCFrame()
	local ok = pcall(function()
		character:PivotTo(cf)
	end)
	if not ok then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.CFrame = cf
		end
	end
	CosmeticService.dress(session.player)
end

local function sendHome(player: Player)
	local map = Workspace:FindFirstChild(Constants.MapFolderName)
	local spawns = if map then map:FindFirstChild("Spawns") else nil
	local spawn = if spawns then spawns:FindFirstChild("Lobby") else nil
	if spawn and spawn:IsA("BasePart") then
		player.RespawnLocation = spawn
		local character = player.Character
		if character then
			pcall(function()
				character:PivotTo(spawn.CFrame + Vector3.new(0, 5, 0))
			end)
		end
	end
end

local function liquidate(session: Session)
	for _, row in session.tickers do
		local n = session.holdings[row.def.id] or 0
		session.cash += n * row.price
		session.holdings[row.def.id] = 0
	end
end

local function settle(session: Session)
	if session.phase == "Settled" then
		return
	end
	liquidate(session)
	session.phase = "Settled"
	session.phaseEnds = clockNow()
	session.profit = ArcadeCatalog.profit(session.cash, session.startYarn)
	session.bestProfit = ModeService.noteArcadeBest(session.player.UserId, session.profit)
	CosmeticService.refresh(session.player)
	shout(session, if session.profit >= 0 then "BOOM · yarn prints" else "BUST · yarn crumbs", if session.profit >= 0 then "moon" else "rug", 2.2)
	toast(session, `Settled  {ArcadeCatalog.signedYarn(session.profit)} yarn`, 2.2)
	fire(session)
end

local function driftTick(session: Session)
	if session.phase ~= "Playing" then
		return
	end
	session.ticks += 1
	for _, row in session.tickers do
		local drift = session.rng:NextNumber(-0.055, 0.055)
		row.last = row.price
		row.price = ArcadeCatalog.tickPrice(row.price, drift)
		row.change = row.price - row.last
		row.candles = ArcadeCatalog.pushCandle(row.candles, row.price)
	end
	if session.ticks % ArcadeCatalog.EventEveryTicks == 0 then
		local kind = ArcadeCatalog.rollEvent(session.rng:NextNumber())
		if kind then
			local pick = session.tickers[session.rng:NextInteger(1, #session.tickers)]
			local mag = ArcadeCatalog.eventMag(kind, session.rng:NextNumber())
			pick.last = pick.price
			pick.price = ArcadeCatalog.applyEvent(pick.price, kind, mag)
			pick.change = pick.price - pick.last
			pick.candles = ArcadeCatalog.pushCandle(pick.candles, pick.price)
			pick.eventKind = kind
			pick.eventUntil = clockNow() + 2.1
			shout(session, ArcadeCatalog.eventLabel(kind, pick.def.ticker), kind, 1.85)
		end
	end
	if clockNow() >= session.phaseEnds then
		settle(session)
	end
end

local function bind()
	if bound then
		return
	end
	bound = true
	RunService.Heartbeat:Connect(function(dt)
		for _, session in sessions do
			if session.phase == "Playing" then
				session.tickAcc += dt
				if session.tickAcc >= ArcadeCatalog.TickSeconds then
					session.tickAcc = 0
					driftTick(session)
				end
			end
			session.sendAcc += dt
			if session.sendAcc >= 0.12 then
				session.sendAcc = 0
				fire(session)
			end
		end
	end)
end

function ArcadeService.playingCount(): number
	local n = 0
	for _ in sessions do
		n += 1
	end
	return n
end

function ArcadeService.isPlaying(player: Player): boolean
	return sessions[player.UserId] ~= nil
end

function ArcadeService.snapshot(player: Player): Types.ArcadeSnapshot?
	local session = sessions[player.UserId]
	if not session then
		return nil
	end
	return snapshotOf(session)
end

function ArcadeService.start(player: Player): Types.TradeResult
	if ModeService.busyMatch() then
		return { ok = false, error = "Cat Rift is live on this server — try the arcade after." }
	end
	if ModeService.is(player, "Moba") then
		return { ok = false, error = "Leave the Rift first." }
	end
	if ModeService.is(player, "YarnRun") then
		return { ok = false, error = "Leave Yarn Run first." }
	end
	if ModeService.is(player, "KoiPond") then
		return { ok = false, error = "Leave the pond first." }
	end
	if ModeService.is(player, "YarnParty") then
		return { ok = false, error = "Leave Yarn Party first." }
	end
	if sessions[player.UserId] then
		return { ok = false, error = "Already at the arcade." }
	end

	ArcadeBuilder.ensure()
	local unix = now()
	local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
	local rng = Random.new(ArcadeCatalog.dailySeed(unix) + player.UserId + math.floor(unix * 10) % 97)
	local tickers: { LiveTicker } = {}
	local holdings: { [string]: number } = {}
	for _, def in ArcadeCatalog.all() do
		local price = ArcadeCatalog.roundPrice(def.basePrice + rng:NextNumber(-1.4, 1.8))
		holdings[def.id] = 0
		table.insert(tickers, {
			def = def,
			price = price,
			last = price,
			change = 0,
			candles = { price },
			eventKind = "",
			eventUntil = 0,
		})
	end
	local session: Session = {
		player = player,
		phase = "Playing",
		round = 1,
		startYarn = ArcadeCatalog.StartYarn,
		cash = ArcadeCatalog.StartYarn,
		holdings = holdings,
		tickers = tickers,
		phaseEnds = clockNow() + ArcadeCatalog.RoundSeconds,
		eventBanner = "TAPE'S LIVE · tap a loaf",
		eventKind = "",
		eventUntil = clockNow() + 1.5,
		toast = "",
		toastUntil = 0,
		profit = 0,
		bestProfit = ModeService.arcadeBestOf(player.UserId),
		dayKey = ArcadeCatalog.dayKey(unix),
		walkSpeed = if humanoid then humanoid.WalkSpeed else 16,
		sendAcc = 1,
		tickAcc = 0,
		ticks = 0,
		rng = rng,
		charConn = nil,
	}
	sessions[player.UserId] = session
	ModeService.set(player, "MemeArcade")
	freezeCharacter(player, true, session.walkSpeed)
	place(session)
	session.charConn = player.CharacterAdded:Connect(function()
		task.defer(function()
			if sessions[player.UserId] ~= session then
				return
			end
			freezeCharacter(player, true, session.walkSpeed)
			place(session)
		end)
	end)
	bind()
	fire(session)
	return { ok = true }
end

function ArcadeService.input(player: Player, payload: unknown): Types.TradeResult
	local session = sessions[player.UserId]
	if not session then
		return { ok = false, error = "Not at the arcade." }
	end
	if session.phase ~= "Playing" then
		return { ok = false, error = "Round's over — play again." }
	end
	if typeof(payload) ~= "table" then
		return { ok = false, error = "Bad input." }
	end
	local body = payload :: Types.ArcadeInput
	if typeof(body.tickerId) ~= "string" then
		return { ok = false, error = "Unknown ticker." }
	end
	if body.action ~= "buy" and body.action ~= "sell" then
		return { ok = false, error = "Unknown tape action." }
	end
	local live: LiveTicker? = nil
	for _, row in session.tickers do
		if row.def.id == body.tickerId then
			live = row
			break
		end
	end
	if not live then
		return { ok = false, error = "Unknown ticker." }
	end
	local shares = session.holdings[live.def.id] or 0
	if body.action == "buy" then
		if not ArcadeCatalog.canBuy(session.cash, live.price, shares) then
			toast(session, "Not enough yarn", 0.9)
			fire(session)
			return { ok = false, error = "Not enough yarn." }
		end
		local nextCash, nextShares = ArcadeCatalog.afterBuy(session.cash, shares, live.price)
		session.cash = nextCash
		session.holdings[live.def.id] = nextShares
		toast(session, `BUY {live.def.ticker}  {live.price}`, 0.7)
	else
		if not ArcadeCatalog.canSell(shares) then
			toast(session, "No shares", 0.9)
			fire(session)
			return { ok = false, error = "No shares to sell." }
		end
		local nextCash, nextShares = ArcadeCatalog.afterSell(session.cash, shares, live.price)
		session.cash = nextCash
		session.holdings[live.def.id] = nextShares
		toast(session, `SELL {live.def.ticker}  {live.price}`, 0.7)
	end
	fire(session)
	return { ok = true }
end

function ArcadeService.leave(player: Player): Types.TradeResult
	local session = sessions[player.UserId]
	if session then
		if session.phase == "Playing" then
			settle(session)
		end
		freezeCharacter(player, false, session.walkSpeed)
		if session.charConn then
			session.charConn:Disconnect()
		end
	end
	sessions[player.UserId] = nil
	ModeService.set(player, "Hub")
	sendHome(player)
	return { ok = true }
end

function ArcadeService.retry(player: Player): Types.TradeResult
	ArcadeService.leave(player)
	return ArcadeService.start(player)
end

function ArcadeService.clear(userId: number)
	local session = sessions[userId]
	if session and session.charConn then
		session.charConn:Disconnect()
	end
	sessions[userId] = nil
end

return ArcadeService
