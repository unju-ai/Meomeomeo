--!strict

-- Hold-G radial smart-ping wheel. Release or click a slice.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.Theme)
local PingCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PingCatalog"))

local PingWheel = {}

export type WheelApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	isOpen: () -> boolean,
	open: () -> (),
	close: () -> (),
	selected: () -> string?,
	onPick: ((kind: string) -> ()) -> (),
}

local RING = 112
local DEADZONE = 34
local SLICE = 70

function PingWheel.create(parent: Instance): WheelApi
	local catalog = PingCatalog.wheel()
	local pickHandler: ((string) -> ())? = nil
	local highlighted: string? = nil
	local open = false
	local heartbeat: RBXScriptConnection? = nil

	local root = Instance.new("Frame")
	root.Name = "PingWheel"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.ZIndex = 41
	root.Parent = parent

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.68
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 41
	dim.Parent = root

	local hub = Theme.text(root, "Hub", "📍  release / click", 14, Theme.cream, Theme.fontTitle)
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.new(0.5, 0, 0.5, 0)
	hub.Size = UDim2.fromOffset(180, 36)
	hub.TextXAlignment = Enum.TextXAlignment.Center
	hub.ZIndex = 43

	local buttons: { TextButton } = {}

	local function angleOf(index: number): number
		return -math.pi / 2 + (index - 1) * (math.pi * 2 / #catalog)
	end

	local function setHighlight(id: string?)
		highlighted = id
		for i, def in catalog do
			local btn = buttons[i]
			if not btn then
				continue
			end
			local on = def.id == id
			btn.BackgroundColor3 = if on then def.color else Theme.panel
			btn.TextColor3 = if on then Theme.ink else Theme.cream
		end
		if id then
			local def = PingCatalog.get(id)
			hub.Text = if def then `{def.emoji}  {def.label}` else "📍  release / click"
		else
			hub.Text = "📍  release / click"
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
		btn.TextColor3 = Theme.cream
		btn.TextSize = 13
		btn.ZIndex = 44
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
		table.insert(buttons, btn)
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
			hub.Text = "📍  release / click"
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

return PingWheel
