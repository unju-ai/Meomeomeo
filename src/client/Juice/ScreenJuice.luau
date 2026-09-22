--!strict

-- Brief screen flashes, a level-up pop, and a tiny camera shake stub.

local TweenService = game:GetService("TweenService")

local CameraFollow = require(script.Parent.Parent.CameraFollow)
local LevelUpJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LevelUpJuice"))
local Theme = require(script.Parent.Parent.Theme)

local ScreenJuice = {}

local flash: Frame?
local levelLabel: TextLabel?
local levelSub: TextLabel?
local levelToken = 0

local function ensure(gui: ScreenGui)
	if flash and levelLabel and levelSub then
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

	levelLabel = Theme.text(overlay, "LevelUp", "", 42, Theme.cream, Theme.fontTitle)
	levelLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	levelLabel.Position = UDim2.fromScale(0.5, 0.32)
	levelLabel.Size = UDim2.fromOffset(520, 64)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Center
	levelLabel.TextStrokeTransparency = 0.28
	levelLabel.TextStrokeColor3 = Theme.ink
	levelLabel.TextTransparency = 1
	levelLabel.ZIndex = 21

	levelSub = Theme.text(overlay, "LevelUpSub", "", 22, Theme.amber, Theme.fontTitle)
	levelSub.AnchorPoint = Vector2.new(0.5, 0.5)
	levelSub.Position = UDim2.fromScale(0.5, 0.38)
	levelSub.Size = UDim2.fromOffset(420, 32)
	levelSub.TextXAlignment = Enum.TextXAlignment.Center
	levelSub.TextStrokeTransparency = 0.4
	levelSub.TextStrokeColor3 = Theme.ink
	levelSub.TextTransparency = 1
	levelSub.ZIndex = 21
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

function ScreenJuice.banner(text: string, color: Color3?)
	local label = levelLabel
	if not label then
		return
	end
	levelToken += 1
	local token = levelToken
	label.Text = text
	label.TextColor3 = color or Theme.mint
	label.TextTransparency = 1
	label.TextSize = 28
	local sub = levelSub
	if sub then
		sub.Text = ""
		sub.TextTransparency = 1
	end
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

-- Punchy local Cat Rift level-up: cream/amber night-market banner + soft flash.
-- Teammate level-ups stay kill-feed only (no call into this).
function ScreenJuice.levelUp(level: number)
	local label = levelLabel
	local sub = levelSub
	if not label or not sub then
		return
	end
	pulse(Theme.amber, 0.62)
	levelToken += 1
	local token = levelToken
	label.Text = LevelUpJuice.bannerTitle()
	label.TextColor3 = Theme.cream
	label.TextTransparency = 1
	label.TextSize = 36
	sub.Text = LevelUpJuice.bannerLine(level)
	sub.TextColor3 = Theme.amber
	sub.TextTransparency = 1
	sub.TextSize = 18
	TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		TextSize = 58,
	}):Play()
	TweenService:Create(sub, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		TextSize = 26,
	}):Play()
	task.delay(LevelUpJuice.BannerHold, function()
		if token ~= levelToken then
			return
		end
		TweenService:Create(label, TweenInfo.new(0.28), { TextTransparency = 1, TextSize = 44 }):Play()
		TweenService:Create(sub, TweenInfo.new(0.28), { TextTransparency = 1, TextSize = 20 }):Play()
	end)
end
function ScreenJuice.comboBreak()
	pulse(Theme.coral, 0.62)
	ScreenJuice.banner("COMBO BREAK", Theme.coral)
end

function ScreenJuice.nearMiss()
	pulse(Theme.amber, 0.78)
	ScreenJuice.banner("CLOSE!", Theme.coral)
end

-- Equal readable hit for SPD / MAG / SHD / 2X (SHIELD POP already used damageFlash).
function ScreenJuice.powerFlash(color: Color3)
	pulse(color, 0.72)
end

-- Soft hold tint while a Yarn Run power is live (stream-readable, not a full flash).
function ScreenJuice.powerTint(color: Color3, peakTransparency: number?)
	local frame = flash
	if not frame then
		return
	end
	local peak = peakTransparency or 0.9
	frame.BackgroundColor3 = color
	TweenService:Create(frame, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = peak,
	}):Play()
end

function ScreenJuice.clearTint()
	local frame = flash
	if not frame then
		return
	end
	TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	}):Play()
end

function ScreenJuice.shakeTower()
	CameraFollow.shake(0.16, 0.22)
end

function ScreenJuice.shakeNexus()
	CameraFollow.shake(0.28, 0.38)
end

-- Soft end-screen sting. Victory = mint/amber wash; defeat = coral. One flash, no banner fight with EndScreen.
function ScreenJuice.matchEnd(won: boolean)
	if won then
		pulse(Theme.mint, 0.7)
		task.delay(0.12, function()
			pulse(Theme.amber, 0.82)
		end)
	else
		pulse(Theme.coral, 0.72)
	end
end

return ScreenJuice
