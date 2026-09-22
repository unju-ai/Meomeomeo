--!strict

local BrandCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrandCatalog"))
local HostGuide = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("HostGuide"))
local Theme = require(script.Parent.Parent.Theme)

local NpcChatPanel = {}

export type ChatApi = {
	root: Frame,
	open: (npcId: string, npcName: string) -> (),
	close: () -> (),
	append: (who: string, text: string) -> (),
	note: (who: string, text: string) -> (),
	onSend: ((npcId: string, text: string, reply: (string, string) -> ()) -> ()) -> (),
}

function NpcChatPanel.create(parent: Instance): ChatApi
	local root = Instance.new("Frame")
	root.Name = "NpcChat"
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.new(0, 16, 1, -16)
	root.Size = UDim2.new(1, -32, 1, -32)
	root.ZIndex = 20
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(340, 280)
	bounds.Parent = root
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.Parent = parent
	Theme.corner(root, 16)
	Theme.stroke(root, Theme.coral, 2, 0.2)
	Theme.pad(root, 12)

	local title = Theme.text(root, "Title", "Talk to a cat", 18, Theme.amber, Theme.fontTitle)
	title.Size = UDim2.new(1, -28, 0, 22)

	local close = Theme.button(root, "Close", "✕", Theme.coral)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, 0)
	close.Size = UDim2.fromOffset(28, 28)
	close.TextSize = 14

	local log = Instance.new("ScrollingFrame")
	log.Name = "Log"
	log.BackgroundColor3 = Theme.panelAlt
	log.Position = UDim2.fromOffset(0, 36)
	log.Size = UDim2.new(1, 0, 1, -84)
	log.ScrollBarThickness = 4
	log.CanvasSize = UDim2.fromOffset(0, 0)
	log.AutomaticCanvasSize = Enum.AutomaticSize.Y
	log.Parent = root
	Theme.corner(log, 10)
	Theme.pad(log, 8)
	local layout = Theme.list(log, 6)
	local followLatest = true
	log:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		local bottom = math.max(0, log.AbsoluteCanvasSize.Y - log.AbsoluteWindowSize.Y)
		followLatest = log.CanvasPosition.Y >= bottom - 24
	end)
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if followLatest then
			log.CanvasPosition = Vector2.new(0, math.max(0, layout.AbsoluteContentSize.Y + 16 - log.AbsoluteWindowSize.Y))
		end
	end)

	local box = Instance.new("TextBox")
	box.Name = "Input"
	box.Position = UDim2.new(0, 0, 1, -36)
	box.Size = UDim2.new(1, -84, 0, 36)
	box.BackgroundColor3 = Theme.foam
	box.TextColor3 = Theme.ink
	box.PlaceholderText = "mrrp?"
	box.Text = ""
	box.TextSize = 14
	box.Font = Theme.fontBody
	box.ClearTextOnFocus = false
	box.Parent = root
	Theme.corner(box, 10)

	local send = Theme.button(root, "Send", "Send", Theme.amber)
	send.Position = UDim2.new(1, -76, 1, -36)
	send.Size = UDim2.fromOffset(76, 36)
	send.TextSize = 14

	local topics = Instance.new("ScrollingFrame")
	topics.Name = "Topics"
	topics.Position = UDim2.fromOffset(0, 36)
	topics.Size = UDim2.new(1, 0, 0, 48)
	topics.BackgroundTransparency = 1
	topics.BorderSizePixel = 0
	topics.ScrollBarThickness = 3
	topics.ScrollingDirection = Enum.ScrollingDirection.X
	topics.AutomaticCanvasSize = Enum.AutomaticSize.X
	topics.CanvasSize = UDim2.fromOffset(0, 0)
	topics.Visible = false
	topics.Parent = root
	Theme.list(topics, 6, Enum.FillDirection.Horizontal)
	local topicButtons: { TextButton } = {}

	local activeId = ""
	local session = 0
	local sendHandler: ((string, string, (string, string) -> ()) -> ())? = nil
	local lines: { TextLabel } = {}
	local lineOrder = 0
	local pending = false

	local function setPending(value: boolean)
		pending = value
		send.Text = if value then "…" else "Send"
		send.Active = not value
		send.AutoButtonColor = not value
		for _, button in topicButtons do
			button.Active = not value
			button.AutoButtonColor = not value
		end
	end

	local function append(who: string, text: string)
		lineOrder += 1
		local line = Theme.text(log, "Line", `{who}: {text}`, 13, Theme.cream)
		line.Size = UDim2.new(1, -8, 0, 0)
		line.AutomaticSize = Enum.AutomaticSize.Y
		line.LayoutOrder = lineOrder
		table.insert(lines, line)
		if #lines > 60 then
			table.remove(lines, 1):Destroy()
		end
	end

	local function submit(question: string?)
		local text = (question or box.Text):match("^%s*(.-)%s*$") or ""
		if text == "" or activeId == "" or pending or not sendHandler or not root.Visible then
			return
		end
		if not question then box.Text = "" end
		followLatest = true
		setPending(true)
		append("You", text)
		if sendHandler then
			local requestSession = session
			sendHandler(activeId, text, function(who: string, reply: string)
				if session == requestSession and root.Visible then
					setPending(false)
					append(who, reply)
				end
			end)
		end
	end

	local function addTopic(id: string, label: string, question: string)
		local button = Theme.button(topics, id, label, Theme.peach)
		button.Size = UDim2.fromOffset(100, 44)
		button.TextSize = 13
		button.TextWrapped = true
		button.LayoutOrder = #topicButtons + 1
		table.insert(topicButtons, button)
		button.Activated:Connect(function()
			if topics.Visible then submit(question) end
		end)
	end
	for _, chip in HostGuide.chips() do
		addTopic(chip.id, chip.label, chip.question)
	end

	send.MouseButton1Click:Connect(function() submit() end)
	box.FocusLost:Connect(function(enter)
		if enter then
			submit()
		end
	end)
	local function closeChat()
		session += 1
		root.Visible = false
		setPending(false)
	end
	close.MouseButton1Click:Connect(closeChat)

	return {
		root = root,
		open = function(npcId: string, npcName: string)
			session += 1
			for _, line in lines do line:Destroy() end
			table.clear(lines)
			lineOrder = 0
			followLatest = true
			setPending(false)
			box.Text = ""
			log.CanvasPosition = Vector2.new(0, 0)
			activeId = npcId
			title.Text = `Talk · {npcName}`
			root.Visible = true
			local host = BrandCatalog.host(npcId)
			topics.Visible = host ~= nil
			topics.CanvasPosition = Vector2.new(0, 0)
			bounds.MaxSize = Vector2.new(340, if host then 332 else 280)
			log.Position = UDim2.fromOffset(0, if host then 88 else 36)
			log.Size = UDim2.new(1, 0, 1, if host then -136 else -84)
			box.PlaceholderText = if host then "Fog, shop, voice, or help" else "mrrp?"
			append(npcName, if host then host.greeting else "Mrrp. What is on your mind?")
		end,
		close = closeChat,
		append = append,
		note = function(who: string, text: string)
			if root.Visible and activeId == "KittyCaster" then
				append(who, text)
			end
		end,
		onSend = function(fn)
			sendHandler = fn
		end,
	}
end

return NpcChatPanel
