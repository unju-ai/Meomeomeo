--!strict

local Workspace = game:GetService("Workspace")

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local Targeting = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Targeting"))

local TargetingIndicator = {}

local folder: Folder? = nil
local rangeRing: BasePart? = nil
local aimPart: BasePart? = nil

local function ensure(): Folder
	if folder and folder.Parent then
		return folder
	end
	local existing = Workspace:FindFirstChild("MeoTargeting")
	if existing and existing:IsA("Folder") then
		folder = existing
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "MeoTargeting"
	created.Parent = Workspace
	folder = created
	return created
end

local function part(name: string, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.55
	p.Parent = ensure()
	return p
end

function TargetingIndicator.hide()
	if rangeRing then
		rangeRing:Destroy()
		rangeRing = nil
	end
	if aimPart then
		aimPart:Destroy()
		aimPart = nil
	end
end

function TargetingIndicator.show(ability: Types.AbilityDef, origin: Vector3, aim: Vector3)
	local mode = Targeting.of(ability)
	local parent = ensure()
	if not rangeRing or not rangeRing.Parent then
		rangeRing = part("Range", Color3.fromRGB(255, 220, 140))
	end
	if not aimPart or not aimPart.Parent then
		aimPart = part("Aim", Color3.fromRGB(120, 220, 180))
	end
	rangeRing.Parent = parent
	aimPart.Parent = parent

	local diameter = math.max(ability.range * 2, 8)
	rangeRing.Shape = Enum.PartType.Cylinder
	rangeRing.Size = Vector3.new(0.25, diameter, diameter)
	rangeRing.CFrame = CFrame.new(origin.X, origin.Y + 0.15, origin.Z) * CFrame.Angles(0, 0, math.rad(90))
	rangeRing.Transparency = 0.72

	if mode == "line" or mode == "dash" then
		local dest = Targeting.clampAim(origin, aim, ability.range)
		local flat = Targeting.flat(origin, dest)
		local length = math.max(flat.Magnitude, 2)
		local mid = origin + flat.Unit * (length / 2)
		aimPart.Shape = Enum.PartType.Block
		aimPart.Size = Vector3.new(if mode == "line" then math.max(ability.radius * 2, 2) else 2.2, 0.35, length)
		aimPart.CFrame = CFrame.lookAt(
			Vector3.new(mid.X, origin.Y + 0.35, mid.Z),
			Vector3.new(dest.X, origin.Y + 0.35, dest.Z)
		)
		aimPart.Transparency = 0.4
	else
		local dest = if mode == "instant" then origin else aim
		local size = math.max(ability.radius * 2, 6)
		aimPart.Shape = Enum.PartType.Cylinder
		aimPart.Size = Vector3.new(0.3, size, size)
		aimPart.CFrame = CFrame.new(dest.X, dest.Y + 0.2, dest.Z) * CFrame.Angles(0, 0, math.rad(90))
		aimPart.Transparency = 0.5
	end
end

return TargetingIndicator
