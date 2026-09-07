--!strict

local Theme = require(script.Parent.Parent.Theme)

local SettingsPanel = {}

export type SettingsState = {
	sfxVolume: number,
	sfxMuted: boolean,
	muteOthersEmotes: boolean,
	musicVolume: number,
	musicMuted: boolean,
}

export type SettingsApi = {
	root: Frame,
	gear: TextButton,
	toggle: () -> (),
	setVisible: (visible: boolean) -> (),
	getState: () -> SettingsState,
	onChange: ((state: SettingsState) -> ()) -> (),
}

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function makeTrack(parent: Instance, name: string, y: number, color: Color3): (TextButton, Frame)
	local track = Instance.new("TextButton")
	track.Name = name
	track.Position = UDim2.fromOffset(0, y)
	track.Size = UDim2.new(1, 0, 0, 14)
	track.BackgroundColor3 = Theme.panelAlt
	track.Text = ""
	track.AutoButtonColor = false
	track.Parent = parent
	Theme.corner(track, 8)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.Parent = track
	Theme.corner(fill, 8)
	return track, fill
end

function SettingsPanel.create(parent: Instance, start: SettingsState): SettingsApi
	local sfxVolume = clamp01(start.sfxVolume)
	local sfxMuted = start.sfxMuted == true
	local muteOthers = start.muteOthersEmotes == true
	local musicVolume = clamp01(start.musicVolume)
	local musicMuted = start.musicMuted == true
	local changeHandler: ((SettingsState) -> ())? = nil

	local gear = Theme.button(parent, "SettingsGear", "Audio", Theme.amber)
	gear.AnchorPoint = Vector2.new(1, 0)
	gear.Position = UDim2.new(1, -16, 0, 96)
	gear.Size = UDim2.fromOffset(62, 40)
	gear.TextSize = 14
	gear.ZIndex = 30

	local root = Instance.new("Frame")
	root.Name = "SettingsPanel"
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.new(1, -16, 0, 144)
	root.Size = UDim2.fromOffset(248, 268)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.ZIndex = 30
	root.Parent = parent
	Theme.corner(root, 16)
	Theme.stroke(root, Theme.amber, 2, 0.2)
	Theme.pad(root, 12)

	local title = Theme.text(root, "Title", "Audio", 18, Theme.amber, Theme.fontTitle)
	title.Size = UDim2.new(1, 0, 0, 22)

	local hint = Theme.text(root, "Hint", "SFX and Music are independent. Music stays quieter.", 11, Theme.peach)
	hint.Position = UDim2.fromOffset(0, 22)
	hint.Size = UDim2.new(1, 0, 0, 16)

	local muteSfx = Theme.button(root, "MuteSfx", "Mute SFX", Theme.coral)
	muteSfx.Position = UDim2.fromOffset(0, 42)
	muteSfx.Size = UDim2.new(0.5, -4, 0, 26)
	muteSfx.TextSize = 13

	local muteMusic = Theme.button(root, "MuteMusic", "Mute Music", Theme.blue)
	muteMusic.Position = UDim2.new(0.5, 4, 0, 42)
	muteMusic.Size = UDim2.new(0.5, -4, 0, 26)
	muteMusic.TextSize = 13

	local othersBtn = Theme.button(root, "MuteOthers", "Mute others' emotes", Theme.peach)
	othersBtn.Position = UDim2.fromOffset(0, 72)
	othersBtn.Size = UDim2.new(1, 0, 0, 24)
	othersBtn.TextSize = 13

	local sfxLbl = Theme.text(root, "SfxLbl", "SFX", 12, Theme.cream)
	sfxLbl.Position = UDim2.fromOffset(0, 102)
	sfxLbl.Size = UDim2.new(1, 0, 0, 16)

	local sfxTrack, sfxFill = makeTrack(root, "SfxTrack", 120, Theme.mint)

	local musicLbl = Theme.text(root, "MusicLbl", "Music", 12, Theme.cream)
	musicLbl.Position = UDim2.fromOffset(0, 142)
	musicLbl.Size = UDim2.new(1, 0, 0, 16)

	local musicTrack, musicFill = makeTrack(root, "MusicTrack", 160, Theme.blue)

	local valueLbl = Theme.text(root, "Value", "", 11, Theme.muted)
	valueLbl.Position = UDim2.fromOffset(0, 180)
	valueLbl.Size = UDim2.new(1, 0, 0, 32)

	local function snapshot(): SettingsState
		return {
			sfxVolume = sfxVolume,
			sfxMuted = sfxMuted,
			muteOthersEmotes = muteOthers,
			musicVolume = musicVolume,
			musicMuted = musicMuted,
		}
	end

	local function paint()
		sfxFill.Size = UDim2.new(if sfxMuted then 0 else sfxVolume, 0, 1, 0)
		musicFill.Size = UDim2.new(if musicMuted then 0 else musicVolume, 0, 1, 0)
		muteSfx.Text = if sfxMuted then "SFX off" else "Mute SFX"
		muteSfx.BackgroundColor3 = if sfxMuted then Theme.muted else Theme.coral
		muteMusic.Text = if musicMuted then "Music off" else "Mute Music"
		muteMusic.BackgroundColor3 = if musicMuted then Theme.muted else Theme.blue
		othersBtn.Text = if muteOthers then "Hearing others' emotes" else "Mute others' emotes"
		othersBtn.BackgroundColor3 = if muteOthers then Theme.muted else Theme.peach
		local sfxBit = if sfxMuted then "SFX muted" else `SFX {math.floor(sfxVolume * 100 + 0.5)}%`
		local musicBit = if musicMuted then "Music muted" else `Music {math.floor(musicVolume * 100 + 0.5)}%`
		valueLbl.Text = `{sfxBit}  ·  {musicBit}`
		if changeHandler then
			changeHandler(snapshot())
		end
	end

	local function bindTrack(track: TextButton, setVolume: (number) -> (), unmute: () -> ())
		local function setFromX(x: number)
			local abs = track.AbsolutePosition.X
			local width = track.AbsoluteSize.X
			if width <= 0 then
				return
			end
			setVolume(clamp01((x - abs) / width))
			unmute()
			paint()
		end
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
	end

	bindTrack(sfxTrack, function(value)
		sfxVolume = value
	end, function()
		if sfxMuted and sfxVolume > 0 then
			sfxMuted = false
		end
	end)
	bindTrack(musicTrack, function(value)
		musicVolume = value
	end, function()
		if musicMuted and musicVolume > 0 then
			musicMuted = false
		end
	end)

	muteSfx.MouseButton1Click:Connect(function()
		sfxMuted = not sfxMuted
		paint()
	end)
	muteMusic.MouseButton1Click:Connect(function()
		musicMuted = not musicMuted
		paint()
	end)
	othersBtn.MouseButton1Click:Connect(function()
		muteOthers = not muteOthers
		paint()
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
		getState = function()
			return snapshot()
		end,
		onChange = function(fn)
			changeHandler = fn
			fn(snapshot())
		end,
	}
end

return SettingsPanel
