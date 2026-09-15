--!strict

-- Translucent PB ghost. Same silhouette language as the live cat — no meshes.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local YarnRunCatalog = require(Shared:WaitForChild("YarnRunCatalog"))

local YarnGhost = {}

local model: Model? = nil
local GHOST = Color3.fromRGB(180, 230, 255)

local function origin(): Vector3
	return Constants.YarnRunOrigin
end

local function ensure(): Model
	if model and model.Parent then
		return model
	end
	local m = Instance.new("Model")
	m.Name = "MeoYarnGhost"
	local function blob(name: string, size: Vector3, offset: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.ForceField
		p.Color = GHOST
		p.Transparency = 0.45
		p.Size = size
		p.CFrame = CFrame.new(offset)
		p.Parent = m
		return p
	end
	blob("Body", Vector3.new(3.2, 2.4, 4.2), Vector3.zero)
	blob("Head", Vector3.new(2.2, 2, 2.2), Vector3.new(0, 2.1, 0.6))
	blob("EarL", Vector3.new(0.7, 1.3, 0.5), Vector3.new(-0.7, 3.3, 0.5))
	blob("EarR", Vector3.new(0.7, 1.3, 0.5), Vector3.new(0.7, 3.3, 0.5))
	blob("Tail", Vector3.new(0.6, 0.6, 2.4), Vector3.new(0, 0.6, -2.4))
	m.PrimaryPart = m:FindFirstChild("Body") :: BasePart
	m.Parent = Workspace
	model = m
	return m
end

function YarnGhost.setVisible(on: boolean)
	if not on then
		if model then
			model:Destroy()
			model = nil
		end
		return
	end
	ensure()
end

function YarnGhost.update(lane: number?, z: number?, y: number?, alive: boolean?)
	if lane == nil or z == nil or y == nil then
		YarnGhost.setVisible(false)
		return
	end
	local m = ensure()
	local at = origin() + Vector3.new(YarnRunCatalog.laneX(lane), 3.1 + y, z)
	m:PivotTo(CFrame.lookAt(at, at + Vector3.new(0, 0, 10)))
	for _, child in m:GetChildren() do
		if child:IsA("BasePart") then
			child.Transparency = if alive == false then 0.72 else 0.42
			child.Color = if alive == false then Color3.fromRGB(255, 210, 120) else GHOST
		end
	end
end

return YarnGhost
