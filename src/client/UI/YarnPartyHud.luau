--!strict

-- Stream party chrome: giant round titles, seat board, elim plate, crown card.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Theme)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local YarnPartyCatalog = require(Shared:WaitForChild("YarnPartyCatalog"))

local YarnPartyHud = {}

export type PartyHudApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (snap: Types.YarnPartySnapshot, localUserId: number) -> (),
	onHub: (() -> ()) -> (),
	onRetry: (() -> ()) -> (),
}

function YarnPartyHud.create(parent: Instance): PartyHudApi
	local root = Instance.new("Frame")
	root.Name = "YarnPartyHud"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = parent

	local title = Theme.text(root, "Title", "YARN PARTY", 56, Theme.amber, Theme.fontTitle)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 58)
	title.Size = UDim2.fromOffset(720, 62)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextStrokeTransparency = 0.18
	title.ZIndex = 2

	local sub = Theme.text(root, "Sub", "", 16, Theme.peach, Theme.fontMono)
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.new(0.5, 0, 0, 118)
	sub.Size = UDim2.fromOffset(620, 20)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.ZIndex = 2

	local rule = Theme.text(root, "Rule", "", 18, Theme.cream, Theme.fontTitle)
	rule.AnchorPoint = Vector2.new(0.5, 0)
	rule.Position = UDim2.new(0.5, 0, 0, 140)
	rule.Size = UDim2.fromOffset(640, 24)
	rule.TextXAlignment = Enum.TextXAlignment.Center
	rule.TextStrokeTransparency = 0.28
	rule.ZIndex = 2

	local eventPlate = Instance.new("Frame")
	eventPlate.Name = "EventPlate"
	eventPlate.AnchorPoint = Vector2.new(0.5, 0)
	eventPlate.Position = UDim2.new(0.5, 0, 0, 168)
	eventPlate.Size = UDim2.fromOffset(680, 52)
	eventPlate.BackgroundColor3 = Theme.coral
	eventPlate.BackgroundTransparency = 1
	eventPlate.BorderSizePixel = 0
	eventPlate.ZIndex = 3
	eventPlate.Parent = root
	Theme.corner(eventPlate, 14)
	local eventStroke = Theme.stroke(eventPlate, Theme.foam, 3, 1)

	local event = Theme.text(eventPlate, "Event", "", 34, Theme.foam, Theme.fontTitle)
	event.Size = UDim2.fromScale(1, 1)
	event.TextXAlignment = Enum.TextXAlignment.Center
	event.TextStrokeTransparency = 0.16
	event.ZIndex = 4

	local hint = Theme.text(root, "Hint", "WASD move  ·  Space hop the yarn  ·  lit pillow = safe", 13, Theme.peach)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -18)
	hint.Size = UDim2.fromOffset(620, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Center

	local board = Instance.new("Frame")
	board.Name = "Seats"
	board.AnchorPoint = Vector2.new(0, 0)
	board.Position = UDim2.fromOffset(16, 148)
	board.Size = UDim2.fromOffset(300, 188)
	board.BackgroundColor3 = Theme.panel
	board.ZIndex = 2
	board.Parent = root
	Theme.corner(board, 14)
	Theme.stroke(board, Theme.peach, 2, 0.22)
	Theme.pad(board, 10)

	local boardTitle = Theme.text(board, "Title", "Seats 1–4", 18, Theme.amber, Theme.fontTitle)
	boardTitle.Size = UDim2.new(1, 0, 0, 22)
	boardTitle.ZIndex = 3

	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(0, 26)
	rows.Size = UDim2.new(1, 0, 1, -26)
	rows.ZIndex = 3
	rows.Parent = board
	Theme.list(rows, 5)

	local crown = Instance.new("Frame")
	crown.Name = "Crown"
	crown.AnchorPoint = Vector2.new(0.5, 0.5)
	crown.Position = UDim2.fromScale(0.5, 0.56)
	crown.Size = UDim2.fromOffset(440, 310)
	crown.BackgroundColor3 = Theme.panel
	crown.Visible = false
	crown.ZIndex = 8
	crown.Parent = root
	Theme.corner(crown, 20)
	local crownStroke = Theme.stroke(crown, Theme.amber, 4, 0.08)
	Theme.pad(crown, 18)

	local crownTitle = Theme.text(crown, "Title", "CROWNED", 34, Theme.amber, Theme.fontTitle)
	crownTitle.Size = UDim2.new(1, 0, 0, 36)
	crownTitle.TextXAlignment = Enum.TextXAlignment.Center
	crownTitle.TextStrokeTransparency = 0.2
	crownTitle.ZIndex = 9

	local crownName = Theme.text(crown, "Name", "", 26, Theme.ink, Theme.fontTitle)
	crownName.Position = UDim2.fromOffset(0, 42)
	crownName.Size = UDim2.new(1, 0, 0, 40)
	crownName.TextXAlignment = Enum.TextXAlignment.Center
	crownName.BackgroundColor3 = Theme.amber
	crownName.BackgroundTransparency = 0.08
	crownName.TextStrokeTransparency = 0.45
	crownName.ZIndex = 9
	Theme.corner(crownName, 12)
	Theme.stroke(crownName, Theme.foam, 2, 0.25)

	local crownRecap = Theme.text(crown, "Recap", "", 15, Theme.cream, Theme.fontMono)
	crownRecap.Position = UDim2.fromOffset(0, 92)
	crownRecap.Size = UDim2.new(1, 0, 0, 88)
	crownRecap.TextXAlignment = Enum.TextXAlignment.Center
	crownRecap.ZIndex = 9

	local retry = Theme.button(crown, "Retry", "Party again", Theme.amber)
	retry.Position = UDim2.new(0, 0, 1, -92)
	retry.Size = UDim2.new(1, 0, 0, 40)
	retry.ZIndex = 9
	Theme.stroke(retry, Theme.foam, 2, 0.2)

	local hub = Theme.button(crown, "Hub", "Back to hub", Theme.peach)
	hub.Position = UDim2.new(0, 0, 1, -44)
	hub.Size = UDim2.new(1, 0, 0, 38)
	hub.ZIndex = 9

	local leave = Theme.button(root, "Leave", "Back to hub", Theme.peach)
	leave.AnchorPoint = Vector2.new(1, 1)
	leave.Position = UDim2.new(1, -18, 1, -18)
	leave.Size = UDim2.fromOffset(150, 36)

	local hubHandler: (() -> ())? = nil
	local retryHandler: (() -> ())? = nil
	local lastEvent = ""
	local lastTitle = ""
	local lastLobbySecs = -1

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

	local function roleOf(seat: Types.YarnPartySeat, localUserId: number): string
		local open = seat.id == 0 or seat.name == "Open"
		return YarnPartyCatalog.seatRole(seat.id == localUserId, seat.isBot, open)
	end

	local function pulseTitle()
		title.TextSize = 64
		TweenService:Create(title, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			TextSize = 56,
		}):Play()
	end

	local function pulseEvent(color: Color3, hot: boolean)
		event.TextColor3 = if hot then Theme.foam else color
		eventPlate.BackgroundColor3 = color
		eventPlate.BackgroundTransparency = if hot then 0.12 else 0.55
		eventStroke.Color = if hot then Theme.foam else color
		eventStroke.Transparency = if hot then 0.05 else 0.35
		event.TextSize = if hot then 42 else 36
		eventPlate.Size = if hot then UDim2.fromOffset(720, 58) else UDim2.fromOffset(680, 52)
		TweenService:Create(event, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			TextSize = if hot then 36 else 34,
		}):Play()
		TweenService:Create(eventPlate, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = if hot then 0.28 else 0.72,
			Size = UDim2.fromOffset(680, 52),
		}):Play()
		TweenService:Create(eventStroke, TweenInfo.new(0.55), {
			Transparency = if hot then 0.2 else 0.55,
		}):Play()
	end

	local function paintSeats(seats: { Types.YarnPartySeat }, localUserId: number, lobby: boolean)
		for _, child in rows:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local ordered = table.clone(seats)
		if lobby then
			table.sort(ordered, function(a, b)
				return a.seat < b.seat
			end)
		end
		for i, seat in ordered do
			local role = roleOf(seat, localUserId)
			local tint = Theme.cream
			local lineText: string
			local bg = Theme.panelAlt
			local bgAlpha = 0.55
			if lobby then
				lineText = YarnPartyCatalog.seatLine(seat.seat, role, seat.name)
				if role == "YOU" then
					tint = Theme.ink
					bg = Theme.amber
					bgAlpha = 0.08
				elseif role == "BOT" then
					tint = Theme.peach
					bg = Theme.panelAlt
					bgAlpha = 0.35
				elseif role == "OPEN" then
					tint = Theme.muted
					bgAlpha = 0.7
				else
					tint = Theme.cream
					bg = Theme.mint
					bgAlpha = 0.72
				end
			else
				local tag = if seat.alive then "IN" else "OUT"
				lineText = `#{i}  {seat.score}  {seat.name}  {tag}  [{role}]`
				tint = if seat.alive then Theme.cream else Theme.muted
				if i == 1 and seat.alive then
					tint = Theme.ink
					bg = Theme.amber
					bgAlpha = 0.1
				elseif not seat.alive then
					bgAlpha = 0.75
				end
			end
			local line = Theme.text(rows, "S" .. i, lineText, 14, tint, Theme.fontMono)
			line.Size = UDim2.new(1, 0, 0, 24)
			line.TextTruncate = Enum.TextTruncate.AtEnd
			line.LayoutOrder = i
			line.BackgroundColor3 = bg
			line.BackgroundTransparency = bgAlpha
			line.ZIndex = 4
			Theme.corner(line, 8)
		end
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if not visible then
				crown.Visible = false
				lastEvent = ""
				lastTitle = ""
				lastLobbySecs = -1
			end
		end,
		update = function(snap: Types.YarnPartySnapshot, localUserId: number)
			local cats = 0
			local bots = 0
			for _, seat in snap.seats do
				if seat.isBot then
					bots += 1
				elseif seat.id ~= 0 and seat.name ~= "Open" then
					cats += 1
				end
			end
			local nextTitle = ""
			if snap.phase == "Lobby" then
				local secs = math.max(0, math.ceil(snap.countdown))
				nextTitle = YarnPartyCatalog.lobbyTitle(secs)
				title.Text = nextTitle
				sub.Text = `YARN PARTY  ·  {cats} cats  ·  {bots} bots`
				rule.Text = "Friends can still hop a bot seat"
				rule.TextColor3 = Theme.amber
				boardTitle.Text = "Seats 1–4"
				if secs ~= lastLobbySecs then
					pulseTitle()
					lastLobbySecs = secs
				end
			elseif snap.phase == "Podium" then
				nextTitle = "CROWNED"
				title.Text = nextTitle
				sub.Text = YarnPartyCatalog.podiumWinnerLine(snap.winnerName or "Loaf")
				rule.Text = "Party again  ·  or Back to hub"
				rule.TextColor3 = Theme.peach
				boardTitle.Text = "Score"
			else
				nextTitle = snap.roundTitle
				title.Text = nextTitle
				sub.Text = `Round {snap.roundIndex}/{snap.roundCount}  ·  {math.ceil(snap.countdown)}s`
				rule.Text = YarnPartyCatalog.ruleBanner(snap.roundKind)
				rule.TextColor3 = if snap.roundKind == "Dodge" then Theme.coral else Theme.mint
				boardTitle.Text = "Score"
			end
			if nextTitle ~= "" and nextTitle ~= lastTitle and snap.phase ~= "Lobby" then
				pulseTitle()
			end
			lastTitle = nextTitle

			local eventText = snap.event or ""
			event.Text = eventText
			local elimHot = YarnPartyCatalog.isElimPop(snap.event)
			local roundHot = YarnPartyCatalog.isRoundTitle(snap.event)
			if snap.event and snap.event ~= lastEvent then
				if string.find(snap.event, "CROWNED", 1, true) then
					pulseEvent(Theme.amber, true)
				elseif elimHot then
					pulseEvent(Theme.coral, true)
				elseif roundHot or snap.event == "GO" then
					pulseEvent(if snap.event == "STALL FREEZE" then Theme.mint else Theme.coral, true)
				elseif string.find(snap.event, "took seat", 1, true) then
					pulseEvent(Theme.amber, false)
				else
					pulseEvent(Theme.foam, false)
				end
			elseif eventText == "" then
				eventPlate.BackgroundTransparency = 1
				eventStroke.Transparency = 1
			end
			lastEvent = eventText

			if snap.phase == "Lobby" then
				hint.Text = "Seats 1–4  ·  a friend takes a bot seat  ·  mid-round waits"
				if not snap.event then
					event.Text = "Friends can still hop in"
					event.TextColor3 = Theme.amber
					eventPlate.BackgroundColor3 = Theme.amber
					eventPlate.BackgroundTransparency = 0.78
					eventStroke.Transparency = 0.55
				end
			else
				hint.Text = if snap.roundKind == "Dodge"
					then "WASD  ·  Space hop the coral yarn"
					else "WASD onto a lit pillow when lanterns blink"
			end
			paintSeats(snap.seats, localUserId, snap.phase == "Lobby")
			local done = snap.phase == "Podium"
			crown.Visible = done
			leave.Visible = not done
			if done then
				crownName.Text = YarnPartyCatalog.podiumWinnerLine(snap.winnerName or "Loaf")
				crownStroke.Transparency = 0.05
				local lines = {}
				for i, seat in snap.seats do
					table.insert(lines, YarnPartyCatalog.podiumRecapLine(i, seat.name, seat.score, seat.isBot))
				end
				crownRecap.Text = table.concat(lines, "\n")
			end
		end,
		onHub = function(fn)
			hubHandler = fn
		end,
		onRetry = function(fn)
			retryHandler = fn
		end,
	}
end

return YarnPartyHud
