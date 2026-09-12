--!strict

-- Billboard + short Part bob for emotes. No animation binaries.

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
local BILLBOARD = 2.4
local BOB = 1.45

type Active = {
	userId: number,
	expiresAt: number,
	part: BasePart,
	gui: BillboardGui,
	motion: EmoteCatalog.EmoteMotion,
	seed: number,
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
				local s = 0.5 + math.abs(math.sin(t * 10)) * 0.35
				active.part.Size = Vector3.new(s, s, s)
			end
		end
	end)
end

function EmoteFx.play(event: Types.EmoteEvent, opts: { muteSfx: boolean }?)
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

	local part = Instance.new("Part")
	part.Name = "EmoteBob"
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = def.color
	part.Size = Vector3.new(0.55, 0.55, 0.55)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Transparency = 0.15
	part.CFrame = root.CFrame * CFrame.new(0, 2.2, 0)
	part.Parent = fxFolder()

	local gui = Instance.new("BillboardGui")
	gui.Name = "MeoEmote"
	gui.Size = UDim2.fromOffset(132, 52)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 96
	gui.Parent = root

	local label = Theme.text(gui, "Emote", `{def.emoji}  {def.label}`, 20, Theme.cream, Theme.fontTitle)
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Theme.panel
	label.BackgroundTransparency = 0.18
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextStrokeTransparency = 0.35
	Theme.corner(label, 12)
	Theme.stroke(label, def.color, 2, 0.15)

	actives[event.userId] = {
		userId = event.userId,
		expiresAt = os.clock() + math.max(BILLBOARD, BOB),
		part = part,
		gui = gui,
		motion = def.motion,
		seed = event.userId % 17,
	}

	task.delay(BILLBOARD, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

return EmoteFx
