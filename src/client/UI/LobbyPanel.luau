--!strict

local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local LobbyPanel = {}

export type LobbyApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (snapshot: Types.MatchSnapshot) -> (),
	setQueued: (queued: boolean) -> (),
	onQueue: (() -> ()) -> (),
	onLeave: (() -> ()) -> (),
	onPractice: ((difficulty: Types.BotDifficulty) -> ()) -> (),
	onMint: (() -> ()) -> (),
	difficulty: () -> Types.BotDifficulty,
}

function LobbyPanel.create(parent: Instance): LobbyApi
	local root = Instance.new("Frame")
	root.Name = "Lobby"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.48)
	root.Size = UDim2.fromOffset(460, 458)
	root.BackgroundColor3 = Theme.panel
	root.Parent = parent
	Theme.corner(root, 22)
	Theme.stroke(root, Theme.peach, 3, 0.15)
	Theme.pad(root, 22)

	local title = Theme.text(root, "Title", "MEO MEO MEO", 36, Theme.amber, Theme.fontTitle)
	title.Size = UDim2.new(1, 0, 0, 40)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local subtitle = Theme.text(root, "Sub", "A cat MOBA. Lanes, nexuses, voice, chaos.", 16, Theme.cream, Theme.fontBody)
	subtitle.Position = UDim2.fromOffset(0, 44)
	subtitle.Size = UDim2.new(1, 0, 0, 24)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center

	local status = Theme.text(root, "Status", "Lobby · 0 in queue", 15, Theme.peach, Theme.fontBody)
	status.Position = UDim2.fromOffset(0, 78)
	status.Size = UDim2.new(1, 0, 0, 22)
	status.TextXAlignment = Enum.TextXAlignment.Center

	local blurb = Theme.text(
		root,
		"Blurb",
		"Queue for a 5v5, or Practice solo against 3 AI cats on Red. Pick a champion, smash the nexus, yell on team voice.",
		14,
		Theme.cream,
		Theme.fontBody
	)
	blurb.Position = UDim2.fromOffset(0, 108)
	blurb.Size = UDim2.new(1, 0, 0, 72)

	local queueBtn = Theme.button(root, "Queue", "Queue 🐾", Theme.amber)
	queueBtn.Position = UDim2.new(0, 0, 1, -192)
	queueBtn.Size = UDim2.new(1, 0, 0, 40)

	local easyBtn = Theme.button(root, "Easy", "Easy bots", Theme.panelAlt)
	easyBtn.Position = UDim2.new(0, 0, 1, -144)
	easyBtn.Size = UDim2.new(0.48, 0, 0, 36)

	local normalBtn = Theme.button(root, "Normal", "Normal bots", Theme.mint)
	normalBtn.Position = UDim2.new(0.52, 0, 1, -144)
	normalBtn.Size = UDim2.new(0.48, 0, 0, 36)

	local practiceBtn = Theme.button(root, "Practice", "Practice vs 3 bots (Normal)", Theme.mint)
	practiceBtn.Position = UDim2.new(0, 0, 1, -96)
	practiceBtn.Size = UDim2.new(1, 0, 0, 40)

	local mintBtn = Theme.button(root, "Mint", "Mint Meo 404", Theme.coral)
	mintBtn.Position = UDim2.new(0, 0, 1, -48)
	mintBtn.Size = UDim2.new(1, 0, 0, 40)

	local leaveBtn = Theme.button(root, "Leave", "Leave queue", Theme.coral)
	leaveBtn.Position = UDim2.new(0, 0, 1, -192)
	leaveBtn.Size = UDim2.new(1, 0, 0, 40)
	leaveBtn.Visible = false

	local inQueue = false
	local difficulty: Types.BotDifficulty = "Normal"
	local queueHandler: (() -> ())? = nil
	local leaveHandler: (() -> ())? = nil
	local practiceHandler: ((Types.BotDifficulty) -> ())? = nil
	local mintHandler: (() -> ())? = nil

	local function paintDifficulty()
		easyBtn.BackgroundColor3 = if difficulty == "Easy" then Theme.mint else Theme.peach
		normalBtn.BackgroundColor3 = if difficulty == "Normal" then Theme.mint else Theme.peach
		practiceBtn.Text = `Practice vs 3 bots ({difficulty})`
	end
	paintDifficulty()

	local function refreshButtons()
		queueBtn.Visible = not inQueue
		leaveBtn.Visible = inQueue
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
	easyBtn.MouseButton1Click:Connect(function()
		difficulty = "Easy"
		paintDifficulty()
	end)
	normalBtn.MouseButton1Click:Connect(function()
		difficulty = "Normal"
		paintDifficulty()
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

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
		end,
		update = function(snapshot: Types.MatchSnapshot)
			status.Text = `Lobby · {snapshot.queueCount} in queue`
			if snapshot.phase ~= "Lobby" then
				inQueue = false
			end
			refreshButtons()
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
		difficulty = function()
			return difficulty
		end,
	}
end

return LobbyPanel
