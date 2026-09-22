--!strict

-- Client-only last-seen silhouettes for Cat Rift fog.
-- A ghost is spawned once from the pose captured while the unit was visible,
-- parented under MeoLastSeen (not the live model), and then only fades.
-- Heartbeat never reads the live body, so the ghost cannot chase it.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LastSeenGhostLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LastSeenGhostLogic"))

local LastSeenGhosts = {}

local FOLDER_NAME = "MeoLastSeen"

local DROP: { [string]: boolean } = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
	Humanoid = true,
	Animator = true,
	AnimationController = true,
	BillboardGui = true,
	SurfaceGui = true,
	Highlight = true,
	SelectionBox = true,
	ClickDetector = true,
	ProximityPrompt = true,
	ParticleEmitter = true,
	Trail = true,
	Beam = true,
	Fire = true,
	Smoke = true,
	Sparkles = true,
	Sound = true,
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
}

type FadeEntry = {
	inst: Instance,
	base: number,
}

type Visual = {
	root: Instance,
	fades: { FadeEntry },
	born: number,
}

local state = LastSeenGhostLogic.newState()
local visuals: { [string]: Visual } = {}
local folder: Folder? = nil
local heartbeat: RBXScriptConnection? = nil

local function ensureFolder(): Folder
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

local function lockPart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.LocalTransparencyModifier = 0
end

local function clearAttributes(inst: Instance)
	local names = {}
	for name in pairs(inst:GetAttributes()) do
		table.insert(names, name)
	end
	for _, name in names do
		inst:SetAttribute(name, nil)
	end
end

local function sanitize(root: Instance)
	local dropping: { Instance } = {}
	for _, inst in root:GetDescendants() do
		if DROP[inst.ClassName] then
			table.insert(dropping, inst)
		end
	end
	local function scrub(inst: Instance)
		if DROP[inst.ClassName] then
			return
		end
		if inst:IsA("BasePart") then
			lockPart(inst)
		end
		clearAttributes(inst)
	end
	scrub(root)
	for _, inst in root:GetDescendants() do
		scrub(inst)
	end
	for _, inst in dropping do
		if inst.Parent then
			inst:Destroy()
		end
	end
	if root:IsA("BasePart") then
		lockPart(root)
	end
	for _, inst in root:GetDescendants() do
		if inst:IsA("BasePart") then
			lockPart(inst)
		end
	end
end

local function canFade(inst: Instance): boolean
	return inst:IsA("BasePart") or inst:IsA("Decal") or inst:IsA("Texture")
end

local function applyTransparency(inst: Instance, value: number)
	if canFade(inst) then
		local fade = inst :: any
		fade.Transparency = value
	end
end

local function readTransparency(inst: Instance): number?
	if canFade(inst) then
		local fade = inst :: any
		return fade.Transparency
	end
	return nil
end

local function collectFades(root: Instance): { FadeEntry }
	local fades: { FadeEntry } = {}
	local function consider(inst: Instance)
		local base = readTransparency(inst)
		if base ~= nil then
			table.insert(fades, { inst = inst, base = base })
		end
	end
	consider(root)
	for _, child in root:GetDescendants() do
		consider(child)
	end
	return fades
end

local function poseToCFrame(pose: LastSeenGhostLogic.Pose): CFrame
	return CFrame.new(
		pose.x,
		pose.y,
		pose.z,
		pose.r00,
		pose.r01,
		pose.r02,
		pose.r10,
		pose.r11,
		pose.r12,
		pose.r20,
		pose.r21,
		pose.r22
	)
end

local function place(root: Instance, pose: LastSeenGhostLogic.Pose)
	local cf = poseToCFrame(pose)
	if root:IsA("Model") then
		root:PivotTo(cf)
	elseif root:IsA("BasePart") then
		root.CFrame = cf
	end
end

local function capture(source: Instance): LastSeenGhostLogic.Pose?
	local cf: CFrame
	if source:IsA("Model") then
		cf = source:GetPivot()
	elseif source:IsA("BasePart") then
		cf = source.CFrame
	else
		return nil
	end
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return LastSeenGhostLogic.pose(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

local function destroyVisual(key: string)
	local visual = visuals[key]
	if not visual then
		return
	end
	visuals[key] = nil
	visual.root:Destroy()
end

local function ensureHeartbeat()
	if heartbeat then
		return
	end
	heartbeat = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local due = LastSeenGhostLogic.expireDue(state, now)
		for _, key in due do
			destroyVisual(key)
		end
		for _, visual in visuals do
			local age = now - visual.born
			for _, entry in visual.fades do
				applyTransparency(entry.inst, LastSeenGhostLogic.partTransparency(entry.base, age))
			end
		end
		if next(visuals) == nil and heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
	end)
end

local function build(key: string, source: Instance, pose: LastSeenGhostLogic.Pose, born: number)
	if not (source:IsA("Model") or source:IsA("BasePart")) then
		return
	end
	if source.Parent == nil then
		return
	end
	local cloned = source:Clone()
	if cloned == nil then
		return
	end
	local clone = cloned
	clone.Name = "LastSeenGhost"
	sanitize(clone)
	-- Pose before parenting so the clone is never in the world at the live position.
	place(clone, pose)
	local fades = collectFades(clone)
	for _, entry in fades do
		applyTransparency(entry.inst, LastSeenGhostLogic.partTransparency(entry.base, 0))
	end
	clone.Parent = ensureFolder()
	visuals[key] = {
		root = clone,
		fades = fades,
		born = born,
	}
	ensureHeartbeat()
end

function LastSeenGhosts.seen(key: string, source: Instance)
	destroyVisual(key)
	local pose = capture(source)
	if pose then
		LastSeenGhostLogic.seen(state, key, pose)
	else
		LastSeenGhostLogic.recall(state, key)
	end
end

function LastSeenGhosts.lost(key: string, source: Instance)
	local now = os.clock()
	local fresh = LastSeenGhostLogic.lost(state, key, now)
	-- An existing ghost stays where it was spawned. Do not rebuild from the live source.
	if visuals[key] then
		return
	end
	local pose = fresh or LastSeenGhostLogic.ghostOf(state, key)
	local born = LastSeenGhostLogic.bornAt(state, key)
	if not pose or born == nil then
		return
	end
	build(key, source, pose, born)
end

function LastSeenGhosts.clear()
	LastSeenGhostLogic.clear(state)
	local keys = {}
	for key in visuals do
		table.insert(keys, key)
	end
	for _, key in keys do
		destroyVisual(key)
	end
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
end

return LastSeenGhosts
