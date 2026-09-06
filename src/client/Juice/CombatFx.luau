--!strict

-- World VFX for confirmed casts / hits. Engine Parts, Beams, and one-shot
-- ParticleEmitters only. Short-lived, pooled, AA sparks debounced.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local Theme = require(script.Parent.Parent.Theme)

local CombatFx = {}

local FOLDER_NAME = "MeoFx"
local POOL_CAP = 28
local AA_DEBOUNCE = 0.14
local HEAL_DEBOUNCE = 0.2

type Follow = {
	kind: string,
	userId: number,
	parts: { BasePart },
	until: number,
	offset: number,
}

local folder: Folder? = nil
local pool: { BasePart } = {}
local follows: { [string]: Follow } = {}
local lastAaAt: { [string]: number } = {}
local lastHealAt: { [string]: number } = {}
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

local function resetPart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Transparency = 1
	part.Size = Vector3.new(0.4, 0.4, 0.4)
	part.CFrame = CFrame.new(0, -50, 0)
	local spark = part:FindFirstChild("Spark")
	if spark and spark:IsA("ParticleEmitter") then
		spark.Enabled = false
		spark.Rate = 0
	end
	local beam = part:FindFirstChild("Bolt")
	if beam and beam:IsA("Beam") then
		beam.Enabled = false
	end
end

local function takePart(name: string): BasePart
	local part = table.remove(pool)
	if not part then
		part = Instance.new("Part")
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Material = Enum.Material.Neon
		local spark = Instance.new("ParticleEmitter")
		spark.Name = "Spark"
		spark.Rate = 0
		spark.Enabled = false
		spark.Lifetime = NumberRange.new(0.12, 0.24)
		spark.Speed = NumberRange.new(3, 9)
		spark.SpreadAngle = Vector2.new(50, 50)
		spark.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.28),
			NumberSequenceKeypoint.new(1, 0),
		})
		spark.LightEmission = 0.75
		spark.Parent = part
	end
	part.Name = name
	resetPart(part)
	part.Parent = fxFolder()
	return part
end

local function release(part: BasePart, after: number)
	task.delay(after, function()
		if not part.Parent then
			return
		end
		resetPart(part)
		if #pool >= POOL_CAP then
			part:Destroy()
			return
		end
		part.Parent = nil
		table.insert(pool, part)
	end)
end

local function emitSpark(part: BasePart, color: Color3, count: number)
	local spark = part:FindFirstChild("Spark")
	if spark and spark:IsA("ParticleEmitter") then
		spark.Color = ColorSequence.new(color)
		spark:Emit(count)
	end
end

local function teamColor(team: Types.TeamId?): Color3
	if team == "Blue" then
		return Theme.blue
	elseif team == "Red" then
		return Theme.red
	end
	return Theme.amber
end

local function abilityColor(kind: Types.AbilityKind?): Color3
	if kind == "heal" then
		return Theme.mint
	elseif kind == "shield" then
		return Theme.amber
	elseif kind == "stun" then
		return Theme.warn
	elseif kind == "dash" then
		return Color3.fromRGB(160, 220, 255)
	end
	return Theme.coral
end

local function flashPart(part: BasePart, color: Color3, transparency: number)
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
end

local function placeRing(at: Vector3, radius: number, color: Color3, life: number)
	local part = takePart("Ring")
	local size = math.max(radius * 2, 5)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.22, size, size)
	part.CFrame = CFrame.new(at.X, at.Y + 0.18, at.Z) * CFrame.Angles(0, 0, math.rad(90))
	flashPart(part, color, 0.35)
	task.delay(0.05, function()
		if part.Parent then
			part.Size = Vector3.new(0.16, size * 1.08, size * 1.08)
			part.Transparency = 0.55
		end
	end)
	release(part, life)
end

local function placeBeam(origin: Vector3, dest: Vector3, color: Color3, width: number, life: number)
	local flat = Vector3.new(dest.X - origin.X, 0, dest.Z - origin.Z)
	local mag = flat.Magnitude
	local length = math.max(mag, 2)
	local dir = if mag > 0.2 then flat.Unit else Vector3.new(1, 0, 0)
	local mid = origin + dir * (length / 2)
	local look = origin + dir
	local part = takePart("Beam")
	part.Shape = Enum.PartType.Block
	part.Size = Vector3.new(math.max(width, 1.2), 0.28, length)
	part.CFrame = CFrame.lookAt(
		Vector3.new(mid.X, origin.Y + 0.45, mid.Z),
		Vector3.new(look.X, origin.Y + 0.45, look.Z)
	)
	flashPart(part, color, 0.25)
	release(part, life)
