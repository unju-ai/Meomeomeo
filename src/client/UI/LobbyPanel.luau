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
	onPractice: (() -> ()) -> (),
}

function LobbyPanel.create(parent: Instance): LobbyApi
	local root = Instance.new("Frame")
	root.Name = "Lobby"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.48)
	root.Size = UDim2.fromOffset(460, 360)
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
		"Queue for a 5v5 (or start a practice match solo). Pick a cat champion, smash the other team's nexus, and yell about it on team voice.",
		14,
		Theme.cream,
		Theme.fontBody
	)
	blurb.Position = UDim2.fromOffset(0, 108)
	blurb.Size = UDim2.new(1, 0, 0, 72)

	local queueBtn = Theme.button(root, "Queue", "Queue 🐾", Theme.amber)
	queueBtn.Position = UDim2.new(0, 0, 1, -96)
	queueBtn.Size = UDim2.new(1, 0, 0, 40)

	local practiceBtn = Theme.button(root, "Practice", "Practice match (solo)", Theme.mint)
	practiceBtn.Position = UDim2.new(0, 0, 1, -48)
	practiceBtn.Size = UDim2.new(1, 0, 0, 40)

	local leaveBtn = Theme.button(root, "Leave", "Leave queue", Theme.coral)
	leaveBtn.Position = UDim2.new(0, 0, 1, -96)
	leaveBtn.Size = UDim2.new(1, 0, 0, 40)
	leaveBtn.Visible = false

	local inQueue = false
	local queueHandler: (() -> ())? = nil
	local leaveHandler: (() -> ())? = nil
	local practiceHandler: (() -> ())? = nil

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
	practiceBtn.MouseButton1Click:Connect(function()
		if practiceHandler then
			practiceHandler()
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
	}
end

return LobbyPanel
