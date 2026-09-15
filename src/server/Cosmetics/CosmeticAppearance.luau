--!strict

-- Primitive hat / collar / trail Parts. Sibling of MeoAppearance so looks rebuilds keep drip.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CosmeticCatalog = require(Shared:WaitForChild("CosmeticCatalog"))

local CosmeticAppearance = {}

local FOLDER_NAME = "MeoCosmetics"

type IdleItem = {
	weld: Weld,
	base: CFrame,
	kind: "spin" | "bob" | "orbit",
	phase: number,
}

local rigs: { [Model]: { IdleItem } } = {}
local loopBound = false

local function findPart(model: Model, names: { string }): BasePart?
	for _, name in names do
		local found = model:FindFirstChild(name)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	return nil
end

local function ensureLoop()
	if loopBound then
		return
	end
	loopBound = true
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for model, items in rigs do
			if not model.Parent then
				rigs[model] = nil
				continue
			end
			for _, item in items do
				if not item.weld.Parent then
					continue
				end
				if item.kind == "spin" then
					item.weld.C0 = item.base * CFrame.Angles(0, now * 1.8 + item.phase, 0)
				elseif item.kind == "bob" then
					item.weld.C0 = item.base * CFrame.new(0, math.sin(now * 2.4 + item.phase) * 0.08, 0)
				elseif item.kind == "orbit" then
					item.weld.C0 = item.base
						* CFrame.Angles(0, now * 2.2 + item.phase, 0)
						* CFrame.new(0.9, math.sin(now * 3 + item.phase) * 0.1, 0)
				end
			end
		end
	end)
end

local function addPart(
	folder: Folder,
	anchor: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): (Part, Weld)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	if shape then
		part.Shape = shape
	end
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("MeoLook", true)
	part.CFrame = anchor.CFrame * offset
	part.Parent = folder
	local weld = Instance.new("Weld")
	weld.Name = "MeoWeld"
	weld.Part0 = anchor
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	return part, weld
end

local function addIdle(items: { IdleItem }, weld: Weld, kind: "spin" | "bob" | "orbit", phase: number)
	table.insert(items, {
		weld = weld,
		base = weld.C0,
		kind = kind,
		phase = phase,
	})
end