end

local function placeBurst(at: Vector3, color: Color3, scale: number, life: number)
	local part = takePart("Burst")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(scale, scale, scale)
	part.CFrame = CFrame.new(at + Vector3.new(0, 1.2, 0))
	part.Material = Enum.Material.ForceField
	part.Color = color
	part.Transparency = 0.35
	emitSpark(part, color, 6)
	task.delay(0.08, function()
		if part.Parent then
			part.Size = Vector3.new(scale * 1.35, scale * 1.35, scale * 1.35)
			part.Transparency = 0.7
		end
	end)
	release(part, life)
end

local function clearFollow(key: string)
	local follow = follows[key]
	if not follow then
		return
	end
	follows[key] = nil
	for _, part in follow.parts do
		release(part, 0.02)
	end
end

local function ensureLoop()
	if loopBound then
		return
	end
	loopBound = true
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for key, follow in follows do
			if now >= follow.until then
				clearFollow(key)
				continue
			end
			local root = rootOf(follow.userId)
			if not root then
				clearFollow(key)
				continue
			end
			if follow.kind == "recall" then
				local ring = follow.parts[1]
				if ring then
					ring.CFrame = CFrame.new(root.Position.X, root.Position.Y - 2.15, root.Position.Z)
						* CFrame.Angles(0, 0, math.rad(90))
				end
			elseif follow.kind == "shield" then
				local bubble = follow.parts[1]
				if bubble then
					bubble.CFrame = root.CFrame
				end
			elseif follow.kind == "stun" then
				local spin = now * 5 + follow.offset
				for i, star in follow.parts do
					local angle = spin + (i - 1) * (math.pi * 2 / #follow.parts)
					star.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(angle) * 1.35, 2.15, math.sin(angle) * 1.35))
				end
			end
		end
	end)
end

local function followRecall(userId: number, duration: number)
	local key = `recall:{userId}`
	if duration <= 0 then
		clearFollow(key)
		return
	end
	clearFollow(key)
	local ring = takePart("Recall")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.16, 6.4, 6.4)
	flashPart(ring, Theme.mint, 0.4)
	follows[key] = {
		kind = "recall",
		userId = userId,
		parts = { ring },
		until = os.clock() + duration,
		offset = 0,
	}
	ensureLoop()
end

local function followShield(userId: number, at: Vector3, duration: number)
	local key = `shield:{userId}`
	clearFollow(key)
	local bubble = takePart("Shield")
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(4.2, 4.2, 4.2)
	bubble.Material = Enum.Material.ForceField
	bubble.Color = Theme.amber
	bubble.Transparency = 0.45
	bubble.CFrame = CFrame.new(at)
	follows[key] = {
		kind = "shield",
		userId = userId,
		parts = { bubble },
		until = os.clock() + duration,
		offset = 0,
	}
	ensureLoop()
end

local function followStun(userId: number, duration: number)
	local key = `stun:{userId}`
	clearFollow(key)
	local stars = {}
	for i = 1, 3 do
		local star = takePart(`Stun{i}`)
		star.Shape = Enum.PartType.Ball
		star.Size = Vector3.new(0.28, 0.28, 0.28)
		flashPart(star, Theme.warn, 0.1)
		table.insert(stars, star)
	end
	follows[key] = {
		kind = "stun",
		userId = userId,
		parts = stars,
		until = os.clock() + math.max(duration, 0.35),
		offset = os.clock(),
	}
	ensureLoop()
end

local function playAbility(event: Types.CombatFxEvent)
	local color = abilityColor(event.abilityKind)
	local origin = event.origin
	local dest = event.dest or origin
	local radius = event.radius or 10
	local mode = event.mode
	if mode == "line" then
		placeBeam(origin, dest, color, math.max((event.radius or 6) * 1.4, 2), 0.28)
		placeBurst(dest, color, 1.6, 0.22)
	elseif mode == "dash" then
		placeBeam(origin, dest, color, 2.1, 0.22)
		placeBurst(dest, color, 1.8, 0.2)
	elseif event.abilityKind == "heal" or event.abilityKind == "shield" then
		placeRing(dest, radius, color, 0.32)
		placeBurst(origin, color, 2.2, 0.28)
	else
		placeRing(dest, radius, color, 0.34)
		placeBurst(dest, color, 2, 0.24)
	end
