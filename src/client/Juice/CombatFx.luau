--!strict

-- World VFX for confirmed casts / hits. Engine Parts, Beams, and one-shot
-- ParticleEmitters only. Short-lived, pooled, AA sparks debounced.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ChampionKits = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionKits"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local Theme = require(script.Parent.Parent.Theme)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local FogOfWar = require(script.Parent.FogOfWar)

local CombatFx = {}

local FOLDER_NAME = "MeoFx"
local POOL_CAP = 40
local AA_DEBOUNCE = 0.14
local HEAL_DEBOUNCE = 0.2

type Follow = {
	kind: string,
	userId: number,
	parts: { BasePart },
	expiresAt: number,
	offset: number,
	origin: Vector3?,
	dest: Vector3?,
	bornAt: number?,
	width: number?,
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
			if now >= follow.expiresAt then
				clearFollow(key)
				continue
			end
			if follow.kind == "zone" then
				local ring = follow.parts[1]
				local at = follow.origin
				if ring and at then
					local pulse = 1 + math.sin(now * 6) * 0.05
					local span = follow.width or 12
					ring.Size = Vector3.new(0.2, span * pulse, span * pulse)
					ring.CFrame = CFrame.new(at.X, at.Y + 0.22, at.Z) * CFrame.Angles(0, now * 0.4, math.rad(90))
				end
				continue
			end
			if follow.kind == "projectile" then
				local bolt = follow.parts[1]
				local origin = follow.origin
				local dest = follow.dest
				local born = follow.bornAt or now
				local life = math.max(follow.expiresAt - born, 0.08)
				if bolt and origin and dest then
					local alpha = math.clamp((now - born) / life, 0, 1)
					local pos = origin:Lerp(dest, alpha)
					local look = dest
					if (dest - origin).Magnitude < 0.4 then
						look = origin + Vector3.new(1, 0, 0)
					end
					bolt.CFrame = CFrame.lookAt(pos + Vector3.new(0, 0.55, 0), look + Vector3.new(0, 0.55, 0))
					local localId = Players.LocalPlayer and Players.LocalPlayer.UserId
					local own = localId ~= nil and follow.userId == localId
					local show = own or FogOfWar.isLit(pos.X, pos.Z)
					bolt.LocalTransparencyModifier = if show then 0 else 1
				end
				continue
			end
			local root = rootOf(follow.userId)
			if not root then
				clearFollow(key)
				continue
			end
			if follow.kind == "channel" then
				local ring = follow.parts[1]
				if ring then
					ring.CFrame = CFrame.new(root.Position.X, root.Position.Y - 2.05, root.Position.Z)
						* CFrame.Angles(0, now * 2.2, math.rad(90))
				end
			elseif follow.kind == "recall" then
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
		expiresAt = os.clock() + duration,
		offset = 0,
	}
	ensureLoop()
end

local function followShield(userId: number, at: Vector3, duration: number, color: Color3?)
	local key = `shield:{userId}`
	clearFollow(key)
	local bubble = takePart("Shield")
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = if color then Vector3.new(5.2, 3.4, 5.2) else Vector3.new(4.2, 4.2, 4.2)
	bubble.Material = Enum.Material.ForceField
	bubble.Color = color or Theme.amber
	bubble.Transparency = 0.42
	bubble.CFrame = CFrame.new(at)
	follows[key] = {
		kind = "shield",
		userId = userId,
		parts = { bubble },
		expiresAt = os.clock() + duration,
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
		expiresAt = os.clock() + math.max(duration, 0.35),
		offset = os.clock(),
	}
	ensureLoop()
end

local function kitLook(event: Types.CombatFxEvent): ChampionKits.Look?
	if not event.championId or not event.slot then
		return nil
	end
	return ChampionKits.look(event.championId, event.slot)
end

local function playKitSound(event: Types.CombatFxEvent, pitch: number, includeLocal: boolean)
	local localId = Players.LocalPlayer and Players.LocalPlayer.UserId
	if not includeLocal and localId ~= nil and event.userId == localId then
		return
	end
	Sfx.play("AbilityCast", pitch)
end

local function followChannel(userId: number, at: Vector3, duration: number)
	local key = `channel:{userId}`
	if duration <= 0 then
		clearFollow(key)
		return
	end
	clearFollow(key)
	local ring = takePart("Hyperbeam")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.22, 7.2, 7.2)
	flashPart(ring, Color3.fromRGB(255, 72, 196), 0.28)
	ring.CFrame = CFrame.new(at.X, at.Y - 2.05, at.Z) * CFrame.Angles(0, 0, math.rad(90))
	follows[key] = {
		kind = "channel",
		userId = userId,
		parts = { ring },
		expiresAt = os.clock() + duration,
		offset = 0,
	}
	ensureLoop()
end

