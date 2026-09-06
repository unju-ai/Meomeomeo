--!strict

local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local VoiceHud = {}

export type VoiceHudApi = {
	root: Frame,
	update: (status: Types.VoiceStatus) -> (),
}

function VoiceHud.create(parent: Instance): VoiceHudApi
	local root = Instance.new("Frame")
	root.Name = "VoiceHud"
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.new(1, -16, 0, 16)
	root.Size = UDim2.fromOffset(280, 72)
	root.BackgroundColor3 = Theme.panel
	root.BackgroundTransparency = 0.08
	root.Parent = parent
	Theme.corner(root, 14)
	local border = Theme.stroke(root, Theme.peach, 2, 0.2)
	Theme.pad(root, 10)

	local title = Theme.text(root, "Title", "🎙️ Voice · Team", 16, Theme.cream, Theme.fontTitle)
	title.Size = UDim2.new(1, 0, 0, 22)

	local detail = Theme.text(root, "Detail", "Checking VoiceChatService…", 12, Theme.peach, Theme.fontBody)
	detail.Position = UDim2.fromOffset(0, 24)
	detail.Size = UDim2.new(1, 0, 0, 32)

	local function update(status: Types.VoiceStatus)
		local icon = if status.availability == "Ready" then "🎙️" else "🔇"
		title.Text = `{icon} Voice · {status.mode}`
		local extra = ""
		if status.localEnabled == false then
			extra = " You: not eligible."
		elseif status.localEnabled == true then
			extra = " You: live."
		end
		detail.Text = status.detail .. extra
		if status.availability == "Ready" then
			border.Color = Theme.mint
			border.Transparency = 0.15
		else
			border.Color = Theme.warn
			border.Transparency = 0.1
		end
	end

	return { root = root, update = update }
end

return VoiceHud
