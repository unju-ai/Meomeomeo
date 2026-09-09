--!strict

local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local LobbyPanel = {}

export type LobbyApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (snapshot: Types.MatchSnapshot) -> (),
	updateQueue: (status: Types.QueueStatus) -> (),
	setQueued: (queued: boolean) -> (),
	onQueue: (() -> ()) -> (),
	onLeave: (() -> ()) -> (),
	onPractice: ((difficulty: Types.BotDifficulty) -> ()) -> (),
	onMint: (() -> ()) -> (),
	onInvite: (() -> ()) -> (),
	onShowTips: (() -> ()) -> (),
	onDifficulty: ((difficulty: Types.BotDifficulty) -> ()) -> (),
	onBack: (() -> ()) -> (),
	setDifficulty: (difficulty: Types.BotDifficulty) -> (),
	difficulty: () -> Types.BotDifficulty,
}

function LobbyPanel.create(parent: Instance): LobbyApi
	local root = Instance.new("Frame")
	root.Name = "Lobby"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.48)
	root.Size = UDim2.fromOffset(480, 520)
	root.BackgroundColor3 = Theme.panel
	root.Parent = parent
	Theme.corner(root, 22)
	Theme.stroke(root, Theme.peach, 3, 0.15)
	Theme.pad(root, 22)

	local backBtn = Theme.button(root, "BackHub", "← Hub", Theme.peach)
	backBtn.Position = UDim2.fromOffset(0, 4)
	backBtn.Size = UDim2.fromOffset(88, 32)
	backBtn.TextSize = 14

	local title = Theme.text(root, "Title", "CAT RIFT", 32, Theme.amber, Theme.fontTitle)
	title.Size = UDim2.new(1, -220, 0, 40)
	title.Position = UDim2.fromOffset(96, 0)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local tipsBtn = Theme.button(root, "ShowTips", "Show tips", Theme.cream)
	tipsBtn.AnchorPoint = Vector2.new(1, 0)
	tipsBtn.Position = UDim2.new(1, 0, 0, 4)
	tipsBtn.Size = UDim2.fromOffset(112, 32)
	tipsBtn.TextSize = 14

	local subtitle = Theme.text(root, "Sub", "MOBA stall. Lanes, nexuses, voice, chaos.", 16, Theme.cream, Theme.fontBody)
	subtitle.Position = UDim2.fromOffset(0, 44)
	subtitle.Size = UDim2.new(1, 0, 0, 22)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center

	local statusLabel = Theme.text(root, "Status", "Lobby · 0 in queue", 15, Theme.peach, Theme.fontBody)
	statusLabel.Position = UDim2.fromOffset(0, 70)
	statusLabel.Size = UDim2.new(1, 0, 0, 20)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center

	local eta = Theme.text(root, "Eta", "Not queued", 13, Theme.muted, Theme.fontMono)
	eta.Position = UDim2.fromOffset(0, 90)
	eta.Size = UDim2.new(1, 0, 0, 18)
	eta.TextXAlignment = Enum.TextXAlignment.Center

	local blurb = Theme.text(
		root,
		"Blurb",
		"Queue for a real match (in-place until MatchPlaceId is set). Practice: Easy / Normal / Hard bots.",
		13,
		Theme.cream,
		Theme.fontBody
	)
	blurb.Position = UDim2.fromOffset(0, 112)
	blurb.Size = UDim2.new(1, 0, 0, 56)

	local party = Theme.text(root, "Party", "Party · just you", 13, Theme.peach, Theme.fontBody)
	party.Position = UDim2.fromOffset(0, 168)
	party.Size = UDim2.new(1, 0, 0, 18)

	local queueBtn = Theme.button(root, "Queue", "Queue 🐾", Theme.amber)
	queueBtn.Position = UDim2.new(0, 0, 1, -236)
	queueBtn.Size = UDim2.new(1, 0, 0, 40)

	local leaveBtn = Theme.button(root, "Leave", "Cancel queue", Theme.coral)
	leaveBtn.Position = UDim2.new(0, 0, 1, -236)
	leaveBtn.Size = UDim2.new(1, 0, 0, 40)
	leaveBtn.Visible = false

	local inviteBtn = Theme.button(root, "Invite", "Invite friend in this server", Theme.peach)
	inviteBtn.Position = UDim2.new(0, 0, 1, -188)
	inviteBtn.Size = UDim2.new(1, 0, 0, 36)

	local easyBtn = Theme.button(root, "Easy", "Easy", Theme.panelAlt)
	easyBtn.Position = UDim2.new(0, 0, 1, -144)
	easyBtn.Size = UDim2.new(0.32, 0, 0, 36)

	local normalBtn = Theme.button(root, "Normal", "Normal", Theme.mint)
	normalBtn.Position = UDim2.new(0.34, 0, 1, -144)
	normalBtn.Size = UDim2.new(0.32, 0, 0, 36)

	local hardBtn = Theme.button(root, "Hard", "Hard", Theme.coral)
	hardBtn.Position = UDim2.new(0.68, 0, 1, -144)
	hardBtn.Size = UDim2.new(0.32, 0, 0, 36)

	local practiceBtn = Theme.button(root, "Practice", "Practice vs 3 bots (Normal)", Theme.mint)
	practiceBtn.Position = UDim2.new(0, 0, 1, -96)
	practiceBtn.Size = UDim2.new(1, 0, 0, 40)

	local mintBtn = Theme.button(root, "Mint", "Mint Meo 404", Theme.coral)
	mintBtn.Position = UDim2.new(0, 0, 1, -48)
	mintBtn.Size = UDim2.new(1, 0, 0, 40)

	local inQueue = false
	local difficulty: Types.BotDifficulty = "Normal"
	local lastQueue: Types.QueueStatus? = nil
	local queueHandler: (() -> ())? = nil
	local leaveHandler: (() -> ())? = nil
	local practiceHandler: ((Types.BotDifficulty) -> ())? = nil
	local mintHandler: (() -> ())? = nil
	local inviteHandler: (() -> ())? = nil
	local tipsHandler: (() -> ())? = nil
	local difficultyHandler: ((Types.BotDifficulty) -> ())? = nil
	local backHandler: (() -> ())? = nil

	local function paintDifficulty()
		easyBtn.BackgroundColor3 = if difficulty == "Easy" then Theme.mint else Theme.peach
		normalBtn.BackgroundColor3 = if difficulty == "Normal" then Theme.mint else Theme.peach
		hardBtn.BackgroundColor3 = if difficulty == "Hard" then Theme.mint else Theme.peach
		practiceBtn.Text = `Practice vs 3 bots ({difficulty})`
	end
	paintDifficulty()

	local function refreshButtons()
		local phase = if lastQueue then lastQueue.phase else "Idle"
		local found = phase == "Found" or phase == "Teleporting"
		queueBtn.Visible = not inQueue and not found
		leaveBtn.Visible = inQueue and not found
		if found then
			leaveBtn.Visible = false
			queueBtn.Visible = false
		end
	end

	local function applyQueue(queueStatus: Types.QueueStatus)
		lastQueue = queueStatus
		inQueue = queueStatus.inQueue or queueStatus.phase == "Found" or queueStatus.phase == "Teleporting"
		local mode = if queueStatus.mode == "Reserved" then "reserved server" else "this server"
		statusLabel.Text = `Lobby · {queueStatus.count} in queue`
		if queueStatus.phase == "Found" then
			eta.TextColor3 = Theme.amber
			eta.Text = `MATCH FOUND  ·  {mode}`
			blurb.Text = queueStatus.detail
		elseif queueStatus.phase == "Teleporting" then
			eta.TextColor3 = Theme.amber
			eta.Text = "Teleporting to reserved match…"
			blurb.Text = queueStatus.detail
		elseif queueStatus.inQueue then
			eta.TextColor3 = Theme.peach
			eta.Text = `In queue  {queueStatus.count}/{queueStatus.needed}  ·  ~{queueStatus.estimatedSeconds}s  ·  {mode}`
			blurb.Text = queueStatus.detail
		else
			eta.TextColor3 = Theme.muted
			eta.Text = `Queue idle  {queueStatus.count}/{queueStatus.needed}  ·  {mode}`
			blurb.Text = queueStatus.detail
		end
		if #queueStatus.party > 0 then
			party.Text = `Party · {table.concat(queueStatus.party, ", ")}`
		else
			party.Text = "Party · just you  (invite a friend in this server)"
		end
		refreshButtons()
	end

	queueBtn.MouseButton1Click:Connect(function()
		inQueue = true
		refreshButtons()
		if queueHandler then
			queueHandler()
		end
	end)
	leaveBtn.MouseButton1Click:Connect(function()
		inQueue = false
		refreshButtons()
		if leaveHandler then
			leaveHandler()
		end
	end)
	inviteBtn.MouseButton1Click:Connect(function()
		if inviteHandler then
			inviteHandler()
		end
	end)
	local function chooseDifficulty(nextDifficulty: Types.BotDifficulty)
		difficulty = nextDifficulty
		paintDifficulty()
		if difficultyHandler then
			difficultyHandler(difficulty)
		end
	end

	easyBtn.MouseButton1Click:Connect(function()
		chooseDifficulty("Easy")
	end)
	normalBtn.MouseButton1Click:Connect(function()
		chooseDifficulty("Normal")
	end)
	hardBtn.MouseButton1Click:Connect(function()
		chooseDifficulty("Hard")
	end)
	practiceBtn.MouseButton1Click:Connect(function()
		if practiceHandler then
			practiceHandler(difficulty)
		end
	end)
	mintBtn.MouseButton1Click:Connect(function()
		if mintHandler then
			mintHandler()
		end
	end)
	tipsBtn.MouseButton1Click:Connect(function()
		if tipsHandler then
			tipsHandler()
		end
	end)
	backBtn.MouseButton1Click:Connect(function()
		if backHandler then
			backHandler()
		end
	end)

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
		end,
		update = function(snapshot: Types.MatchSnapshot)
			statusLabel.Text = `Lobby · {snapshot.queueCount} in queue`
			if snapshot.queue then
				applyQueue(snapshot.queue)
			end
			if snapshot.phase ~= "Lobby" then
				inQueue = false
			end
			refreshButtons()
		end,
		updateQueue = function(queueStatus: Types.QueueStatus)
			applyQueue(queueStatus)
		end,
		setQueued = function(queued: boolean)
			inQueue = queued
			refreshButtons()
		end,
		onQueue = function(fn)
			queueHandler = fn
		end,
		onLeave = function(fn)
			leaveHandler = fn
		end,
		onPractice = function(fn)
			practiceHandler = fn
		end,
		onMint = function(fn)
			mintHandler = fn
		end,
		onInvite = function(fn)
			inviteHandler = fn
		end,
		onShowTips = function(fn)
			tipsHandler = fn
		end,
		onDifficulty = function(fn)
			difficultyHandler = fn
		end,
		onBack = function(fn)
			backHandler = fn
		end,
		setDifficulty = function(nextDifficulty: Types.BotDifficulty)
			if nextDifficulty ~= "Easy" and nextDifficulty ~= "Normal" and nextDifficulty ~= "Hard" then
				return
			end
			difficulty = nextDifficulty
			paintDifficulty()
		end,
		difficulty = function()
			return difficulty
		end,
	}
end

return LobbyPanel