local function followZone(event: Types.CombatFxEvent, duration: number, color: Color3?)
	local dest = event.dest or event.origin
	local key = `zone:{event.id or event.userId or 0}:{math.floor(dest.X)}:{math.floor(dest.Z)}`
	clearFollow(key)
	local radius = event.radius or 12
	local span = math.max(radius * 2, 8)
	local ring = takePart("QuizZone")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, span, span)
	flashPart(ring, color or Color3.fromRGB(126, 196, 255), 0.45)
	ring.CFrame = CFrame.new(dest.X, dest.Y + 0.22, dest.Z) * CFrame.Angles(0, 0, math.rad(90))
	follows[key] = {
		kind = "zone",
		userId = event.userId or 0,
		parts = { ring },
		expiresAt = os.clock() + duration,
		offset = 0,
		origin = dest,
		width = span,
	}
	ensureLoop()
end

local function placePull(dest: Vector3, radius: number)
	local gold = Color3.fromRGB(214, 168, 74)
	placeRing(dest, radius, gold, 0.42)
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2
		local edge = dest + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		placeBeam(edge, dest, gold, 1.15, 0.28)
	end
end

local function placeKnock(origin: Vector3, dest: Vector3)
	local chonk = Color3.fromRGB(232, 148, 64)
	placeBeam(origin, dest, chonk, 2.6, 0.26)
	local flat = Vector3.new(dest.X - origin.X, 0, dest.Z - origin.Z)
	local dir = if flat.Magnitude > 0.5 then flat.Unit else Vector3.new(1, 0, 0)
	placeBeam(dest, dest + dir * 10, chonk, 1.5, 0.22)
	placeBurst(dest, chonk, 2.1, 0.22)
end

local function placeWick(at: Vector3)
	local green = Color3.fromRGB(150, 220, 90)
	placeRing(at, 5, green, 0.28)
	local candle = takePart("Wick")
	candle.Shape = Enum.PartType.Block
	candle.Size = Vector3.new(0.35, 6.5, 0.35)
	candle.CFrame = CFrame.new(at + Vector3.new(0, 3.4, 0))
	flashPart(candle, Color3.fromRGB(255, 214, 96), 0.12)
	release(candle, 0.28)
end

local function placeCandle(at: Vector3, radius: number)
	local green = Color3.fromRGB(120, 200, 90)
	local gold = Color3.fromRGB(255, 186, 72)
	placeRing(at, radius, green, 0.34)
	placeRing(at, math.max(radius * 0.45, 4), gold, 0.4)
	placeBurst(at, gold, 2.2, 0.24)
end

local function placeSweater(at: Vector3, radius: number)
	local yarn = Color3.fromRGB(245, 214, 186)
	placeRing(at, radius, yarn, 0.4)
	placeBurst(at, Color3.fromRGB(255, 236, 214), 2.1, 0.28)
end

local function placeOverclock(at: Vector3, radius: number)
	local steel = Color3.fromRGB(176, 214, 232)
	placeRing(at, radius, steel, 0.36)
	placeRing(at, math.max(radius * 0.45, 3), Color3.fromRGB(210, 236, 255), 0.42)
end

local function placeBleed(at: Vector3)
	local cut = Color3.fromRGB(176, 48, 42)
	placeRing(at, 5, cut, 0.3)
	for i = 1, 3 do
		local tick = takePart(`Bleed{i}`)
		tick.Shape = Enum.PartType.Block
		tick.Size = Vector3.new(0.18, 2.4, 0.7)
		local angle = (i / 3) * math.pi
		tick.CFrame = CFrame.new(at + Vector3.new(math.cos(angle) * 1.2, 1.4, math.sin(angle) * 1.2))
			* CFrame.Angles(0, angle, math.rad(18))
		flashPart(tick, cut, 0.15)
		release(tick, 0.28)
	end
end

local function placeFortify(at: Vector3, radius: number)
	local heater = Color3.fromRGB(196, 80, 70)
	placeRing(at, radius, heater, 0.38)
	placeBurst(at, Color3.fromRGB(232, 120, 96), 1.8, 0.22)
end

local function placeMark(at: Vector3)
	local ink = Color3.fromRGB(36, 40, 64)
	local edge = Color3.fromRGB(168, 140, 220)
	placeRing(at, 6, ink, 0.22)
	placeRing(at, 3.2, edge, 0.4)
end

local function placeVanish(origin: Vector3, dest: Vector3)
	local smoke = Color3.fromRGB(28, 32, 52)
	placeBeam(origin, dest, smoke, 2.4, 0.34)
	placeBurst(dest, Color3.fromRGB(120, 110, 160), 1.6, 0.2)
end

