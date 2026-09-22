--!strict

-- Billboard + short Part bob for emotes. Closet emoteFlair adds tint + sparkle.
-- No animation binaries.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local EmoteCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("EmoteCatalog"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local Theme = require(script.Parent.Parent.Theme)
local SoundIds = require(script.Parent.Parent.Audio.SoundIds)
local Sfx = require(script.Parent.Parent.Audio.Sfx)

local EmoteFx = {}

local FOLDER_NAME = "MeoEmoteFx"
local BILLBOARD = 2.55
local BOB = 1.55

type Active = {
	userId: number,
	expiresAt: number,
	part: BasePart,
	gui: BillboardGui,
	motion: EmoteCatalog.EmoteMotion,
	seed: number,
	flair: boolean,
}

local folder: Folder? = nil
local actives: { [number]: Active } = {}
local loopBound = false

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

local function modelOf(userId: number): Model?
	local localPlayer = Players.LocalPlayer
	if localPlayer and localPlayer.UserId == userId then
		return localPlayer.Character
	end
	for _, other in Players:GetPlayers() do
		if other.UserId == userId then
			return other.Character
		end
	end
	local map = Workspace:FindFirstChild(Constants.MapFolderName)
	local bots = if map then map:FindFirstChild("Bots") else nil
	if bots then
		for _, child in bots:GetChildren() do
			if child:IsA("Model") and child:GetAttribute(Constants.Attributes.UserId) == userId then
				return child
			end
		end
	end
	return nil
end

local function rootOf(userId: number): BasePart?
	local model = modelOf(userId)
	if not model then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

local function clear(userId: number)
	local active = actives[userId]
	if not active then
		return
	end
	actives[userId] = nil
	if active.part.Parent then
		active.part:Destroy()
	end
	if active.gui.Parent then
		active.gui:Destroy()
	end
end

local function motionOffset(motion: EmoteCatalog.EmoteMotion, t: number, seed: number): CFrame
	local spin = t * 8 + seed
	if motion == "nod" then
		return CFrame.new(0, 2.1 + math.sin(t * 14) * 0.18, 0)
	elseif motion == "puff" then
		return CFrame.new(0, 2.15, 0) * CFrame.Angles(0, spin * 0.4, 0)
	elseif motion == "float" then
		return CFrame.new(0, 2.25 + math.sin(t * 6) * 0.28, 0)
	elseif motion == "flex" then
		return CFrame.new(0, 2.35 + math.abs(math.sin(t * 9)) * 0.42, 0)
	elseif motion == "dance" then
		return CFrame.new(math.sin(t * 12) * 0.55, 2.15, 0) * CFrame.Angles(0, 0, math.sin(t * 12) * 0.4)
	elseif motion == "bounce" then
		return CFrame.new(0, 2.1 + math.abs(math.sin(t * 16)) * 0.5, 0)
	elseif motion == "droop" then
		return CFrame.new(0, 1.85 - math.abs(math.sin(t * 5)) * 0.15, 0)
	end
	return CFrame.new(0, 2.2, 0) * CFrame.Angles(0, spin, 0)
end

local function attachFlairSpark(part: BasePart, tint: Color3)
	local spark = Instance.new("ParticleEmitter")
	spark.Name = "FlairSpark"
	spark.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spark.Color = ColorSequence.new(tint)
	spark.LightEmission = 0.85
	spark.LightInfluence = 0
	spark.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.55, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})
	spark.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	spark.Lifetime = NumberRange.new(0.35, 0.7)
	spark.Speed = NumberRange.new(1.4, 3.6)
	spark.SpreadAngle = Vector2.new(180, 180)
	spark.Acceleration = Vector3.new(0, 2.4, 0)
	spark.RotSpeed = NumberRange.new(-90, 90)
	spark.Rate = 0
	spark.Enabled = false
	spark.Parent = part
	spark:Emit(18)
	task.delay(0.05, function()
		if spark.Parent then
			spark.Enabled = true
			spark.Rate = 14
		end
	end)
end

local function ensureLoop()
	if loopBound then
		return
	end
	loopBound = true
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for userId, active in actives do
			if now >= active.expiresAt then
				clear(userId)
				continue
			end
			local root = rootOf(userId)
			if not root then
				clear(userId)
				continue
			end
			local t = 1 - (active.expiresAt - now) / BOB
			local offset = motionOffset(active.motion, t * BOB, active.seed)
			active.part.CFrame = root.CFrame * offset
			if active.motion == "puff" then
				local base = if active.flair then 0.7 else 0.5
				local s = base + math.abs(math.sin(t * 10)) * (if active.flair then 0.42 else 0.35)
				active.part.Size = Vector3.new(s, s, s)
			elseif active.flair then
				local pulse = 0.92 + math.sin(t * 14) * 0.08
				active.part.Transparency = math.clamp(0.08 + (1 - pulse) * 0.2, 0.05, 0.35)
			end
		end
	end)
end

function EmoteFx.play(event: Types.EmoteEvent, opts: { muteSfx: boolean, tint: Color3? }?)
	local def = EmoteCatalog.get(event.emoteId)
	if not def then
		return
	end
	local root = rootOf(event.userId)
	if not root then
		return
	end
	clear(event.userId)
	ensureLoop()

	if not (opts and opts.muteSfx) then
		Sfx.play(def.cue :: SoundIds.Cue)
	end

	local tint = if opts then opts.tint else nil
	if tint == nil and typeof(event.flairTint) == "Color3" then
		tint = event.flairTint
	end
	local hasFlair = tint ~= nil
	-- Flair leads; keep a hint of the emote's own color so Meow still reads as Meow.
	local color = if tint then tint:Lerp(def.color, 0.28) else def.color
	local bob = if hasFlair then 0.88 else 0.55

	local part = Instance.new("Part")
	part.Name = "EmoteBob"
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(bob, bob, bob)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Transparency = if hasFlair then 0.08 else 0.15
	part.CFrame = root.CFrame * CFrame.new(0, 2.2, 0)
	part.Parent = fxFolder()

	if tint then
		attachFlairSpark(part, tint)
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "MeoEmote"
	gui.Size = UDim2.fromOffset(if hasFlair then 148 else 132, if hasFlair then 56 else 52)
	gui.StudsOffset = Vector3.new(0, 3.55, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 110
	gui.Parent = root

	local label = Theme.text(gui, "Emote", `{def.emoji}  {def.label}`, if hasFlair then 22 else 20, Theme.cream, Theme.fontTitle)
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Theme.panel
	label.BackgroundTransparency = if hasFlair then 0.08 else 0.18
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextStrokeTransparency = 0.3
	Theme.corner(label, 12)
	Theme.stroke(label, if tint then tint else color, if hasFlair then 3 else 2, if hasFlair then 0.05 else 0.15)

	actives[event.userId] = {
		userId = event.userId,
		expiresAt = os.clock() + math.max(BILLBOARD, BOB),
		part = part,
		gui = gui,
		motion = def.motion,
		seed = event.userId % 17,
		flair = hasFlair,
	}

	task.delay(BILLBOARD, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

return EmoteFx
