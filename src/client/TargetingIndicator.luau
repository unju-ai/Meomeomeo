--!strict

-- Local client aim juice only. Does not parent to enemies or pierce fog.

local Workspace = game:GetService("Workspace")

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local Targeting = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Targeting"))
local Theme = require(script.Parent.Theme)

local TargetingIndicator = {}

local FOLDER_NAME = "MeoTargeting"

local RANGE_COLOR = Color3.fromRGB(255, 220, 160)
local VALID_COLOR = Theme.mint
local WARN_COLOR = Theme.coral

local folder: Folder? = nil
local rangeRing: BasePart? = nil
local pathPart: BasePart? = nil
local aimPart: BasePart? = nil
local tipPart: BasePart? = nil

local function ensure(): Folder
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

local function stylePart(p: BasePart, color: Color3, transparency: number)
	p.Color = color
	p.Material = Enum.Material.ForceField
	p.Transparency = transparency
end

local function part(name: string, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	stylePart(p, color, 0.55)
	p.Parent = ensure()
	return p
end

local function clearPart(slot: BasePart?)
	if slot then
		slot:Destroy()
	end
end

function TargetingIndicator.hide()
	clearPart(rangeRing)
	rangeRing = nil
	clearPart(pathPart)
	pathPart = nil
	clearPart(aimPart)
	aimPart = nil
	clearPart(tipPart)
	tipPart = nil
end

local function ensureRange(): BasePart
	if not rangeRing or not rangeRing.Parent then
		rangeRing = part("Range", RANGE_COLOR)
	end
	return rangeRing :: BasePart
end

local function ensurePath(): BasePart
	if not pathPart or not pathPart.Parent then
		pathPart = part("Path", VALID_COLOR)
	end
	return pathPart :: BasePart
end

local function ensureAim(): BasePart
	if not aimPart or not aimPart.Parent then
		aimPart = part("Aim", VALID_COLOR)
	end
	return aimPart :: BasePart
end

local function ensureTip(): BasePart
	if not tipPart or not tipPart.Parent then
		tipPart = part("Tip", VALID_COLOR)
	end
	return tipPart :: BasePart
end

local function dropUnused(keepPath: boolean, keepAim: boolean, keepTip: boolean)
	if not keepPath and pathPart then
		pathPart:Destroy()
		pathPart = nil
	end
	if not keepAim and aimPart then
		aimPart:Destroy()
		aimPart = nil
	end
	if not keepTip and tipPart then
		tipPart:Destroy()
		tipPart = nil
	end
end

local function flatLook(origin: Vector3, dest: Vector3, y: number): (Vector3, Vector3, number)
	local flat = Targeting.flat(origin, dest)
	local length = math.max(flat.Magnitude, 1.5)
	local dir = if flat.Magnitude > 0.2 then flat.Unit else Vector3.new(1, 0, 0)
	local mid = origin + dir * (length / 2)
	local from = Vector3.new(mid.X, y, mid.Z)
	local look = Vector3.new(dest.X, y, dest.Z)
	return from, look, length
end

function TargetingIndicator.show(ability: Types.AbilityDef, origin: Vector3, aim: Vector3)
	local preview = Targeting.preview(ability, origin, aim)
	if not preview.showAim then
		TargetingIndicator.hide()
		return
	end

	local parent = ensure()
	local ring = ensureRange()
	ring.Parent = parent

	local diameter = math.max(ability.range * 2, 8)
	-- Thin cream ring: ForceField reads softer than a neon slab on the night market.
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.1, diameter, diameter)
	ring.CFrame = CFrame.new(origin.X, origin.Y + 0.12, origin.Z) * CFrame.Angles(0, 0, math.rad(90))
	stylePart(ring, RANGE_COLOR, 0.78)

	local warn = preview.clamped or not preview.valid
	local tint = if warn then WARN_COLOR else VALID_COLOR
	local dest = preview.dest
	local y = origin.Y + 0.28

	if preview.mode == "line" then
		dropUnused(true, false, false)
		local path = ensurePath()
		path.Parent = parent
		local from, look, length = flatLook(origin, dest, y)
		local width = math.max(ability.radius * 2, 2)
		path.Shape = Enum.PartType.Block
		path.Size = Vector3.new(width, 0.22, length)
		path.CFrame = CFrame.lookAt(from, look)
		stylePart(path, tint, if warn then 0.42 else 0.52)
		return
	end

	if preview.mode == "dash" then
		dropUnused(true, false, true)
		local flat = Targeting.flat(origin, dest)
		local full = math.max(flat.Magnitude, 2)
		local dir = if flat.Magnitude > 0.2 then flat.Unit else Vector3.new(1, 0, 0)
		-- Short streak + tip so a dash does not read as a line bolt.
		local streakLen = math.clamp(full * 0.38, 8, math.min(full, 18))
		local streakMid = origin + dir * (streakLen / 2)
		local path = ensurePath()
		path.Parent = parent
		path.Shape = Enum.PartType.Block
		path.Size = Vector3.new(1.35, 0.18, streakLen)
		path.CFrame = CFrame.lookAt(
			Vector3.new(streakMid.X, y, streakMid.Z),
			Vector3.new(dest.X, y, dest.Z)
		)
		stylePart(path, tint, if warn then 0.38 else 0.48)

		local tip = ensureTip()
		tip.Parent = parent
		tip.Shape = Enum.PartType.Cylinder
		tip.Size = Vector3.new(0.2, 3.2, 3.2)
		tip.CFrame = CFrame.new(dest.X, y, dest.Z) * CFrame.Angles(0, 0, math.rad(90))
		stylePart(tip, tint, if warn then 0.32 else 0.42)
		return
	end

	-- ground AoE: clear circle at the (clamped) aim point; range ring stays while armed.
	dropUnused(false, true, false)
	local disc = ensureAim()
	disc.Parent = parent
	local size = math.max(ability.radius * 2, 6)
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.16, size, size)
	disc.CFrame = CFrame.new(dest.X, dest.Y + 0.16, dest.Z) * CFrame.Angles(0, 0, math.rad(90))
	stylePart(disc, tint, if warn then 0.4 else 0.55)
end

return TargetingIndicator
