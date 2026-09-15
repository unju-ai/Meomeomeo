--!strict

-- Stream-readable Yarn Run chrome: giant score, combo, funny fail card.

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
	meta.Size = UDim2.fromOffset(360, 18)
	meta.TextXAlignment = Enum.TextXAlignment.Center

	local event = Theme.text(root, "Event", "", 28, Theme.foam, Theme.fontTitle)
	event.AnchorPoint = Vector2.new(0, 0)
	event.Position = UDim2.new(0, 20, 0, 200)
	event.Size = UDim2.fromOffset(360, 36)
	event.TextStrokeTransparency = 0.25

	local hint = Theme.text(root, "Hint", "A / D lanes  ·  Space jump  ·  C slide  ·  T emote", 13, Theme.peach)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -18)
	hint.Size = UDim2.fromOffset(520, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Center

	local summary = Instance.new("Frame")
	summary.Name = "Summary"
	summary.AnchorPoint = Vector2.new(0.5, 0.5)
	summary.Position = UDim2.fromScale(0.5, 0.55)
	summary.Size = UDim2.fromOffset(420, 280)
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
	recap.Position = UDim2.fromOffset(0, 40)
	recap.Size = UDim2.new(1, 0, 0, 90)
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
			meta.Text = `{snap.meters}m  ·  yarn {snap.yarn}  ·  best {snap.bestScore}`
			event.Text = snap.event or ""
			event.TextColor3 = if snap.event == "MEGA YARN" then Theme.amber else Theme.foam
			local dead = snap.phase == "Dead"
			summary.Visible = dead
			if dead then
				fail.Text = snap.failReason or "Faceplant"
				recap.Text =
					`Score {snap.score}\nYarn {snap.yarn}  ·  best combo x{snap.bestCombo}\n{snap.meters} meters of night-market chaos`
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
