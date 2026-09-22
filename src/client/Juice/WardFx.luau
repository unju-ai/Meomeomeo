--!strict

-- Client paint for wards the server already placed.
-- Place: a replicated part whose MeoPlacedAt is still inside the place window,
-- and whose cue is paintable (ally, or an enemy id already in the vision list).
-- Near expire: MeoExpiresAt drives a fade and pulse. The part leaving the folder
-- plays the pop only if we were showing it. A hidden expire stays quiet.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local WardJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WardJuice"))

local WardFx = {}

local FOLDER_NAME = "MeoWardJuice"

type Live = {
	shown: boolean,
	position: Vector3,
	cue: string,
	kind: string,
	parts: { BasePart },
}

local allowed = false
local userId = 0
local myTeam: string? = nil
local visible: { [string]: boolean } = {}
local lives: { [string]: Live } = {}
local puffed: { [string]: boolean } = {}
local toasted: { [string]: boolean } = {}
local transient: { BasePart } = {}
local fxFolder: Folder? = nil
local loopBound = false

local function rgb(triple: { number }): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

local function fx(): Folder
	if fxFolder and fxFolder.Parent then
		return fxFolder
	end
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		fxFolder = existing
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = Workspace
	fxFolder = created
	return created
end

local function numAttr(part: BasePart, name: string): number?
	local value = part:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return nil
end

local function ownerOf(part: BasePart): number?
	local value = part:GetAttribute(Constants.Attributes.UserId)
	if typeof(value) == "number" then
		return value
	end
	return nil
end

local function kindOf(part: BasePart): string
	local value = part:GetAttribute(Constants.Attributes.WardKind)
	if typeof(value) == "string" then
		return value
	end
	return "trinket"
end

local function dropParts(parts: { BasePart })
	for _, part in parts do
		if part.Parent then
			part:Destroy()
		end
	end
end

local function hold(part: BasePart, seconds: number)
	table.insert(transient, part)
	task.delay(seconds, function()
		if part.Parent then
			part:Destroy()
		end
	end)
end