end

local function playAa(event: Types.CombatFxEvent)
	local color = teamColor(event.team)
	local dest = event.dest or event.origin
	local claw = takePart("Claw")
	claw.Shape = Enum.PartType.Block
	claw.Size = Vector3.new(0.18, 0.7, 1.1)
	local look = dest
	if (dest - event.origin).Magnitude < 0.4 then
		look = event.origin + Vector3.new(1, 0, 0)
	end
	claw.CFrame = CFrame.lookAt(event.origin + Vector3.new(0, 1.1, 0), look + Vector3.new(0, 1.1, 0))
	flashPart(claw, color, 0.15)
	release(claw, 0.12)

	local key = `{event.userId or 0}:{math.floor(dest.X / 5)}:{math.floor(dest.Z / 5)}`
	local now = os.clock()
	if now - (lastAaAt[key] or 0) < AA_DEBOUNCE then
		return
	end
	lastAaAt[key] = now
	local spark = takePart("Hit")
	spark.Shape = Enum.PartType.Ball
	spark.Size = Vector3.new(0.55, 0.55, 0.55)
	spark.CFrame = CFrame.new(dest + Vector3.new(0, 1.3, 0))
	flashPart(spark, Theme.cream, 0.2)
	emitSpark(spark, color, 8)
	release(spark, 0.18)
end

local function playTowerShot(event: Types.CombatFxEvent)
	local dest = event.dest or event.origin
	local color = teamColor(event.team)
	placeBeam(event.origin, dest, color, 1.4, 0.16)
	local bolt = takePart("Bolt")
	bolt.Shape = Enum.PartType.Ball
	bolt.Size = Vector3.new(0.7, 0.7, 0.7)
	bolt.CFrame = CFrame.new(event.origin + Vector3.new(0, 4, 0))
	flashPart(bolt, color, 0.05)
	bolt.CFrame = CFrame.new(dest + Vector3.new(0, 1.4, 0))
	emitSpark(bolt, color, 7)
	release(bolt, 0.2)
end

local function playStructureDeath(event: Types.CombatFxEvent)
	local scale = if event.structureKind == "Nexus" then 1.5 else 1
	placeBurst(event.origin, Theme.peach, 3.2 * scale, 0.4)
	for i = 1, 6 do
		local puff = takePart(`Puff{i}`)
		local angle = (i / 6) * math.pi * 2
		puff.Shape = Enum.PartType.Ball
		puff.Size = Vector3.new(1.1, 1.1, 1.1) * scale
		puff.CFrame = CFrame.new(event.origin + Vector3.new(math.cos(angle) * 3 * scale, 2, math.sin(angle) * 3 * scale))
		flashPart(puff, Theme.amber, 0.25)
		release(puff, 0.42)
	end
end

function CombatFx.play(event: Types.CombatFxEvent)
	if event.kind == "ability" then
		playAbility(event)
	elseif event.kind == "aa" then
		playAa(event)
	elseif event.kind == "towerShot" then
		playTowerShot(event)
	elseif event.kind == "structureDeath" then
		playStructureDeath(event)
	elseif event.kind == "shield" then
		followShield(event.userId or 0, event.origin, event.duration or 1.15)
	elseif event.kind == "stun" then
		if event.userId then
			followStun(event.userId, event.duration or 0.8)
		end
	elseif event.kind == "heal" then
		local key = tostring(event.userId or 0)
		local now = os.clock()
		if now - (lastHealAt[key] or 0) < HEAL_DEBOUNCE then
			return
		end
		lastHealAt[key] = now
		placeBurst(event.origin, Theme.mint, 2, 0.24)
	elseif event.kind == "recall" then
		if event.userId then
			followRecall(event.userId, event.duration or 0)
		end
	end
end

function CombatFx.playUnknown(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.kind) ~= "string" or typeof(payload.origin) ~= "Vector3" then
		return
	end
	CombatFx.play(payload :: Types.CombatFxEvent)
end

function CombatFx.localRecall(userId: number, recalling: boolean, remain: number)
	if recalling then
		followRecall(userId, math.max(remain, 0.2))
	else
		followRecall(userId, 0)
	end
end

return CombatFx
