--!strict

-- Dresses a locked champion with primitive Parts already in Roblox.
-- Does not resize or replace HumanoidRootPart (combat / dash / recall).
-- Extra parts are massless, non-colliding, and parented under MeoAppearance
-- so a later mesh swap can replace this folder only.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ChampionCatalog = require(Shared:WaitForChild("ChampionCatalog"))
local ChampionLooks = require(Shared:WaitForChild("ChampionLooks"))
local Types = require(Shared:WaitForChild("Types"))

export type ApplyInfo = {
	championId: string,
	team: Types.TeamId,
	displayName: string,
	isBot: boolean,
}

type IdleKind = "ear" | "tail" | "orb" | "aura" | "bob"

type IdleItem = {
	weld: Weld,
	base: CFrame,
	kind: IdleKind,
	phase: number,
}

type Rig = {
	items: { IdleItem },
}

local ChampionAppearance = {}

local rigs: { [Model]: Rig } = {}
local loopBound = false

local FOLDER_NAME = "MeoAppearance"
local PLATE_NAME = "MeoNameplate"

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
		for model, rig in rigs do
			if not model.Parent then
				rigs[model] = nil
				continue
			end
			for _, item in rig.items do
				if not item.weld.Parent then
					continue
				end
				local wave = math.sin(now * 6.4 + item.phase)
				if item.kind == "ear" then
					item.weld.C0 = item.base * CFrame.Angles(wave * 0.11, 0, wave * 0.04)
				elseif item.kind == "tail" then
					item.weld.C0 = item.base
						* CFrame.Angles(math.sin(now * 2.6 + item.phase) * 0.18, math.sin(now * 1.8) * 0.22, 0)
				elseif item.kind == "orb" then
					item.weld.C0 = item.base
						* CFrame.Angles(0, now * 1.5 + item.phase, 0)
						* CFrame.new(0, math.sin(now * 3.1 + item.phase) * 0.14, 0)
				elseif item.kind == "aura" then
					item.weld.C0 = item.base * CFrame.new(0, math.sin(now * 2.1) * 0.07, 0)
				elseif item.kind == "bob" then
					item.weld.C0 = item.base * CFrame.new(0, math.sin(now * 2.3 + item.phase) * 0.035, 0)
				end
			end
		end
	end)
end

local function addIdle(rig: Rig, weld: Weld, kind: IdleKind, phase: number)
	table.insert(rig.items, {
		weld = weld,
		base = weld.C0,
		kind = kind,
		phase = phase,
	})
end

local function decorate(part: BasePart, color: Color3, material: Enum.Material)
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = true
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("MeoLook", true)
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
	decorate(part, color, material)
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

