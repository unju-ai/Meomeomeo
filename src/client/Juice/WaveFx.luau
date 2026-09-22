--!strict

-- Lantern glow at a lane mouth just before that lane's kittens leave,
-- then a short cream puff when the first one steps out.
-- The clock is the stamp MinionService writes on the minion folder.
-- Fog still hides a mouth the viewer has not seen. Camps are not painted here.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local WaveJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WaveJuice"))

local WaveFx = {}

local FOLDER_NAME = "MeoWaveJuice"

type Live = {
	ball: BasePart,
	ring: BasePart,
	light: PointLight,
}

local folder: Folder? = nil
local glows: { [string]: Live } = {}
local puffed: { [string]: number } = {}
local loopBound = false
local allowed = false
local anchor: number? = nil
local schedule: WaveJuice.Schedule = WaveJuice.defaultSchedule()
local fogBits: { number }? = nil
local exploredBits: { number }? = nil

local function rgb(triple: { number }): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

local function root(): Folder
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

local function minionBin(): Folder?
	local map = Workspace:FindFirstChild(Constants.MapFolderName)
	if not map then
		return nil
	end
	local bin = map:FindFirstChild("Minions")
	if bin and bin:IsA("Folder") then
		return bin
	end
	return nil
end

local function readNumber(bin: Folder, name: string): number?
	local value = bin:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return nil
end

local function readClock(): (number?, WaveJuice.Schedule)
	local bin = minionBin()
	if not bin then
		return nil, WaveJuice.defaultSchedule()
	end
	local stamped = readNumber(bin, Constants.Attributes.WaveAnchor)
	if stamped == nil then
		return nil, WaveJuice.defaultSchedule()
	end
	local fallback = WaveJuice.defaultSchedule()
	return stamped, {
		firstDelay = readNumber(bin, Constants.Attributes.WaveFirst) or fallback.firstDelay,
		waveInterval = readNumber(bin, Constants.Attributes.WaveInterval) or fallback.waveInterval,
		perLane = readNumber(bin, Constants.Attributes.WavePerLane) or fallback.perLane,
		kittenStep = readNumber(bin, Constants.Attributes.WaveStep) or fallback.kittenStep,
	}
end

local function release(id: string)
	local live = glows[id]
	if not live then
		return
	end
	if live.ball.Parent then
		live.ball:Destroy()
	end
	if live.ring.Parent then
		live.ring:Destroy()
	end
	glows[id] = nil
end

local function releaseGlows()
	local ids: { string } = {}
	for id in glows do
		table.insert(ids, id)
	end
	for _, id in ids do
		release(id)
	end
end

local function styleGlow(live: Live, cue: WaveJuice.Cue)
	local cream = rgb(WaveJuice.Cream)
	local lantern = rgb(WaveJuice.Lantern)
	local alpha = cue.alpha
	local breathe = 0.5 + 0.5 * math.sin(os.clock() * 3.1 + alpha * 2)
	local span = 2.1 + alpha * 1.15 + breathe * 0.18
	local ground = Vector3.new(cue.x, 1.05, cue.z)

	live.ball.Color = cream
	live.ball.Size = Vector3.new(span, span * 0.7, span)
	live.ball.Transparency = 0.38 + (1 - breathe) * 0.22
	live.ball.CFrame = CFrame.new(ground + Vector3.new(0, 1.35 + alpha * 0.25, 0))

	local diameter = 3.6 + alpha * 2.2
	live.ring.Color = lantern
	live.ring.Size = Vector3.new(0.08, diameter, diameter)
	live.ring.Transparency = 0.42 + (1 - alpha) * 0.28
	live.ring.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))

	live.light.Brightness = 0.28 + alpha * 0.4
	live.light.Range = 10 + alpha * 4
end