local function prep(part: BasePart, color: Color3, transparency: number)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function makePart(name: string, shape: Enum.PartType, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Parent = parent
	return part
end

local function build(anchor: BasePart, cue: string, kind: string): { BasePart }
	local poleColor, lanternColor, yarnColor = WardJuice.palette(cue, kind)
	local scale = WardJuice.scale(cue)
	local pole = makePart("MeoWardPole", Enum.PartType.Cylinder, anchor)
	local lantern = makePart("MeoWardLantern", Enum.PartType.Ball, anchor)
	local yarn = makePart("MeoWardBob", Enum.PartType.Ball, anchor)
	local ring = makePart("MeoWardRing", Enum.PartType.Cylinder, anchor)
	prep(pole, rgb(poleColor), 0.2)
	prep(lantern, rgb(lanternColor), 0.15)
	prep(yarn, rgb(yarnColor), 0.18)
	prep(ring, rgb(poleColor), 0.45)
	local head = (if kind == "control" then 0.95 else 0.72) * scale
	pole.Size = Vector3.new(1.7 * scale, 0.22 * scale, 0.22 * scale)
	lantern.Size = Vector3.new(head, head, head)
	yarn.Size = Vector3.new(0.48 * scale, 0.48 * scale, 0.48 * scale)
	local ringSpan = (if kind == "control" then 2.5 else 2.05) * scale
	ring.Size = Vector3.new(0.1, ringSpan, ringSpan)
	return { pole, lantern, yarn, ring }
end

local function layout(parts: { BasePart }, at: Vector3, cue: string, kind: string, clock: number)
	local bob = WardJuice.bobOffset(clock)
	local headLift = if kind == "control" then 2.05 else 2.4
	local ringDrop = if kind == "control" then 1.15 else 1.5
	local spin = 0.62 * WardJuice.scale(cue)
	local angle = clock * WardJuice.BobSpeed
	local pole = parts[1]
	local lantern = parts[2]
	local yarn = parts[3]
	local ring = parts[4]
	pole.CFrame = CFrame.new(at + Vector3.new(0, headLift * 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90))
	lantern.CFrame = CFrame.new(at + Vector3.new(0, headLift + bob * 0.35, 0))
	yarn.CFrame = CFrame.new(at + Vector3.new(math.cos(angle) * spin, headLift + bob, math.sin(angle) * spin))
	ring.CFrame = CFrame.new(at - Vector3.new(0, ringDrop, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

local function applyLook(live: Live, expiresAt: number?, serverNow: number, clock: number)
	local transparency = WardJuice.bodyTransparency(live.cue, expiresAt, serverNow)
	local pulse = WardJuice.pulseScale(expiresAt, serverNow)
	local head = (if live.kind == "control" then 0.95 else 0.72) * WardJuice.scale(live.cue) * pulse
	for index, part in live.parts do
		if part.Parent then
			local extra = if index == 4 then 0.22 else 0
			part.Transparency = math.clamp(transparency + extra, 0, 0.92)
		end
	end
	local lantern = live.parts[2]
	if lantern and lantern.Parent then
		lantern.Size = Vector3.new(head, head, head)
	end
	layout(live.parts, live.position, live.cue, live.kind, clock)
end

local function puff(at: Vector3, cue: string, kind: string)
	local _, lanternColor, yarnColor = WardJuice.palette(cue, kind)
	local color = rgb(if cue == "enemy" then WardJuice.Pink else lanternColor)
	local burst = makePart("WardPuff", Enum.PartType.Ball, fx())
	prep(burst, color, 0.35)
	burst.Size = Vector3.new(1.1, 1.1, 1.1)
	burst.CFrame = CFrame.new(at + Vector3.new(0, 1.4, 0))
	hold(burst, WardJuice.PuffSeconds)
	local disc = makePart("WardPuffRing", Enum.PartType.Cylinder, fx())
	prep(disc, rgb(WardJuice.Cream), 0.4)
	disc.Size = Vector3.new(0.12, 1.6, 1.6)
	disc.CFrame = CFrame.new(at.X, at.Y - 0.8, at.Z) * CFrame.Angles(0, 0, math.rad(90))
	hold(disc, WardJuice.PuffSeconds)
	task.delay(0.06, function()
		if burst.Parent then
			burst.Size = Vector3.new(2.2, 2.2, 2.2)
			burst.Transparency = 0.72
		end
		if disc.Parent then
			disc.Size = Vector3.new(0.08, 3.4, 3.4)
			disc.Transparency = 0.78
		end
	end)
	for i = 1, 4 do
		local bit = makePart("WardPuffBit", Enum.PartType.Ball, fx())
		prep(bit, rgb(yarnColor), 0.2)
		bit.Size = Vector3.new(0.28, 0.28, 0.28)
		local angle = (i / 4) * math.pi * 2
		bit.CFrame = CFrame.new(at + Vector3.new(math.cos(angle) * 0.8, 1.6, math.sin(angle) * 0.8))
		hold(bit, WardJuice.PuffSeconds)
	end
end

local function toastFloat(at: Vector3, kind: string)
	local anchor = makePart("WardToast", Enum.PartType.Ball, fx())
	prep(anchor, rgb(WardJuice.Cream), 1)
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(at + Vector3.new(0, 2.6, 0))
	local gui = Instance.new("BillboardGui")
	gui.Name = "Toast"
	gui.Size = UDim2.fromOffset(180, 28)
	gui.StudsOffset = Vector3.new(0, 1.1, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = rgb(WardJuice.Cream)
	label.TextStrokeColor3 = rgb(WardJuice.Ink)
	label.TextStrokeTransparency = 0.45
	label.Text = WardJuice.plantLine(kind)
	label.Parent = gui
	hold(anchor, WardJuice.ToastSeconds)
end

local function pop(at: Vector3, cue: string)
	local color = rgb(if cue == "enemy" then WardJuice.Pink else WardJuice.Amber)
	local ring = makePart("WardPop", Enum.PartType.Cylinder, fx())
	prep(ring, color, 0.25)
	ring.Size = Vector3.new(0.14, 1.4, 1.4)
	ring.CFrame = CFrame.new(at.X, at.Y + 0.4, at.Z) * CFrame.Angles(0, 0, math.rad(90))
	hold(ring, WardJuice.PopSeconds)
	task.delay(0.05, function()
		if ring.Parent then
			ring.Size = Vector3.new(0.08, 3.6, 3.6)
			ring.Transparency = 0.82
		end
	end)
	for i = 1, 6 do
		local bit = makePart("WardPopBit", Enum.PartType.Ball, fx())
		prep(bit, rgb(if cue == "enemy" then WardJuice.Pink else WardJuice.Cream), 0.1)
		bit.Size = Vector3.new(0.32, 0.32, 0.32)
		local angle = (i / 6) * math.pi * 2
		bit.CFrame = CFrame.new(at + Vector3.new(math.cos(angle) * 0.7, 1.2, math.sin(angle) * 0.7))
		hold(bit, WardJuice.PopSeconds)
	end
end

local function cueFor(part: BasePart): string
	local teamAttr = part:GetAttribute(Constants.Attributes.Team)
	local same = myTeam ~= nil and teamAttr == myTeam
	return WardJuice.cueKind(userId, ownerOf(part), same, visible[part.Name] == true)
end

local function step(clock: number)
	if not allowed then
		return
	end
	local serverNow = Workspace:GetServerTimeNow()
	local map = Workspace:FindFirstChild(Constants.MapFolderName)
	local wards = if map then map:FindFirstChild("Wards") else nil
	local seen: { [string]: boolean } = {}
	if wards then
		for _, child in wards:GetChildren() do
			if child:IsA("BasePart") then
				local id = child.Name
				seen[id] = true
				local cue = cueFor(child)
				local kind = kindOf(child)
				local placedAt = numAttr(child, Constants.Attributes.PlacedAt)
				local expiresAt = numAttr(child, Constants.Attributes.ExpiresAt)
				local live = lives[id]
				if not WardJuice.shouldPaint(cue) then
					if live then
						dropParts(live.parts)
						live.parts = {}
						live.shown = false
					end
				else
					if not live then
						live = {
							shown = false,
							position = child.Position,
							cue = cue,
							kind = kind,
							parts = {},
						}
						lives[id] = live
					end
					if #live.parts == 0 or live.cue ~= cue or live.kind ~= kind then
						dropParts(live.parts)
						live.parts = build(child, cue, kind)
						live.cue = cue
						live.kind = kind
					end
					live.shown = true
					live.position = child.Position
					applyLook(live, expiresAt, serverNow, clock)
					if WardJuice.shouldPuff(cue, placedAt, serverNow, puffed[id] == true) then
						puffed[id] = true
						puff(child.Position, cue, kind)
					end
					if WardJuice.wantsToast(cue) and toasted[id] ~= true and WardJuice.placeFresh(placedAt, serverNow) then
						toasted[id] = true
						toastFloat(child.Position, kind)
					end
				end
			end
		end
	end
	local gone: { string } = {}
	for id, live in lives do
		if not seen[id] then
			if WardJuice.shouldPop(live.shown) then
				pop(live.position, live.cue)
			end
			dropParts(live.parts)
			table.insert(gone, id)
		end
	end
	for _, id in gone do
		lives[id] = nil
	end
	if #transient > 0 then
		local fresh: { BasePart } = {}
		for _, part in transient do
			if part.Parent then
				table.insert(fresh, part)
			end
		end
		table.clear(transient)
		for _, part in fresh do
			table.insert(transient, part)
		end
	end
end

local function ensureLoop()
	if loopBound then
		return
	end
	loopBound = true
	RunService.Heartbeat:Connect(function()
		step(os.clock())
	end)
end

function WardFx.sync(localUserId: number, team: string?, wardIds: { string })
	allowed = true
	userId = localUserId
	myTeam = team
	table.clear(visible)
	for _, id in wardIds do
		visible[id] = true
	end
	step(os.clock())
	ensureLoop()
end

function WardFx.clear()
	allowed = false
	myTeam = nil
	table.clear(visible)
	table.clear(puffed)
	table.clear(toasted)
	for _, live in lives do
		dropParts(live.parts)
	end
	table.clear(lives)
	for _, part in transient do
		if part.Parent then
			part:Destroy()
		end
	end
	table.clear(transient)
	if fxFolder and fxFolder.Parent then
		fxFolder:Destroy()
	end
	fxFolder = nil
end

return WardFx
