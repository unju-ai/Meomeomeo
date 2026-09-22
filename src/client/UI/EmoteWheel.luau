--!strict

-- Hold-to-open radial emote wheel. Release to cast; Esc cancels. Click a slice works too.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.Theme)
local EmoteCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("EmoteCatalog"))

local EmoteWheel = {}

export type WheelApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	isOpen: () -> boolean,
	open: () -> (),
	close: () -> (),
	selected: () -> string?,
	onPick: ((emoteId: string) -> ()) -> (),
}

local RING = 126
local DEADZONE = 40
local SLICE = 78
local HINT_IDLE = "😺  release to cast · Esc cancel"

type SliceUi = {
	btn: TextButton,
	stroke: UIStroke,
	defId: string,
	color: Color3,
}

function EmoteWheel.create(parent: Instance): WheelApi
	local catalog = EmoteCatalog.list()
	local pickHandler: ((string) -> ())? = nil
	local highlighted: string? = nil
	local open = false
	local heartbeat: RBXScriptConnection? = nil

	local root = Instance.new("Frame")
	root.Name = "EmoteWheel"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.ZIndex = 42
	root.Parent = parent

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.58
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 42
	dim.Parent = root

	local hub = Theme.text(root, "Hub", HINT_IDLE, 15, Theme.cream, Theme.fontTitle)
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromOffset(220, 44)
	hub.BackgroundColor3 = Theme.panel
	hub.BackgroundTransparency = 0.12
	hub.TextXAlignment = Enum.TextXAlignment.Center
	hub.ZIndex = 44
	Theme.corner(hub, 14)
	Theme.stroke(hub, Theme.strokeColor, 2, 0.35)

	local slices: { SliceUi } = {}

	local function angleOf(index: number): number
		return -math.pi / 2 + (index - 1) * (math.pi * 2 / #catalog)
	end

	local function setHighlight(id: string?)
		highlighted = id
		for _, slice in slices do
			local on = slice.defId == id
			slice.btn.BackgroundColor3 = if on then slice.color else Theme.panel
			slice.btn.BackgroundTransparency = if on then 0.05 else 0.12
			slice.btn.TextColor3 = if on then Theme.ink else Theme.cream
			slice.btn.TextSize = if on then 16 else 14
			slice.btn.Size = if on then UDim2.fromOffset(SLICE + 10, SLICE + 10) else UDim2.fromOffset(SLICE, SLICE)
			slice.stroke.Color = if on then slice.color else Theme.strokeColor
			slice.stroke.Thickness = if on then 3.5 else 2
			slice.stroke.Transparency = if on then 0.05 else 0.4
		end
		if id then
			local def = EmoteCatalog.get(id)
			hub.Text = if def then `{def.emoji}  {def.label}` else HINT_IDLE
			hub.TextColor3 = if def then def.color else Theme.cream
		else
			hub.Text = HINT_IDLE
			hub.TextColor3 = Theme.cream
		end
	end

	local function pickFromScreen(x: number, y: number): string?
		local center = root.AbsolutePosition + root.AbsoluteSize / 2
		local dx = x - center.X
		local dy = y - center.Y
		local dist = math.sqrt(dx * dx + dy * dy)
		if dist < DEADZONE then
			return nil
		end
		local angle = math.atan2(dy, dx)
		local slice = (math.pi * 2) / #catalog
		local start = -math.pi / 2 - slice / 2
		local idx = math.floor(((angle - start) % (math.pi * 2)) / slice) + 1
		local def = catalog[idx]
		return if def then def.id else nil
	end

	for i, def in catalog do
		local btn = Theme.button(root, def.id, `{def.emoji}\n{def.label}`, Theme.panel)
		btn.AnchorPoint = Vector2.new(0.5, 0.5)
		local ang = angleOf(i)
		btn.Position = UDim2.new(0.5, math.floor(math.cos(ang) * RING + 0.5), 0.5, math.floor(math.sin(ang) * RING + 0.5))
		btn.Size = UDim2.fromOffset(SLICE, SLICE)
		btn.BackgroundTransparency = 0.12
		btn.TextColor3 = Theme.cream
		btn.TextSize = 14
		btn.ZIndex = 45
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if not stroke then
			stroke = Theme.stroke(btn, Theme.strokeColor, 2, 0.4)
		end
		btn.MouseButton1Click:Connect(function()
			if pickHandler then
				pickHandler(def.id)
			end
		end)
		btn.MouseEnter:Connect(function()
			if open then
				setHighlight(def.id)
			end
		end)
		table.insert(slices, {
			btn = btn,
			stroke = stroke,
			defId = def.id,
			color = def.color,
		})
	end

	local function stopHeartbeat()
		if heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
	end

	local function startHeartbeat()
		stopHeartbeat()
		heartbeat = RunService.RenderStepped:Connect(function()
			if not open then
				return
			end
			local mouse = UserInputService:GetMouseLocation()
			setHighlight(pickFromScreen(mouse.X, mouse.Y))
		end)
	end

	local function setOpen(visible: boolean)
		open = visible
		root.Visible = visible
		if visible then
			local mouse = UserInputService:GetMouseLocation()
			setHighlight(pickFromScreen(mouse.X, mouse.Y))
			startHeartbeat()
		else
			stopHeartbeat()
			highlighted = nil
			hub.Text = HINT_IDLE
			hub.TextColor3 = Theme.cream
			for _, slice in slices do
				slice.btn.Size = UDim2.fromOffset(SLICE, SLICE)
				slice.btn.BackgroundColor3 = Theme.panel
				slice.btn.BackgroundTransparency = 0.12
				slice.btn.TextColor3 = Theme.cream
				slice.btn.TextSize = 14
				slice.stroke.Color = Theme.strokeColor
				slice.stroke.Thickness = 2
				slice.stroke.Transparency = 0.4
			end
		end
	end

	Players.LocalPlayer.CharacterRemoving:Connect(function()
		setOpen(false)
	end)

	return {
		root = root,
		setVisible = setOpen,
		isOpen = function()
			return open
		end,
		open = function()
			setOpen(true)
		end,
		close = function()
			setOpen(false)
		end,
		selected = function()
			return highlighted
		end,
		onPick = function(fn)
			pickHandler = fn
		end,
	}
end

return EmoteWheel