local function ensureGlow(cue: WaveJuice.Cue): Live
	local existing = glows[cue.id]
	if existing and existing.ball.Parent and existing.ring.Parent then
		styleGlow(existing, cue)
		return existing
	end
	if existing then
		release(cue.id)
	end

	local cream = rgb(WaveJuice.Cream)
	local lantern = rgb(WaveJuice.Lantern)
	local ball = Instance.new("Part")
	ball.Name = `WaveGlow-{cue.id}`
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = cream
	ball.Parent = root()

	local light = Instance.new("PointLight")
	light.Name = "Lantern"
	light.Color = lantern
	light.Shadows = false
	light.Parent = ball

	local ring = Instance.new("Part")
	ring.Name = `WaveRing-{cue.id}`
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = lantern
	ring.Parent = root()

	local live: Live = {
		ball = ball,
		ring = ring,
		light = light,
	}
	glows[cue.id] = live
	styleGlow(live, cue)
	return live
end

local function puff(cue: WaveJuice.Cue)
	local cream = rgb(WaveJuice.Cream)
	local lantern = rgb(WaveJuice.Lantern)
	local ground = Vector3.new(cue.x, 1.1, cue.z)

	local ball = Instance.new("Part")
	ball.Name = "WaveArrival"
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.ForceField
	ball.Color = cream
	ball.Size = Vector3.new(2.6, 1.8, 2.6)
	ball.Transparency = 0.32
	ball.CFrame = CFrame.new(ground + Vector3.new(0, 1.15, 0))
	ball.Parent = root()

	local ring = Instance.new("Part")
	ring.Name = "WaveArrivalRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.ForceField
	ring.Color = lantern
	ring.Size = Vector3.new(0.07, 4.2, 4.2)
	ring.Transparency = 0.36
	ring.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = root()

	task.delay(WaveJuice.ArrivalSeconds, function()
		if ball.Parent then
			ball:Destroy()
		end
		if ring.Parent then
			ring:Destroy()
		end
	end)
end

local function currentRows(now: number): { WaveJuice.Cue }
	if not allowed or anchor == nil then
		return {}
	end
	local elapsed = now - anchor
	return WaveJuice.visible(WaveJuice.cues(elapsed, schedule), fogBits, exploredBits)
end

local function paint(now: number)
	if not allowed or anchor == nil then
		releaseGlows()
		return
	end
	local elapsed = now - anchor
	local rows = currentRows(now)
	local keep: { [string]: boolean } = {}
	for _, cue in rows do
		if cue.kind == "telegraph" then
			keep[cue.id] = true
			ensureGlow(cue)
		elseif cue.kind == "arrival" then
			release(cue.id)
			local key = `{cue.id}@{string.format("%.3f", cue.depart)}`
			if puffed[key] == nil then
				puffed[key] = cue.depart
				puff(cue)
			end
		end
	end
	local stale: { string } = {}
	for id in glows do
		if not keep[id] then
			table.insert(stale, id)
		end
	end
	for _, id in stale do
		release(id)
	end
	local forget: { string } = {}
	for key, depart in puffed do
		if elapsed > depart + WaveJuice.ArrivalSeconds + 1 then
			table.insert(forget, key)
		end
	end
	for _, key in forget do
		puffed[key] = nil
	end
end

local function bind()
	if loopBound then
		return
	end
	loopBound = true
	RunService.Heartbeat:Connect(function()
		if not allowed then
			return
		end
		paint(Workspace:GetServerTimeNow())
	end)
end

function WaveFx.clear()
	allowed = false
	anchor = nil
	fogBits = nil
	exploredBits = nil
	releaseGlows()
	table.clear(puffed)
	if folder and folder.Parent then
		folder:Destroy()
	end
	folder = nil
end

-- `allowed` is the Cat Rift fight gate. Fog bits are the viewer's current mask.
-- Returns the mouths that may blink this instant (telegraph and arrival).
function WaveFx.sync(isAllowed: boolean, nextFog: { number }?, nextExplored: { number }?): { WaveJuice.Cue }
	if not isAllowed then
		WaveFx.clear()
		return {}
	end
	allowed = true
	fogBits = nextFog
	exploredBits = nextExplored
	local stamped, nextSchedule = readClock()
	anchor = stamped
	schedule = nextSchedule
	if anchor == nil then
		releaseGlows()
		return {}
	end
	bind()
	local now = Workspace:GetServerTimeNow()
	paint(now)
	return currentRows(now)
end

return WaveFx