local function buildHat(folder: Folder, head: BasePart, torso: BasePart, def: CosmeticCatalog.CosmeticDef, items: { IdleItem })
	local color = def.color
	if def.id == "CreamCap" then
		addPart(folder, head, "CapBrim", Vector3.new(1.45, 0.12, 1.45), CFrame.new(0, head.Size.Y * 0.42, 0), color, Enum.Material.SmoothPlastic)
		addPart(folder, head, "CapCrown", Vector3.new(1.05, 0.55, 1.05), CFrame.new(0, head.Size.Y * 0.68, 0.04), color, Enum.Material.SmoothPlastic)
	elseif def.id == "GoldBell" then
		local bell, weld = addPart(
			folder,
			torso,
			"Bell",
			Vector3.new(0.38, 0.38, 0.38),
			CFrame.new(0, torso.Size.Y * 0.28, -torso.Size.Z * 0.55),
			color,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 0.45
		light.Range = 6
		light.Parent = bell
		addIdle(items, weld, "bob", 0.4)
	elseif def.id == "CoralBeanie" then
		addPart(folder, head, "Beanie", Vector3.new(1.2, 0.7, 1.2), CFrame.new(0, head.Size.Y * 0.58, 0), color, Enum.Material.SmoothPlastic)
		addPart(folder, head, "Pom", Vector3.new(0.32, 0.32, 0.32), CFrame.new(0, head.Size.Y * 0.95, 0), Color3.fromRGB(255, 243, 224), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	elseif def.id == "CanalCrown" then
		addPart(folder, head, "Band", Vector3.new(1.2, 0.16, 1.2), CFrame.new(0, head.Size.Y * 0.5, 0), color, Enum.Material.Neon)
		addPart(folder, head, "SpikeL", Vector3.new(0.18, 0.55, 0.18), CFrame.new(-0.35, head.Size.Y * 0.82, 0), color, Enum.Material.Neon)
		addPart(folder, head, "SpikeR", Vector3.new(0.18, 0.55, 0.18), CFrame.new(0.35, head.Size.Y * 0.82, 0), color, Enum.Material.Neon)
		addPart(folder, head, "SpikeC", Vector3.new(0.2, 0.7, 0.2), CFrame.new(0, head.Size.Y * 0.9, 0), Color3.fromRGB(255, 196, 74), Enum.Material.Neon)
	elseif def.id == "PartyTiara" then
		addPart(folder, head, "Tiara", Vector3.new(1.05, 0.14, 0.35), CFrame.new(0, head.Size.Y * 0.55, -0.15), color, Enum.Material.Neon)
		addPart(folder, head, "Jewel", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, head.Size.Y * 0.72, -0.2), Color3.fromRGB(255, 243, 224), Enum.Material.Neon, Enum.PartType.Ball)
	elseif def.id == "TapeShades" then
		addPart(folder, head, "Shades", Vector3.new(head.Size.X * 0.85, 0.22, 0.16), CFrame.new(0, 0.06, -head.Size.Z * 0.5), color, Enum.Material.SmoothPlastic)
		addPart(folder, head, "LensGlow", Vector3.new(head.Size.X * 0.7, 0.08, 0.08), CFrame.new(0, 0.06, -head.Size.Z * 0.56), Color3.fromRGB(255, 220, 70), Enum.Material.Neon)
	end
end

local function buildTrail(folder: Folder, root: BasePart, def: CosmeticCatalog.CosmeticDef, items: { IdleItem })
	local color = def.color
	if def.id == "YarnPuff" then
		local puff, weld = addPart(
			folder,
			root,
			"Puff",
			Vector3.new(0.9, 0.9, 0.9),
			CFrame.new(0, 0.2, 1.35),
			color,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		puff.Transparency = 0.28
		addIdle(items, weld, "bob", 0.2)
	elseif def.id == "MintAura" then
		local aura, weld = addPart(
			folder,
			root,
			"Aura",
			Vector3.new(3.2, 3.2, 3.2),
			CFrame.new(0, 0.1, 0),
			color,
			Enum.Material.ForceField,
			Enum.PartType.Ball
		)
		aura.Transparency = 0.78
		addIdle(items, weld, "spin", 0)
	elseif def.id == "BraincellOrbs" then
		for i, side in { -1, 1 } do
			local orb, weld = addPart(
				folder,
				root,
				"Orb" .. i,
				Vector3.new(0.32, 0.32, 0.32),
				CFrame.new(side * 1.1, 1.1, 0.2),
				color,
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
			local light = Instance.new("PointLight")
			light.Color = color
			light.Brightness = 0.5
			light.Range = 7
			light.Parent = orb
			addIdle(items, weld, "orbit", side * 1.4)
		end
	elseif def.id == "MoonDust" then
		local dust, weld = addPart(
			folder,
			root,
			"Dust",
			Vector3.new(1.1, 1.1, 1.1),
			CFrame.new(0, 0.4, 1.5),
			color,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		dust.Transparency = 0.2
		addIdle(items, weld, "spin", 0.8)
		local spark, sparkWeld = addPart(
			folder,
			root,
			"Spark",
			Vector3.new(0.35, 0.35, 0.35),
			CFrame.new(0.4, 1.2, 0.8),
			Color3.fromRGB(255, 243, 224),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		addIdle(items, sparkWeld, "orbit", 2.1)
	end
end

function CosmeticAppearance.apply(model: Model, hatId: string?, trailId: string?)
	local existing = model:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	rigs[model] = nil

	local head = findPart(model, { "Head" })
	local torso = findPart(model, { "UpperTorso", "Torso", "HumanoidRootPart" })
	local root = findPart(model, { "HumanoidRootPart" })
	if not head or not torso or not root then
		return
	end

	local hat = CosmeticCatalog.get(hatId)
	local trail = CosmeticCatalog.get(trailId)
	if not hat and not trail then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = model
	local items: { IdleItem } = {}
	if hat and hat.slot == "hat" then
		buildHat(folder, head, torso, hat, items)
	end
	if trail and trail.slot == "trail" then
		buildTrail(folder, root, trail, items)
	end
	if #items > 0 then
		rigs[model] = items
		ensureLoop()
	end
end

function CosmeticAppearance.clear(model: Model)
	local existing = model:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	rigs[model] = nil
end

return CosmeticAppearance
