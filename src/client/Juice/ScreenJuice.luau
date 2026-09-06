--!strict

-- Brief screen flashes, a level-up pop, and a tiny camera shake stub.

local TweenService = game:GetService("TweenService")

local CameraFollow = require(script.Parent.Parent.CameraFollow)
local Theme = require(script.Parent.Parent.Theme)

local ScreenJuice = {}

local flash: Frame?
local levelLabel: TextLabel?
local levelToken = 0

local function ensure(gui: ScreenGui)
	if flash and levelLabel then
		return
	end
	local overlay = Instance.new("Frame")
	overlay.Name = "JuiceOverlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 20
	overlay.Parent = gui

	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundColor3 = Theme.coral
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 20
	flash.Parent = overlay

	levelLabel = Theme.text(overlay, "LevelUp", "", 42, Theme.mint, Theme.fontTitle)
	levelLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	levelLabel.Position = UDim2.new(0.5, 0, 0.34, 0)
	levelLabel.Size = UDim2.fromOffset(420, 52)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Center
	levelLabel.TextStrokeTransparency = 0.35
	levelLabel.TextTransparency = 1
	levelLabel.ZIndex = 21
end

local function pulse(color: Color3, peakTransparency: number)
	local frame = flash
	if not frame then
		return
	end
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1
	local inn = TweenService:Create(frame, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = peakTransparency,
	})
	local out = TweenService:Create(frame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})
	inn:Play()
	inn.Completed:Once(function()
		out:Play()
	end)
end

function ScreenJuice.init(gui: ScreenGui)
	ensure(gui)
end

function ScreenJuice.damageFlash()
	pulse(Theme.coral, 0.78)
end

function ScreenJuice.healFlash()
	pulse(Theme.mint, 0.84)
end

function ScreenJuice.levelUp(level: number)
	local label = levelLabel
	if not label then
		return
	end
	levelToken += 1
	local token = levelToken
	label.Text = `LEVEL {level}!`
	label.TextTransparency = 1
	label.TextSize = 28
	local pop = TweenService:Create(label, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		TextSize = 44,
	})
	pop:Play()
	task.delay(1.05, function()
		if token ~= levelToken then
			return
		end
		TweenService:Create(label, TweenInfo.new(0.22), { TextTransparency = 1, TextSize = 36 }):Play()
	end)
end

function ScreenJuice.shakeTower()
	CameraFollow.shake(0.16, 0.22)
end

function ScreenJuice.shakeNexus()
	CameraFollow.shake(0.28, 0.38)
end

return ScreenJuice