local function placePlate(at: Vector3)
	local chrome = Color3.fromRGB(90, 210, 200)
	placeRing(at, 5.5, chrome, 0.32)
	local shard = takePart("Plate")
	shard.Shape = Enum.PartType.Block
	shard.Size = Vector3.new(0.35, 3.2, 1.4)
	shard.CFrame = CFrame.new(at + Vector3.new(0, 1.8, 0))
	flashPart(shard, chrome, 0.12)
	release(shard, 0.28)
end

local function placeReload(origin: Vector3, dest: Vector3)
	local chrome = Color3.fromRGB(90, 210, 200)
	placeBeam(origin, dest, chrome, 2.2, 0.28)
	placeRing(dest, 4.5, Color3.fromRGB(210, 255, 246), 0.36)
	placeBurst(dest, chrome, 1.6, 0.2)
end

local function placeOmen(at: Vector3, radius: number)
	local lilac = Color3.fromRGB(186, 140, 220)
	placeRing(at, radius, lilac, 0.38)
	placeRing(at, math.max(radius * 0.45, 3.5), Color3.fromRGB(236, 214, 255), 0.44)
end

local function placeCharge(at: Vector3)
	local ink = Color3.fromRGB(70, 90, 190)
	placeRing(at, 4.2, ink, 0.3)
	local spark = takePart("Charge")
	spark.Shape = Enum.PartType.Ball
	spark.Size = Vector3.new(0.7, 0.7, 0.7)
	spark.CFrame = CFrame.new(at + Vector3.new(0, 2.4, 0))
	flashPart(spark, Color3.fromRGB(170, 190, 255), 0.08)
	release(spark, 0.26)
end

local function placeCurse(at: Vector3)
	local hex = Color3.fromRGB(168, 70, 200)
	placeRing(at, 5.2, hex, 0.3)
	for i = 1, 3 do
		local tick = takePart(`Curse{i}`)
		tick.Shape = Enum.PartType.Ball
		tick.Size = Vector3.new(0.35, 0.35, 0.35)
		local angle = (i / 3) * math.pi * 2
		tick.CFrame = CFrame.new(at + Vector3.new(math.cos(angle) * 1.4, 1.6, math.sin(angle) * 1.4))
		flashPart(tick, Color3.fromRGB(230, 140, 255), 0.12)
		release(tick, 0.28)
	end
end

local function placePsi(at: Vector3)
	local mind = Color3.fromRGB(210, 120, 230)
	placeRing(at, 6, Color3.fromRGB(86, 40, 120), 0.24)
	placeRing(at, 3.1, mind, 0.42)
end

local function placeNudge(origin: Vector3, dest: Vector3)
	local mind = Color3.fromRGB(210, 120, 230)
	placeBeam(dest, origin, mind, 1.35, 0.26)
	placeBurst(dest, mind, 1.7, 0.22)
end

local function placeMeteor(at: Vector3, radius: number)
	local ink = Color3.fromRGB(70, 90, 190)
	placeRing(at, radius, ink, 0.4)
	placeBeam(at + Vector3.new(0, 18, 0), at, Color3.fromRGB(140, 160, 255), 1.6, 0.3)
	placeBurst(at, ink, 2.4, 0.26)
end

local function followProjectile(event: Types.CombatFxEvent)
	local dest = event.dest or event.origin
	local duration = math.max(event.duration or 0.2, 0.08)
	local key = `bolt:{event.id or event.userId or 0}:{math.floor(event.origin.X)}:{math.floor(event.origin.Z)}`
	clearFollow(key)
	local look = kitLook(event)
	local color = abilityColor(event.abilityKind)
	if look == "laser" then
		color = Color3.fromRGB(126, 214, 255)
	elseif look == "data" then
		color = Color3.fromRGB(176, 206, 220)
	elseif look == "channel" then
		color = Color3.fromRGB(255, 64, 196)
	elseif look == "rainbow" then
		color = Color3.fromRGB(255, 120, 210)
	end
	local bolt = takePart("BoltShot")
	local width = math.max((event.radius or 6) * 0.45, 0.9)
	if look == "laser" then
		width = math.max(width * 0.55, 0.65)
	elseif look == "data" then
		width = math.max(width * 0.7, 0.7)
	elseif look == "channel" then
		width *= 1.35
	end
	bolt.Shape = Enum.PartType.Ball
	bolt.Size = Vector3.new(width, width, width * 1.6)
	bolt.Material = Enum.Material.Neon
	bolt.Color = color
	bolt.Transparency = 0.08
	bolt.CFrame = CFrame.new(event.origin + Vector3.new(0, 0.55, 0))
	follows[key] = {
		kind = "projectile",
		userId = event.userId or 0,
		parts = { bolt },
		expiresAt = os.clock() + duration,
		offset = 0,
		origin = event.origin,
		dest = dest,
		bornAt = os.clock(),
		width = width,
	}
	ensureLoop()
