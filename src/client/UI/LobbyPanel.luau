--!strict

local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local BrandCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrandCatalog"))

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
	onCloset: (() -> ()) -> (),
	onInvite: (() -> ()) -> (),
	onAcceptInvite: (() -> ()) -> (),
	onDeclineInvite: (() -> ()) -> (),
	onLeaveParty: (() -> ()) -> (),
	setPeers: (peers: { { userId: number, name: string } }) -> (),
	inviteUserId: () -> number?,
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
	root.Size = UDim2.fromOffset(480, 600)
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

	local subtitle = Theme.text(root, "Sub", BrandCatalog.GameLine, 16, Theme.cream, Theme.fontBody)
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
		"Pick a cat. Three towers, then the nexus. Practice with Easy / Normal / Hard bots, or queue with friends. Meet MEO, ME and MO by the lobby.",
		13,
		Theme.cream,
		Theme.fontBody
	)
	blurb.Position = UDim2.fromOffset(0, 112)
	blurb.Size = UDim2.new(1, 0, 0, 56)

	local party = Theme.text(root, "Party", "Party · solo", 13, Theme.peach, Theme.fontBody)
	party.Position = UDim2.fromOffset(0, 168)
	party.Size = UDim2.new(1, -72, 0, 36)

	local nextBtn = Theme.button(root, "NextCat", "Next", Theme.cream)
	nextBtn.AnchorPoint = Vector2.new(1, 0)
	nextBtn.Position = UDim2.new(1, 0, 0, 168)
	nextBtn.Size = UDim2.fromOffset(64, 28)
	nextBtn.TextSize = 14
	nextBtn.Visible = false

	local inviteCard = Instance.new("Frame")
	inviteCard.Name = "InviteCard"
	inviteCard.BackgroundTransparency = 1
	inviteCard.Position = UDim2.fromOffset(0, 208)
	inviteCard.Size = UDim2.new(1, 0, 0, 64)
	inviteCard.Visible = false
	inviteCard.Parent = root

	local inviteStatus = Theme.text(inviteCard, "InviteStatus", "", 13, Theme.amber, Theme.fontBody)
	inviteStatus.Size = UDim2.new(1, 0, 0, 20)

	local acceptBtn = Theme.button(inviteCard, "AcceptInvite", "Accept", Theme.mint)
	acceptBtn.Position = UDim2.fromOffset(0, 24)
	acceptBtn.Size = UDim2.new(0.48, 0, 0, 36)

	local declineBtn = Theme.button(inviteCard, "DeclineInvite", "Decline", Theme.coral)
	declineBtn.Position = UDim2.new(0.52, 0, 0, 24)
	declineBtn.Size = UDim2.new(0.48, 0, 0, 36)

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
	inviteBtn.TextTruncate = Enum.TextTruncate.AtEnd

	local leavePartyBtn = Theme.button(root, "LeaveParty", "Leave party", Theme.coral)
	leavePartyBtn.Position = UDim2.new(0.52, 0, 1, -188)
	leavePartyBtn.Size = UDim2.new(0.48, 0, 0, 36)
	leavePartyBtn.Visible = false

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

	local closetBtn = Theme.button(root, "Closet", "Closet", Theme.peach)
	closetBtn.Position = UDim2.new(0, 0, 1, -48)
	closetBtn.Size = UDim2.new(0.48, 0, 0, 40)

	local mintBtn = Theme.button(root, "Mint", "Mint Meo 404", Theme.coral)
	mintBtn.Position = UDim2.new(0.52, 0, 1, -48)
	mintBtn.Size = UDim2.new(0.48, 0, 0, 40)

	local inQueue = false
	local difficulty: Types.BotDifficulty = "Normal"
	local lastQueue: Types.QueueStatus? = nil
	local peers: { { userId: number, name: string } } = {}
	local peerIndex = 1
	local memberIds: { [number]: boolean } = {}
	local queueHandler: (() -> ())? = nil
	local leaveHandler: (() -> ())? = nil
	local practiceHandler: ((Types.BotDifficulty) -> ())? = nil
	local mintHandler: (() -> ())? = nil
	local closetHandler: (() -> ())? = nil
	local inviteHandler: (() -> ())? = nil
	local acceptHandler: (() -> ())? = nil
	local declineHandler: (() -> ())? = nil
	local leavePartyHandler: (() -> ())? = nil
	local tipsHandler: (() -> ())? = nil
	local difficultyHandler: ((Types.BotDifficulty) -> ())? = nil
	local backHandler: (() -> ())? = nil

	local function eligiblePeers(): { { userId: number, name: string } }
		local list = {}
		for _, peer in peers do
			if not memberIds[peer.userId] then
				table.insert(list, peer)
			end
		end
		return list
	end

	local function currentPeer(): { userId: number, name: string }?
		local list = eligiblePeers()
		if #list == 0 then
			return nil
		end
		peerIndex = ((peerIndex - 1) % #list) + 1
		return list[peerIndex]
	end

	local function paintPartyActions()
		local role = if lastQueue then lastQueue.partyRole else nil
		local count = if lastQueue and lastQueue.party then #lastQueue.party else 0
		if role == "leader" and count > 1 then
			queueBtn.Text = "Queue party"
			practiceBtn.Text = `Practice with party ({difficulty})`
		elseif role == "member" then
			queueBtn.Text = "Leader queues"
			practiceBtn.Text = `Leader starts Practice ({difficulty})`
		else
			queueBtn.Text = "Queue 🐾"
			practiceBtn.Text = `Practice vs 3 bots ({difficulty})`
		end
		local outgoing = if lastQueue then lastQueue.outgoingInvite else nil
		local peer = currentPeer()
		if outgoing and outgoing.toName then
			inviteBtn.Text = `Waiting on {outgoing.toName}`
			inviteBtn.Active = false
			inviteBtn.AutoButtonColor = false
		else
			inviteBtn.Active = true
			inviteBtn.AutoButtonColor = true
			inviteBtn.Text = if peer then `Invite {peer.name}` else "Invite friend in this server"
		end
		local inParty = role == "leader" or role == "member"
		leavePartyBtn.Visible = inParty
		leaveBtn.Text = if role == "leader" and count > 1 then "Cancel party queue" else "Cancel queue"
		nextBtn.Visible = peer ~= nil and #eligiblePeers() > 1 and not (outgoing and outgoing.toName)
		if inParty then
			inviteBtn.Size = UDim2.new(0.48, 0, 0, 36)
			inviteBtn.Position = UDim2.new(0, 0, 1, -188)
		else
			inviteBtn.Size = UDim2.new(1, 0, 0, 36)
			inviteBtn.Position = UDim2.new(0, 0, 1, -188)
		end
		easyBtn.BackgroundColor3 = if difficulty == "Easy" then Theme.mint else Theme.peach
		normalBtn.BackgroundColor3 = if difficulty == "Normal" then Theme.mint else Theme.peach
		hardBtn.BackgroundColor3 = if difficulty == "Hard" then Theme.mint else Theme.peach
	end
	paintPartyActions()

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
		local mode = if queueStatus.mode == "Reserved" then "reserved server" else "in-place"
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
		memberIds = {}
		if queueStatus.partyMemberIds then
			for _, userId in queueStatus.partyMemberIds do
				memberIds[userId] = true
			end
		end
		local role = queueStatus.partyRole
		if role == "leader" or role == "member" then
			party.Text = `Party · {table.concat(queueStatus.party, " · ")}`
		elseif #queueStatus.party > 1 then
			party.Text = `Party · {table.concat(queueStatus.party, ", ")}`
		else
			party.Text = "Party · solo"
		end
		local incoming = queueStatus.incomingInvite
		if incoming and incoming.fromName then
			inviteCard.Visible = true
			local remain = math.max(0, math.floor(incoming.expiresIn or 0))
			inviteStatus.Text = `{incoming.fromName} invited you · {remain}s`
		else
			inviteCard.Visible = false
			inviteStatus.Text = ""
		end
		refreshButtons()
		paintPartyActions()
	end

	queueBtn.MouseButton1Click:Connect(function()
		local role = if lastQueue then lastQueue.partyRole else nil
		if role ~= "member" then
			inQueue = true
			refreshButtons()
		end
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
		if lastQueue and lastQueue.outgoingInvite and lastQueue.outgoingInvite.toName then
			return
		end
		if inviteHandler then
			inviteHandler()
		end
	end)
	acceptBtn.MouseButton1Click:Connect(function()
		if acceptHandler then
			acceptHandler()
		end
	end)
	declineBtn.MouseButton1Click:Connect(function()
		if declineHandler then
			declineHandler()
		end
	end)
	leavePartyBtn.MouseButton1Click:Connect(function()
		if leavePartyHandler then
			leavePartyHandler()
		end
	end)
	nextBtn.MouseButton1Click:Connect(function()
		local list = eligiblePeers()
		if #list > 1 then
			peerIndex = (peerIndex % #list) + 1
			paintPartyActions()
		end
	end)
	local function chooseDifficulty(nextDifficulty: Types.BotDifficulty)
		difficulty = nextDifficulty
		paintPartyActions()
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
	closetBtn.MouseButton1Click:Connect(function()
		if closetHandler then
			closetHandler()
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
		onCloset = function(fn)
			closetHandler = fn
		end,
		onInvite = function(fn)
			inviteHandler = fn
		end,
		onAcceptInvite = function(fn)
			acceptHandler = fn
		end,
		onDeclineInvite = function(fn)
			declineHandler = fn
		end,
		onLeaveParty = function(fn)
			leavePartyHandler = fn
		end,
		setPeers = function(nextPeers)
			peers = nextPeers
			peerIndex = math.clamp(peerIndex, 1, math.max(1, #eligiblePeers()))
			paintPartyActions()
		end,
		inviteUserId = function()
			local peer = currentPeer()
			return if peer then peer.userId else nil
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
			paintPartyActions()
		end,
		difficulty = function()
			return difficulty
		end,
	}
end

return LobbyPanel
