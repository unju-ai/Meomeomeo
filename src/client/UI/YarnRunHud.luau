--!strict

-- Stream-readable Yarn Run chrome: giant score, power chips, PB, funny fail card.

local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local YarnRunHud = {}

export type YarnHudApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (snap: Types.YarnRunSnapshot) -> (),
	onRetry: (() -> ()) -> (),
	onHub: (() -> ()) -> (),
}

local function chip(parent: Instance, name: string, text: string, color: Color3, order: number): TextLabel
	local label = Theme.text(parent, name, text, 16, Theme.ink, Theme.fontTitle)
	label.BackgroundColor3 = color
	label.BackgroundTransparency = 0.08
	label.Size = UDim2.fromOffset(92, 36)
	label.LayoutOrder = order
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Visible = false
	Theme.corner(label, 10)
	Theme.stroke(label, Theme.foam, 2, 0.35)
	return label
end

function YarnRunHud.create(parent: Instance): YarnHudApi
	local root = Instance.new("Frame")
	root.Name = "YarnRunHud"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = parent

	local score = Theme.text(root, "Score", "0", 56, Theme.amber, Theme.fontTitle)
	score.AnchorPoint = Vector2.new(0.5, 0)
	score.Position = UDim2.new(0.5, 0, 0, 72)
	score.Size = UDim2.fromOffset(420, 62)
	score.TextXAlignment = Enum.TextXAlignment.Center
	score.TextStrokeTransparency = 0.3

	local combo = Theme.text(root, "Combo", "", 22, Theme.coral, Theme.fontTitle)
	combo.AnchorPoint = Vector2.new(0.5, 0)
	combo.Position = UDim2.new(0.5, 0, 0, 132)
	combo.Size = UDim2.fromOffset(280, 26)
	combo.TextXAlignment = Enum.TextXAlignment.Center

	local meta = Theme.text(root, "Meta", "0m  ·  best 0", 14, Theme.cream, Theme.fontMono)
	meta.AnchorPoint = Vector2.new(0.5, 0)
	meta.Position = UDim2.new(0.5, 0, 0, 158)
	meta.Size = UDim2.fromOffset(420, 18)
	meta.TextXAlignment = Enum.TextXAlignment.Center

	local day = Theme.text(root, "Day", "", 13, Theme.peach, Theme.fontMono)
	day.AnchorPoint = Vector2.new(0.5, 0)
	day.Position = UDim2.new(0.5, 0, 0, 176)
	day.Size = UDim2.fromOffset(360, 16)
	day.TextXAlignment = Enum.TextXAlignment.Center

	local powers = Instance.new("Frame")
	powers.Name = "Powers"
	powers.BackgroundTransparency = 1
	powers.AnchorPoint = Vector2.new(0.5, 0)
	powers.Position = UDim2.new(0.5, 0, 0, 198)
	powers.Size = UDim2.fromOffset(400, 40)
	powers.Parent = root
	local layout = Theme.list(powers, 8, Enum.FillDirection.Horizontal)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local speedChip = chip(powers, "Speed", "SPD", Color3.fromRGB(90, 220, 255), 1)
	local magChip = chip(powers, "Magnet", "MAG", Color3.fromRGB(220, 90, 210), 2)
	local shdChip = chip(powers, "Shield", "SHD", Color3.fromRGB(120, 220, 160), 3)
	local dblChip = chip(powers, "Double", "2X", Theme.amber, 4)

	local event = Theme.text(root, "Event", "", 32, Theme.foam, Theme.fontTitle)
	event.AnchorPoint = Vector2.new(0, 0)
	event.Position = UDim2.new(0, 20, 0, 248)
	event.Size = UDim2.fromOffset(420, 40)
	event.TextStrokeTransparency = 0.25

	local hint = Theme.text(root, "Hint", "A / D lanes  ·  Space jump  ·  C slide  ·  chase the ghost", 13, Theme.peach)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -18)
	hint.Size = UDim2.fromOffset(560, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Center

	local summary = Instance.new("Frame")
	summary.Name = "Summary"
	summary.AnchorPoint = Vector2.new(0.5, 0.5)
	summary.Position = UDim2.fromScale(0.5, 0.55)
	summary.Size = UDim2.fromOffset(440, 300)
	summary.BackgroundColor3 = Theme.panel
	summary.Visible = false
	summary.Parent = root
	Theme.corner(summary, 20)
	Theme.stroke(summary, Theme.coral, 3, 0.12)
	Theme.pad(summary, 18)

	local fail = Theme.text(summary, "Fail", "Oof", 22, Theme.coral, Theme.fontTitle)
	fail.Size = UDim2.new(1, 0, 0, 28)
	fail.TextXAlignment = Enum.TextXAlignment.Center

	local recap = Theme.text(summary, "Recap", "", 16, Theme.cream)
	recap.Position = UDim2.fromOffset(0, 36)
	recap.Size = UDim2.new(1, 0, 0, 110)
	recap.TextXAlignment = Enum.TextXAlignment.Center

	local retry = Theme.button(summary, "Retry", "Retry dash", Theme.amber)
	retry.Position = UDim2.new(0, 0, 1, -88)
	retry.Size = UDim2.new(1, 0, 0, 38)

	local hub = Theme.button(summary, "Hub", "Back to hub", Theme.peach)
	hub.Position = UDim2.new(0, 0, 1, -42)
	hub.Size = UDim2.new(1, 0, 0, 36)

	local retryHandler: (() -> ())? = nil
	local hubHandler: (() -> ())? = nil

	retry.MouseButton1Click:Connect(function()
		if retryHandler then
			retryHandler()
		end
	end)
	hub.MouseButton1Click:Connect(function()
		if hubHandler then
			hubHandler()
		end
	end)

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if not visible then
				summary.Visible = false
			end
		end,
		update = function(snap: Types.YarnRunSnapshot)
			score.Text = tostring(snap.score)
			combo.Text = if snap.combo >= 2 then `COMBO x{snap.combo}` else ""
			local pb = if snap.bestMeters > 0 then `{snap.bestScore} / {snap.bestMeters}m` else tostring(snap.bestScore)
			meta.Text = `{snap.meters}m  ·  yarn {snap.yarn}  ·  PB {pb}`
			day.Text = if snap.dayKey ~= "" then `Daily seed  {snap.dayKey}` else ""
			speedChip.Visible = snap.powers.speed
			magChip.Visible = snap.powers.magnet
			shdChip.Visible = snap.powers.shield
			dblChip.Visible = snap.powers.double
			event.Text = snap.event or ""
			if snap.event == "MEGA YARN" or snap.event == "NEW PB" or snap.event == "2X YARN" then
				event.TextColor3 = Theme.amber
			elseif snap.event == "COMBO BREAK" or snap.event == "CLOSE!" then
				event.TextColor3 = Theme.coral
			elseif snap.event == "SHIELD UP" or snap.event == "SHIELD POP" or snap.event == "MAGNET ON" then
				event.TextColor3 = Theme.mint
			else
				event.TextColor3 = Theme.foam
			end
			local dead = snap.phase == "Dead"
			summary.Visible = dead
			if dead then
				fail.Text = if snap.newBest then "NEW PERSONAL BEST" else (snap.failReason or "Faceplant")
				fail.TextColor3 = if snap.newBest then Theme.amber else Theme.coral
				local ghostLine = if snap.bestMeters > 0 then `\nPB was {snap.bestScore} at {snap.bestMeters}m` else ""
				recap.Text =
					`Score {snap.score}\nYarn {snap.yarn}  ·  best combo x{snap.bestCombo}\n{snap.meters} meters of night-market chaos{ghostLine}`
			end
		end,
		onRetry = function(fn)
			retryHandler = fn
		end,
		onHub = function(fn)
			hubHandler = fn
		end,
	}
end

return YarnRunHud