end

local function playAbility(event: Types.CombatFxEvent)
	local look = kitLook(event)
	local origin = event.origin
	local dest = event.dest or origin
	local radius = event.radius or 10
	if look == "channel" then
		local seconds = event.duration or 0
		if seconds <= 0 then
			followChannel(event.userId or 0, origin, 0)
			local pitch = if event.championId and event.slot then ChampionKits.breakPitch(event.championId, event.slot) else nil
			if pitch then
				playKitSound(event, pitch, true)
			end
		else
			followChannel(event.userId or 0, origin, seconds)
			placeBeam(origin, dest, Color3.fromRGB(255, 120, 210), 1.4, 0.16)
			local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
			playKitSound(event, pitch, false)
		end
		return
	elseif look == "zone" then
		local seconds = math.max(event.duration or 2.4, 0.4)
		followZone(event, seconds)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "pull" then
		placePull(dest, radius)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "knock" then
		placeKnock(origin, dest)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "wick" then
		placeWick(dest)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "candle" then
		placeCandle(dest, radius)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "sweater" then
		placeSweater(dest, radius)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "overclock" then
		placeOverclock(dest, radius)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "bleed" then
		placeBleed(dest)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "fortify" then
		placeFortify(dest, radius)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "mark" then
		placeMark(dest)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "vanish" then
		placeVanish(origin, dest)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "plate" then
		placePlate(dest)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "reload" then
		placeReload(origin, dest)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "omen" then
		placeOmen(dest, radius)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "charge" then
		placeCharge(dest)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "meteor" then
		placeMeteor(dest, radius)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "curse" then
		placeCurse(dest)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "hex" then
		local seconds = math.max(event.duration or 2.4, 0.4)
		followZone(event, seconds, Color3.fromRGB(168, 70, 200))
		placeBurst(dest, Color3.fromRGB(210, 120, 255), 2.2, 0.24)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "psi" then
		placePsi(dest)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	elseif look == "nudge" then
		placeNudge(origin, dest)
		local pitch = if event.championId and event.slot then ChampionKits.castPitch(event.championId, event.slot) else 1
		playKitSound(event, pitch, false)
		return
	end
	local color = abilityColor(event.abilityKind)
	local mode = event.mode
	if mode == "line" then
		placeBeam(origin, dest, color, math.max((event.radius or 6) * 1.4, 2), 0.18)
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
	local color = if event.tier == "Inner" then Color3.fromRGB(255, 186, 96) else teamColor(event.team)
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
	local scale = if event.structureKind == "Nexus" then 1.5 elseif event.tier == "Inner" then 1.2 else 1
	local puffColor = if event.tier == "Inner" then Color3.fromRGB(255, 176, 72) else Theme.peach
	placeBurst(event.origin, puffColor, 3.2 * scale, 0.4)
	for i = 1, 6 do
		local puff = takePart(`Puff{i}`)
		local angle = (i / 6) * math.pi * 2
		puff.Shape = Enum.PartType.Ball
		puff.Size = Vector3.new(1.1, 1.1, 1.1) * scale
		puff.CFrame = CFrame.new(event.origin + Vector3.new(math.cos(angle) * 3 * scale, 2, math.sin(angle) * 3 * scale))
		flashPart(puff, puffColor, 0.25)
		release(puff, 0.42)
	end
end

function CombatFx.play(event: Types.CombatFxEvent)
	if event.kind == "ability" then
		playAbility(event)
	elseif event.kind == "projectile" then
		followProjectile(event)
	elseif event.kind == "projectileHit" then
		local localId = Players.LocalPlayer and Players.LocalPlayer.UserId
		local own = localId ~= nil and event.userId == localId
		if own or FogOfWar.isLit(event.origin.X, event.origin.Z) then
			local look = kitLook(event)
			local color = abilityColor(event.abilityKind)
			if look == "laser" then
				color = Color3.fromRGB(126, 214, 255)
			elseif look == "data" then
				color = Color3.fromRGB(176, 206, 220)
			elseif look == "channel" or look == "rainbow" then
				color = Color3.fromRGB(255, 96, 196)
			end
			placeBurst(event.origin, color, 1.7, 0.2)
		end
	elseif event.kind == "aa" then
		playAa(event)
	elseif event.kind == "towerShot" then
		playTowerShot(event)
	elseif event.kind == "structureDeath" then
		playStructureDeath(event)
	elseif event.kind == "shield" then
		local look = kitLook(event)
		local tint = if look == "guard"
			then Color3.fromRGB(196, 148, 72)
			elseif look == "sweater" then Color3.fromRGB(245, 214, 186)
			elseif look == "fortify" then Color3.fromRGB(196, 92, 78)
			else nil
		followShield(event.userId or 0, event.origin, event.duration or 1.15, tint)
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
