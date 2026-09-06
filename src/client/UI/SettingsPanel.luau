--!strict

local Theme = require(script.Parent.Parent.Theme)

local SettingsPanel = {}

export type SettingsApi = {
	root: Frame,
	gear: TextButton,
	toggle: () -> (),
	setVisible: (visible: boolean) -> (),
	getVolume: () -> number,
	isMuted: () -> boolean,
	onChange: ((volume: number, muted: boolean) -> ()) -> (),
}

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

function SettingsPanel.create(parent: Instance, startVolume: number, startMuted: boolean): SettingsApi
	local volume = clamp01(startVolume)
	local muted = startMuted
	local changeHandler: ((number, boolean) -> ())? = nil

	local gear = Theme.button(parent, "SettingsGear", "SFX", Theme.amber)
	gear.AnchorPoint = Vector2.new(1, 0)
	gear.Position = UDim2.new(1, -16, 0, 96)
	gear.Size = UDim2.fromOffset(52, 40)
	gear.TextSize = 14
	gear.ZIndex = 30

	local root = Instance.new("Frame")
	root.Name = "SettingsPanel"
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.new(1, -16, 0, 144)
	root.Size = UDim2.fromOffset(240, 148)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.ZIndex = 30
	root.Parent = parent
	Theme.corner(root, 16)
	Theme.stroke(root, Theme.amber, 2, 0.2)
	Theme.pad(root, 12)

	local title = Theme.text(root, "Title", "SFX", 18, Theme.amber, Theme.fontTitle)
	title.Size = UDim2.new(1, 0, 0, 22)

	local hint = Theme.text(root, "Hint", "Master volume · mute combat juice", 11, Theme.peach)
	hint.Position = UDim2.fromOffset(0, 24)
	hint.Size = UDim2.new(1, 0, 0, 16)

	local muteBtn = Theme.button(root, "Mute", "Mute", Theme.coral)
	muteBtn.Position = UDim2.fromOffset(0, 46)
	muteBtn.Size = UDim2.new(1, 0, 0, 30)
	muteBtn.TextSize = 15

	local track = Instance.new("TextButton")
	track.Name = "VolumeTrack"
	track.Position = UDim2.fromOffset(0, 86)
	track.Size = UDim2.new(1, 0, 0, 16)
	track.BackgroundColor3 = Theme.panelAlt
	track.Text = ""
	track.AutoButtonColor = false
	track.Parent = root
	Theme.corner(track, 8)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.mint
	fill.Size = UDim2.new(volume, 0, 1, 0)
	fill.Parent = track
	Theme.corner(fill, 8)

	local valueLbl = Theme.text(root, "Value", "", 12, Theme.cream)
	valueLbl.Position = UDim2.fromOffset(0, 108)
	valueLbl.Size = UDim2.new(1, 0, 0, 20)

	local function paint()
		fill.Size = UDim2.new(if muted then 0 else volume, 0, 1, 0)
		muteBtn.Text = if muted then "Unmute SFX" else "Mute SFX"
		muteBtn.BackgroundColor3 = if muted then Theme.muted else Theme.coral
		valueLbl.Text = if muted then "Muted" else `Volume {math.floor(volume * 100 + 0.5)}%`
		if changeHandler then
			changeHandler(volume, muted)
		end
	end

	local function setFromX(x: number)
		local abs = track.AbsolutePosition.X
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		volume = clamp01((x - abs) / width)
		if muted and volume > 0 then
			muted = false
		end
		paint()
	end

	muteBtn.MouseButton1Click:Connect(function()
		muted = not muted
		paint()
	end)

	local dragging = false
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	track.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	track.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)

	gear.MouseButton1Click:Connect(function()
		root.Visible = not root.Visible
	end)

	paint()

	return {
		root = root,
		gear = gear,
		toggle = function()
			root.Visible = not root.Visible
		end,
		setVisible = function(visible: boolean)
			root.Visible = visible
		end,
		getVolume = function()
			return volume
		end,
		isMuted = function()
			return muted
		end,
		onChange = function(fn)
			changeHandler = fn
			fn(volume, muted)
		end,
	}
end

return SettingsPanel
