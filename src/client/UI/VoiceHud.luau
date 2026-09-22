--!strict

-- Match voice pill. Mute touches AudioDeviceInput only — SFX and Music stay
-- on the Audio panel. Speaking pulse is real analyzer amplitude or absent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Parent.Theme)
local VoiceMeter = require(script.Parent.Parent.Voice.VoiceMeter)
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local VoiceLogic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VoiceLogic"))

local VoiceHud = {}

export type VoiceContext = {
	place: "Match" | "Hub" | "Stall",
	selfTeam: string?,
	seats: { VoiceLogic.Seat },
}

export type VoiceHudApi = {
	root: Frame,
	update: (status: Types.VoiceStatus) -> (),
	setContext: (context: VoiceContext) -> (),
}

function VoiceHud.create(parent: Instance): VoiceHudApi
	local player = Players.LocalPlayer
	local heard = false
	local status: Types.VoiceStatus = {
		mode = "Team",
		availability = "Unavailable",
		detail = "Checking voice…",
		localEnabled = nil,
		outsideMatch = "Off",
	}
	local context: VoiceContext = {
		place = "Hub",
		selfTeam = nil,
		seats = {},
	}

	local root = Instance.new("Frame")
	root.Name = "VoiceHud"
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.new(1, -16, 0, 12)
	root.Size = UDim2.fromOffset(292, 76)
	root.BackgroundColor3 = Theme.panel
	root.BackgroundTransparency = 0.08
	root.ZIndex = 6
	root.Parent = parent
	Theme.corner(root, 14)
	local border = Theme.stroke(root, Theme.peach, 2, 0.2)
	Theme.pad(root, 6)

	local title = Theme.text(root, "Title", "🎙️ Voice", 14, Theme.cream, Theme.fontTitle)
	title.Size = UDim2.new(1, -82, 0, 18)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local mute = Theme.button(root, "Mute", "Mute me", Theme.peach)
	mute.AnchorPoint = Vector2.new(1, 0)
	mute.Position = UDim2.new(1, 0, 0, 0)
	mute.Size = UDim2.fromOffset(76, 18)
	mute.TextSize = 12
	mute.ZIndex = 7

	local detail = Theme.text(root, "Detail", "Checking voice…", 11, Theme.peach, Theme.fontBody)
	detail.Position = UDim2.fromOffset(0, 18)
	detail.Size = UDim2.new(1, 0, 0, 28)
	detail.TextWrapped = true
	detail.TextYAlignment = Enum.TextYAlignment.Top

	local pulse = Instance.new("Frame")
	pulse.Name = "Pulse"
	pulse.BackgroundColor3 = Theme.mint
	pulse.BorderSizePixel = 0
	pulse.AnchorPoint = Vector2.new(0, 0.5)
	pulse.Position = UDim2.new(0, 0, 0, 54)
	pulse.Size = UDim2.fromOffset(8, 8)
	pulse.Visible = false
	pulse.ZIndex = 7
	pulse.Parent = root
	Theme.corner(pulse, 8)

	local you = Theme.text(root, "You", "You: checking", 12, Theme.cream, Theme.fontBody)
	you.Position = UDim2.fromOffset(12, 46)
	you.Size = UDim2.new(1, -12, 0, 16)

	local function render()
		local meter = VoiceMeter.sample()
		local inMatch = context.place == "Match"
		local view = VoiceLogic.present({
			mode = status.mode,
			availability = if heard then status.availability else "Unavailable",
			outsideMatch = status.outsideMatch,
			localEnabled = status.localEnabled,
			muted = meter.muted,
			selfUserId = player.UserId,
			selfTeam = if inMatch then context.selfTeam else nil,
			seats = if inMatch then context.seats else {},
			deviceReady = meter.deviceReady,
			signalAvailable = meter.signalAvailable,
			speaking = meter.speaking,
			serverDetail = status.detail,
		})
		if not heard then
			title.Text = "🎙️ Voice"
			detail.Text = "Checking voice…"
			you.Text = "You: checking"
			pulse.Visible = false
			border.Color = Theme.peach
			border.Transparency = 0.2
		else
			title.Text = view.title
			detail.Text = view.detail
			you.Text = view.footer
			local showPulse = view.pulse
			pulse.Visible = showPulse
			if showPulse then
				local wave = 0.45 + 0.55 * math.sin(os.clock() * 8)
				local size = 7 + math.floor(5 * wave)
				pulse.Size = UDim2.fromOffset(size, size)
				pulse.BackgroundTransparency = 0.05 + (1 - wave) * 0.45
			end
			if view.tone == "ready" then
				border.Color = Theme.mint
				border.Transparency = 0.15
			elseif view.tone == "muted" then
				border.Color = Theme.peach
				border.Transparency = 0.1
			else
				border.Color = Theme.warn
				border.Transparency = 0.1
			end
		end
		if not meter.deviceReady then
			mute.Text = "No mic"
			mute.BackgroundColor3 = Theme.muted
		elseif meter.muted then
			mute.Text = "Unmute"
			mute.BackgroundColor3 = Theme.coral
		else
			mute.Text = "Mute me"
			mute.BackgroundColor3 = Theme.peach
		end
	end

	mute.MouseButton1Click:Connect(function()
		local meter = VoiceMeter.sample()
		if not meter.deviceReady then
			return
		end
		VoiceMeter.setMuted(not meter.muted)
		render()
	end)

	VoiceMeter.onChanged(render)
	VoiceMeter.start(player)
	render()

	local function update(nextStatus: Types.VoiceStatus)
		status = nextStatus
		heard = true
		render()
	end

	local function setContext(nextContext: VoiceContext)
		context = nextContext
		local seats = if nextContext.place == "Match" then nextContext.seats else {}
		local team = if nextContext.place == "Match" then nextContext.selfTeam else nil
		VoiceMeter.setWatch(VoiceLogic.peerUserIds(player.UserId, team, seats))
		render()
	end

	return { root = root, update = update, setContext = setContext }
end

return VoiceHud
