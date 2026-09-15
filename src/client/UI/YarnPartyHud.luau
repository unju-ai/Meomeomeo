--!strict

-- Stream party chrome: giant round titles, seat board, crown card.

local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

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

	local title = Theme.text(root, "Title", "YARN PARTY", 48, Theme.amber, Theme.fontTitle)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 68)
	title.Size = UDim2.fromOffset(640, 54)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextStrokeTransparency = 0.28

	local sub = Theme.text(root, "Sub", "", 16, Theme.peach, Theme.fontMono)
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.new(0.5, 0, 0, 122)
	sub.Size = UDim2.fromOffset(560, 20)
	sub.TextXAlignment = Enum.TextXAlignment.Center

	local event = Theme.text(root, "Event", "", 32, Theme.foam, Theme.fontTitle)
	event.AnchorPoint = Vector2.new(0.5, 0)
	event.Position = UDim2.new(0.5, 0, 0, 148)
	event.Size = UDim2.fromOffset(640, 36)
	event.TextXAlignment = Enum.TextXAlignment.Center
	event.TextStrokeTransparency = 0.3

	local hint = Theme.text(root, "Hint", "WASD move  ·  Space hop the yarn  ·  lit pillow = safe", 13, Theme.peach)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -18)
	hint.Size = UDim2.fromOffset(620, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Center

	local board = Instance.new("Frame")
	board.Name = "Seats"
	board.AnchorPoint = Vector2.new(0, 0)
	board.Position = UDim2.fromOffset(16, 148)
	board.Size = UDim2.fromOffset(240, 220)
	board.BackgroundColor3 = Theme.panel
	board.Parent = root
	Theme.corner(board, 14)
	Theme.stroke(board, Theme.peach, 2, 0.3)
	Theme.pad(board, 10)

	local boardTitle = Theme.text(board, "Title", "Score", 16, Theme.amber, Theme.fontTitle)
	boardTitle.Size = UDim2.new(1, 0, 0, 20)

	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(0, 24)
	rows.Size = UDim2.new(1, 0, 1, -24)
	rows.Parent = board
	Theme.list(rows, 4)

	local crown = Instance.new("Frame")
	crown.Name = "Crown"
	crown.AnchorPoint = Vector2.new(0.5, 0.5)
	crown.Position = UDim2.fromScale(0.5, 0.58)
	crown.Size = UDim2.fromOffset(420, 280)
	crown.BackgroundColor3 = Theme.panel
	crown.Visible = false
	crown.Parent = root
	Theme.corner(crown, 20)
	Theme.stroke(crown, Theme.amber, 3, 0.12)
	Theme.pad(crown, 18)

	local crownTitle = Theme.text(crown, "Title", "CROWNED", 28, Theme.amber, Theme.fontTitle)
	crownTitle.Size = UDim2.new(1, 0, 0, 32)
	crownTitle.TextXAlignment = Enum.TextXAlignment.Center

	local crownName = Theme.text(crown, "Name", "", 22, Theme.cream, Theme.fontTitle)
	crownName.Position = UDim2.fromOffset(0, 40)
	crownName.Size = UDim2.new(1, 0, 0, 28)
	crownName.TextXAlignment = Enum.TextXAlignment.Center

	local crownRecap = Theme.text(crown, "Recap", "", 14, Theme.peach)
	crownRecap.Position = UDim2.fromOffset(0, 76)
	crownRecap.Size = UDim2.new(1, 0, 0, 72)
	crownRecap.TextXAlignment = Enum.TextXAlignment.Center

	local retry = Theme.button(crown, "Retry", "Party again", Theme.amber)
	retry.Position = UDim2.new(0, 0, 1, -88)
	retry.Size = UDim2.new(1, 0, 0, 38)

	local hub = Theme.button(crown, "Hub", "Back to hub", Theme.peach)
	hub.Position = UDim2.new(0, 0, 1, -42)
	hub.Size = UDim2.new(1, 0, 0, 36)

	local leave = Theme.button(root, "Leave", "Back to hub", Theme.peach)
	leave.AnchorPoint = Vector2.new(1, 1)
	leave.Position = UDim2.new(1, -18, 1, -18)
	leave.Size = UDim2.fromOffset(150, 36)

	local hubHandler: (() -> ())? = nil
	local retryHandler: (() -> ())? = nil
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

	local function paintSeats(seats: { Types.YarnPartySeat }, localUserId: number)
		for _, child in rows:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		for i, seat in seats do
			local tag = if seat.alive then "IN" else "OUT"
			local me = if seat.id == localUserId then "  · you" else if seat.isBot then "  · bot" else ""
			local tint = if seat.alive then Theme.cream else Theme.muted
			if i == 1 then
				tint = Theme.amber
			end
			local line = Theme.text(rows, "S" .. i, `#{i}  {seat.score}  {seat.name}  {tag}{me}`, 13, tint, Theme.fontMono)
			line.Size = UDim2.new(1, 0, 0, 20)
			line.LayoutOrder = i
		end
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if not visible then
				crown.Visible = false
			end
		end,
		update = function(snap: Types.YarnPartySnapshot, localUserId: number)
			if snap.phase == "Lobby" then
				title.Text = "YARN PARTY"
				sub.Text = `Bots fill empty seats  ·  {math.ceil(snap.countdown)}s`
			elseif snap.phase == "Podium" then
				title.Text = "CROWNED"
				sub.Text = snap.winnerName or ""
			else
				title.Text = snap.roundTitle
				sub.Text = `Round {snap.roundIndex}/{snap.roundCount}  ·  {math.ceil(snap.countdown)}s`
			end
			event.Text = snap.event or ""
			if snap.event and string.find(snap.event, "CROWNED", 1, true) then
				event.TextColor3 = Theme.amber
			elseif snap.event == "YARN DODGE" or snap.event == "GO" then
				event.TextColor3 = Theme.coral
			elseif snap.event == "STALL FREEZE" then
				event.TextColor3 = Theme.mint
			else
				event.TextColor3 = Theme.foam
			end
			hint.Text = if snap.roundKind == "Dodge"
				then "WASD  ·  Space hop the coral yarn"
				else "WASD onto a lit pillow when lanterns blink"
			if snap.phase == "Lobby" then
				hint.Text = "Waiting for loafs  ·  bots fill in a moment"
			end
			paintSeats(snap.seats, localUserId)
			local done = snap.phase == "Podium"
			crown.Visible = done
			leave.Visible = not done
			if done then
				crownName.Text = snap.winnerName or "Loaf"
				local lines = {}
				for i, seat in snap.seats do
					table.insert(lines, `#{i}  {seat.name}  {seat.score}`)
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
