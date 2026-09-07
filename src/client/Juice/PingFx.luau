--!strict

-- Team ping world marker. Billboard + neon disc. No mesh binaries.

local Workspace = game:GetService("Workspace")

local PingCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PingCatalog"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local Theme = require(script.Parent.Parent.Theme)

local PingFx = {}

local FOLDER_NAME = "MeoPingFx"
local LIFE = 2.6

local folder: Folder? = nil

local function fxFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = Workspace
	folder = created
	return created
end

function PingFx.play(payload: Types.PingPayload)
	local def = PingCatalog.get(payload.kind)
	local color = if def then def.color else Theme.amber
	local emoji = if def then def.emoji else "📍"
	local label = if def then def.label else "Attention"

	local disc = Instance.new("Part")
	disc.Name = "PingDisc"
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Material = Enum.Material.Neon
	disc.Color = color
	disc.Size = Vector3.new(5.4, 0.35, 5.4)
	disc.CFrame = CFrame.new(payload.position)
	disc.Parent = fxFolder()

	local ring = Instance.new("Part")
	ring.Name = "PingRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.ForceField
	ring.Color = color
	ring.Transparency = 0.35
	ring.Size = Vector3.new(7.2, 0.2, 7.2)
	ring.CFrame = CFrame.new(payload.position + Vector3.new(0, 0.15, 0))
	ring.Parent = fxFolder()

	local gui = Instance.new("BillboardGui")
	gui.Name = "PingBillboard"
	gui.Size = UDim2.fromOffset(160, 40)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.Parent = disc

	local caption = if payload.targetName then `{emoji}  {label} · {payload.targetName}` else `{emoji}  {label}`
	local text = Theme.text(gui, "Ping", caption, 16, Theme.cream, Theme.fontTitle)
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Theme.panel
	text.BackgroundTransparency = 0.2
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextStrokeTransparency = 0.35
	Theme.corner(text, 10)
	Theme.stroke(text, color, 2, 0.2)

	task.delay(LIFE, function()
		if disc.Parent then
			disc:Destroy()
		end
		if ring.Parent then
			ring:Destroy()
		end
	end)
end

return PingFx