local function addLight(part: BasePart, color: Color3, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = 7
	light.Parent = part
end

local function hideAvatarAccessories(model: Model)
	for _, child in model:GetChildren() do
		if child:IsA("Accoutrement") then
			for _, d in child:GetDescendants() do
				if d:IsA("BasePart") then
					d.Transparency = 1
					d.CanCollide = false
				end
			end
		end
	end
end

local function tintBody(model: Model, look: ChampionLooks.LookDef, body: Color3, isBot: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("MeoLook") ~= true then
			if d.Name == "HumanoidRootPart" then
				if isBot then
					d.Transparency = 1
					d.CanCollide = true
				end
			else
				d.Color = if d.Name == "Head" then body:Lerp(Color3.new(1, 1, 1), 0.12) else body
				d.Material = look.material
			end
		end
	end
	if isBot then
		local torso = findPart(model, { "Torso", "UpperTorso" })
		if torso and look.torsoScale ~= 1 then
			local base = Vector3.new(2.1, 2.2, 1.2)
			torso.Size = Vector3.new(base.X * look.torsoScale, base.Y * math.clamp(look.torsoScale, 0.92, 1.18), base.Z * look.torsoScale)
		end
	end
	local colors = model:FindFirstChildOfClass("BodyColors")
	if colors then
		colors.HeadColor3 = body:Lerp(Color3.new(1, 1, 1), 0.12)
		colors.TorsoColor3 = body
		colors.LeftArmColor3 = body
		colors.RightArmColor3 = body
		colors.LeftLegColor3 = body
		colors.RightLegColor3 = body
	end
end

local function attachNameplate(anchor: BasePart, champName: string, role: string, isBot: boolean, team: Types.TeamId, tall: boolean)
	local old = anchor:FindFirstChild(PLATE_NAME)
	if old then
		old:Destroy()
	end
	local parent = anchor.Parent
	if parent then
		local leftover = parent:FindFirstChild(PLATE_NAME)
		if leftover then
			leftover:Destroy()
		end
		local botName = parent:FindFirstChild("BotName")
		if botName then
			botName:Destroy()
		end
	end
	local rootBot = anchor:FindFirstChild("BotName")
	if rootBot then
		rootBot:Destroy()
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = PLATE_NAME
	bb.Size = UDim2.fromOffset(176, 38)
	bb.StudsOffset = Vector3.new(0, if tall then 4.4 else 3.55, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 90
	bb.Parent = anchor

	local name = Instance.new("TextLabel")
	name.Name = "Champ"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.58, 0)
	name.Font = Enum.Font.FredokaOne
	name.TextSize = 14
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.35
	name.Text = if isBot then `{champName} (Bot)` else champName
	name.Parent = bb

	local roleLabel = Instance.new("TextLabel")
	roleLabel.Name = "Role"
	roleLabel.BackgroundTransparency = 1
	roleLabel.Position = UDim2.fromScale(0, 0.52)
	roleLabel.Size = UDim2.new(1, 0, 0.48, 0)
	roleLabel.Font = Enum.Font.GothamMedium
	roleLabel.TextSize = 11
	roleLabel.TextColor3 = ChampionLooks.teamColor(team)
	roleLabel.TextStrokeTransparency = 0.45
	roleLabel.Text = role
	roleLabel.Parent = bb
end

local function buildFlair(
	folder: Folder,
	head: BasePart,
	torso: BasePart,
	look: ChampionLooks.LookDef,
	body: Color3,
	teamColor: Color3,
	rig: Rig
)
	local flair = look.flair
	local accent = look.accent
	local neon = look.neon
	local mat = look.material
	local earSize = Vector3.new(0.42, 0.62, 0.22) * look.earScale
	local _, leftEar = addPart(
		folder,
		head,
		"EarL",
		earSize,
		CFrame.new(-head.Size.X * 0.28, head.Size.Y * 0.38, 0.02) * CFrame.Angles(0, 0, 0.32),
		body:Lerp(accent, 0.15),
		mat
	)
	local _, rightEar = addPart(
		folder,
		head,
		"EarR",
		earSize,
		CFrame.new(head.Size.X * 0.28, head.Size.Y * 0.38, 0.02) * CFrame.Angles(0, 0, -0.32),
		body:Lerp(accent, 0.15),
		mat
	)
	addIdle(rig, leftEar, "ear", 0.2)
	addIdle(rig, rightEar, "ear", 1.1)

	local tailLen = look.tailLength
	if flair.rainbowTail then
		local colors = {
			Color3.fromRGB(255, 80, 80),
			Color3.fromRGB(255, 170, 50),
			Color3.fromRGB(255, 230, 70),
			Color3.fromRGB(80, 210, 110),
			Color3.fromRGB(80, 160, 255),
		}
		local prev: BasePart = torso
		local prevOffset = CFrame.new(0, -0.1, torso.Size.Z * 0.52)
		for i, stripe in colors do
			local seg, weld = addPart(
				folder,
				prev,
				`Rainbow{i}`,
				Vector3.new(0.28, 0.28, 0.42),
				if i == 1 then prevOffset else CFrame.new(0, 0, 0.4),
				stripe,
				Enum.Material.SmoothPlastic
			)
			if i == 1 then
				addIdle(rig, weld, "tail", 0)
			end
			prev = seg
		end
	else
		local _, tailWeld = addPart(
			folder,
			torso,
			"Tail",
			Vector3.new(0.32, 0.32, tailLen),
			CFrame.new(0, -torso.Size.Y * 0.12, torso.Size.Z * 0.45 + tailLen * 0.28) * CFrame.Angles(0.4, 0, 0),
			body:Lerp(accent, 0.25),
			mat
		)
		addIdle(rig, tailWeld, "tail", 0.4)
	end

	local collarColor = if flair.goldCollar then accent else teamColor
	addPart(
		folder,
		torso,
		"Collar",
		Vector3.new(torso.Size.X * 0.72, 0.14, torso.Size.Z * 0.72),
		CFrame.new(0, torso.Size.Y * 0.38, 0),
		collarColor,
		Enum.Material.SmoothPlastic
	)

	if flair.bowtie then
		addPart(folder, torso, "Bowtie", Vector3.new(0.55, 0.22, 0.18), CFrame.new(0, 0.55, -torso.Size.Z * 0.52), accent, mat)
	end
	if flair.rocket then
		local pack, packWeld = addPart(
			folder,
			torso,
			"Rocket",
			Vector3.new(0.7, 0.7, 1.1),
			CFrame.new(0, 0.1, torso.Size.Z * 0.7),
			accent,
			Enum.Material.Metal
		)
		addPart(folder, pack, "Nozzle", Vector3.new(0.35, 0.35, 0.4), CFrame.new(0, 0, 0.7), neon, Enum.Material.Neon)
		addLight(pack, neon, 0.55)
		addIdle(rig, packWeld, "bob", 0.6)
	end
	if flair.armor then
		addPart(folder, torso, "ChestPlate", Vector3.new(torso.Size.X * 0.95, torso.Size.Y * 0.55, 0.18), CFrame.new(0, 0.15, -torso.Size.Z * 0.52), accent, Enum.Material.Metal)
		addPart(folder, torso, "ShoulderL", Vector3.new(0.55, 0.35, 0.55), CFrame.new(-torso.Size.X * 0.55, 0.55, 0), accent, Enum.Material.Metal)
		addPart(folder, torso, "ShoulderR", Vector3.new(0.55, 0.35, 0.55), CFrame.new(torso.Size.X * 0.55, 0.55, 0), accent, Enum.Material.Metal)
	end
	if flair.visor then
		local visor = addPart(folder, head, "Visor", Vector3.new(head.Size.X * 0.85, 0.16, 0.22), CFrame.new(0, 0.05, -head.Size.Z * 0.48), neon, Enum.Material.Neon)
		addLight(visor, neon, 0.4)
	end
	if flair.glasses then
		addPart(folder, head, "LensL", Vector3.new(0.32, 0.32, 0.08), CFrame.new(-0.22, 0.04, -head.Size.Z * 0.5), accent, Enum.Material.Glass)
		addPart(folder, head, "LensR", Vector3.new(0.32, 0.32, 0.08), CFrame.new(0.22, 0.04, -head.Size.Z * 0.5), accent, Enum.Material.Glass)
		addPart(folder, head, "Bridge", Vector3.new(0.2, 0.06, 0.06), CFrame.new(0, 0.04, -head.Size.Z * 0.5), accent, mat)
	end
	if flair.grannyGlasses then
		addPart(folder, head, "LensL", Vector3.new(0.28, 0.28, 0.08), CFrame.new(-0.2, 0.02, -head.Size.Z * 0.5), accent, Enum.Material.Glass)
		addPart(folder, head, "LensR", Vector3.new(0.28, 0.28, 0.08), CFrame.new(0.2, 0.02, -head.Size.Z * 0.5), accent, Enum.Material.Glass)
	end
	if flair.shades then
		addPart(folder, head, "Shades", Vector3.new(head.Size.X * 0.8, 0.2, 0.16), CFrame.new(0, 0.06, -head.Size.Z * 0.5), accent, Enum.Material.SmoothPlastic)
	end
	if flair.mortar then
		addPart(folder, head, "Board", Vector3.new(1.35, 0.12, 1.35), CFrame.new(0, head.Size.Y * 0.55, 0), accent, mat)
		addPart(folder, head, "Tassel", Vector3.new(0.12, 0.55, 0.12), CFrame.new(0.55, head.Size.Y * 0.28, 0), neon, Enum.Material.Neon)
	end
	if flair.fedora then
		addPart(folder, head, "Brim", Vector3.new(1.5, 0.1, 1.5), CFrame.new(0, head.Size.Y * 0.42, 0), accent, mat)
		addPart(folder, head, "Crown", Vector3.new(0.95, 0.45, 0.95), CFrame.new(0, head.Size.Y * 0.62, 0.04), accent, mat)
	end
	if flair.shawl then
		addPart(folder, torso, "Shawl", Vector3.new(torso.Size.X * 1.15, 0.85, 0.16), CFrame.new(0, 0.35, -torso.Size.Z * 0.4) * CFrame.Angles(0.15, 0, 0), accent, mat)
	end
	if flair.bun then
		addPart(folder, head, "Bun", Vector3.new(0.55, 0.55, 0.55), CFrame.new(0, head.Size.Y * 0.42, 0.35), body, mat, Enum.PartType.Ball)
	end
	if flair.antenna then
		local stem, stemWeld = addPart(folder, head, "Antenna", Vector3.new(0.1, 0.9, 0.1), CFrame.new(0.15, head.Size.Y * 0.7, 0), accent, Enum.Material.Metal)
		local tip = addPart(folder, stem, "AntennaTip", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, 0.55, 0), neon, Enum.Material.Neon, Enum.PartType.Ball)
		addLight(tip, neon, 0.7)
		addIdle(rig, stemWeld, "bob", 0.9)
	end
	if flair.chestLight then
		local lamp = addPart(folder, torso, "ChestLight", Vector3.new(0.35, 0.35, 0.12), CFrame.new(0, 0.15, -torso.Size.Z * 0.55), neon, Enum.Material.Neon)
		addLight(lamp, neon, 0.55)
	end
	if flair.blades then
		addPart(folder, torso, "BladeL", Vector3.new(0.16, 0.9, 0.45), CFrame.new(-torso.Size.X * 0.62, 0.35, 0.1) * CFrame.Angles(0, 0, 0.4), accent, Enum.Material.Metal)
		addPart(folder, torso, "BladeR", Vector3.new(0.16, 0.9, 0.45), CFrame.new(torso.Size.X * 0.62, 0.35, 0.1) * CFrame.Angles(0, 0, -0.4), accent, Enum.Material.Metal)
	end
	if flair.hood then
		addPart(folder, head, "Hood", Vector3.new(head.Size.X * 1.25, head.Size.Y * 0.85, head.Size.Z * 1.15), CFrame.new(0, 0.22, 0.12), accent, mat)
	end
	if flair.cape then
		local _, capeWeld = addPart(
			folder,
			torso,
			"Cape",
			Vector3.new(torso.Size.X * 1.05, torso.Size.Y * 1.35, 0.12),
			CFrame.new(0, -0.15, torso.Size.Z * 0.62) * CFrame.Angles(0.2, 0, 0),
			accent,
			mat
		)
		addIdle(rig, capeWeld, "bob", 1.4)
	end
	if flair.wizardHat then
		addPart(folder, head, "HatBrim", Vector3.new(1.7, 0.1, 1.7), CFrame.new(0, head.Size.Y * 0.48, 0), accent, mat)
		addPart(folder, head, "HatCone", Vector3.new(0.85, 1.7, 0.85), CFrame.new(0, head.Size.Y * 1.15, 0), accent, mat)
		addPart(folder, head, "HatStar", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, head.Size.Y * 2.05, 0), neon, Enum.Material.Neon, Enum.PartType.Ball)
	end
	if flair.crystalHat then
		addPart(folder, head, "Crystal", Vector3.new(0.7, 1.1, 0.7), CFrame.new(0, head.Size.Y * 0.95, 0) * CFrame.Angles(0, 0.4, 0), neon, Enum.Material.Neon)
		addPart(folder, head, "RuneRing", Vector3.new(1.3, 0.08, 1.3), CFrame.new(0, head.Size.Y * 0.42, 0), accent, Enum.Material.Neon)
	end
	if flair.crest then
		addPart(folder, head, "Crest", Vector3.new(0.14, 0.7, 0.4), CFrame.new(0, head.Size.Y * 0.7, -0.05), accent, Enum.Material.Metal)
	end
	if flair.aura then
		local aura, auraWeld = addPart(
			folder,
			torso,
			"Aura",
			Vector3.new(3.2, 3.2, 3.2),
			CFrame.new(0, 0.2, 0),
			neon,
			Enum.Material.ForceField,
			Enum.PartType.Ball
		)
		aura.Transparency = 0.72
		aura.CanQuery = false
		addIdle(rig, auraWeld, "aura", 0)
	end
	if flair.orbs then
		for i, side in { -1, 1 } do
			local orb, orbWeld = addPart(
				folder,
				head,
				`Orb{i}`,
				Vector3.new(0.28, 0.28, 0.28),
				CFrame.new(side * 1.15, 0.35, 0.1),
				neon,
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
			addLight(orb, neon, 0.45)
			addIdle(rig, orbWeld, "orb", side * 1.2)
		end
	end
end

function ChampionAppearance.apply(model: Model, info: ApplyInfo)
	local champ = ChampionCatalog.get(info.championId)
	local look = ChampionLooks.get(info.championId)
	if not champ then
		return
	end
	local root = findPart(model, { "HumanoidRootPart" })
	local head = findPart(model, { "Head" })
	local torso = findPart(model, { "UpperTorso", "Torso", "HumanoidRootPart" })
	if not root or not head or not torso then
		return
	end

	local existing = model:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	rigs[model] = nil

	local body = ChampionLooks.tintedBody(look, info.team)
	hideAvatarAccessories(model)
	tintBody(model, look, body, info.isBot)

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = model

	local rig: Rig = { items = {} }
	buildFlair(folder, head, torso, look, body, ChampionLooks.teamColor(info.team), rig)
	rigs[model] = rig
	ensureLoop()

	local tall = look.flair.wizardHat == true or look.flair.crystalHat == true or look.flair.mortar == true
	attachNameplate(root, champ.name, champ.role, info.isBot, info.team, tall)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	end

	model:SetAttribute("MeoLookId", info.championId)
	if info.isBot and info.displayName ~= "" then
		model.Name = info.displayName
	end
end

function ChampionAppearance.applyMatchPlayer(model: Model, matchPlayer: Types.MatchPlayer)
	if typeof(matchPlayer.championId) ~= "string" then
		return
	end
	ChampionAppearance.apply(model, {
		championId = matchPlayer.championId,
		team = matchPlayer.team,
		displayName = matchPlayer.displayName,
		isBot = matchPlayer.isBot,
	})
end

return ChampionAppearance
