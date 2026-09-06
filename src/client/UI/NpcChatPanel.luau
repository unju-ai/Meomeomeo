--!strict

local Theme = require(script.Parent.Parent.Theme)

local NpcChatPanel = {}

export type ChatApi = {
	root: Frame,
	open: (npcId: string, npcName: string) -> (),
	close: () -> (),
	append: (who: string, text: string) -> (),
	onSend: ((npcId: string, text: string) -> ()) -> (),
}

function NpcChatPanel.create(parent: Instance): ChatApi
	local root = Instance.new("Frame")
	root.Name = "NpcChat"
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.new(0, 16, 1, -16)
	root.Size = UDim2.fromOffset(340, 280)
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
	Theme.list(log, 6)

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

	local activeId = ""
	local sendHandler: ((string, string) -> ())? = nil

	local function append(who: string, text: string)
		local line = Theme.text(log, "Line", `{who}: {text}`, 13, Theme.cream)
		line.Size = UDim2.new(1, -8, 0, 0)
		line.AutomaticSize = Enum.AutomaticSize.Y
	end

	local function submit()
		local text = box.Text
		if text == "" or activeId == "" then
			return
		end
		box.Text = ""
		append("You", text)
		if sendHandler then
			sendHandler(activeId, text)
		end
	end

	send.MouseButton1Click:Connect(submit)
	box.FocusLost:Connect(function(enter)
		if enter then
			submit()
		end
	end)
	close.MouseButton1Click:Connect(function()
		root.Visible = false
	end)

	return {
		root = root,
		open = function(npcId: string, npcName: string)
			activeId = npcId
			title.Text = `Talk · {npcName}`
			root.Visible = true
			append(npcName, "mrrp? (AI stub — mock replies until a provider key is set)")
		end,
		close = function()
			root.Visible = false
		end,
		append = append,
		onSend = function(fn)
			sendHandler = fn
		end,
	}
end

return NpcChatPanel
