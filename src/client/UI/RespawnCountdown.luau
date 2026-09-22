--!strict

-- Local Cat Rift countdown while down. Reads the existing respawnAt stamp.
-- The death recap card is untouched; this chip sits center-top beside it.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RespawnJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RespawnJuice"))
local Theme = require(script.Parent.Parent.Theme)

local RespawnCountdown = {}

export type CountdownApi = {
	root: Frame,
	show: (respawnAt: number?) -> (),
	hide: () -> (),
}

local CREAM = Color3.fromRGB(RespawnJuice.Cream[1], RespawnJuice.Cream[2], RespawnJuice.Cream[3])
local AMBER = Color3.fromRGB(RespawnJuice.Amber[1], RespawnJuice.Amber[2], RespawnJuice.Amber[3])
local INK = Color3.fromRGB(RespawnJuice.Ink[1], RespawnJuice.Ink[2], RespawnJuice.Ink[3])

function RespawnCountdown.create(parent: Instance): CountdownApi
	local wash = Instance.new("Frame")
	wash.Name = "RespawnWash"
	wash.BackgroundColor3 = INK
	wash.BackgroundTransparency = 1
	wash.BorderSizePixel = 0
	wash.Size = UDim2.fromScale(1, 1)
	wash.Active = false
	wash.Visible = false
	wash.ZIndex = 2
	wash.Parent = parent

	local chip = Instance.new("Frame")
	chip.Name = "RespawnCountdown"
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.new(0.5, 0, 0, 76)
	chip.Size = UDim2.fromOffset(168, 74)
	chip.BackgroundColor3 = Theme.panel
	chip.Active = false
	chip.Visible = false
	chip.ZIndex = 17
	chip.Parent = parent
	Theme.corner(chip, 14)
	local stroke = Theme.stroke(chip, AMBER, 1.5, 0.18)

	local caption = Theme.text(chip, "Caption", RespawnJuice.caption(), 13, CREAM, Theme.fontTitle)
	caption.Position = UDim2.fromOffset(0, 6)
	caption.Size = UDim2.new(1, 0, 0, 16)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.TextWrapped = false
	caption.ZIndex = 18

	local clock = Theme.text(chip, "Clock", "", 30, CREAM, Theme.fontMono)
	clock.Position = UDim2.fromOffset(0, 20)
	clock.Size = UDim2.new(1, 0, 0, 32)
	clock.TextXAlignment = Enum.TextXAlignment.Center
	clock.TextWrapped = false
	clock.TextStrokeColor3 = INK
	clock.TextStrokeTransparency = 0.45
	clock.ZIndex = 18

	local hint = Theme.text(chip, "Hint", RespawnJuice.hint(), 12, Theme.muted, Theme.fontBody)
	hint.Position = UDim2.fromOffset(0, 50)
	hint.Size = UDim2.new(1, 0, 0, 16)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.TextWrapped = false
	hint.ZIndex = 18

	local deadline: number? = nil

	local function paint()
		if not chip.Visible then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local left = if deadline ~= nil then RespawnJuice.remaining(deadline, now) else 0
		local amount = RespawnJuice.pulseAmount(left, os.clock())
		clock.Text = if deadline ~= nil then RespawnJuice.chipRead(left) else "—"
		local pulsing = amount > 0
		clock.TextColor3 = if pulsing then AMBER else CREAM
		clock.TextSize = if pulsing then 30 + math.floor(6 * amount) else 30
		stroke.Color = if pulsing then CREAM else AMBER
		stroke.Transparency = if pulsing then 0.05 + 0.2 * (1 - amount) else 0.18
		wash.BackgroundTransparency = RespawnJuice.washTransparency(amount)
	end

	RunService.Heartbeat:Connect(paint)

	return {
		root = chip,
		show = function(respawnAt: number?)
			if typeof(respawnAt) == "number" then
				deadline = respawnAt
			end
			if deadline == nil then
				return
			end
			chip.Visible = true
			wash.Visible = true
			paint()
		end,
		hide = function()
			deadline = nil
			chip.Visible = false
			wash.Visible = false
			wash.BackgroundTransparency = 1
			clock.TextSize = 30
			clock.TextColor3 = CREAM
			stroke.Color = AMBER
			stroke.Transparency = 0.18
		end,
	}
end

return RespawnCountdown
