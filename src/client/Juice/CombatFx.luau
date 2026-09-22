--!strict

-- World VFX for confirmed casts / hits. Engine Parts, Beams, and one-shot
-- ParticleEmitters only. Short-lived, pooled, AA sparks debounced.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ChampionKits = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionKits"))
local CombatFloat = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CombatFloat"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local FountainRegenJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("FountainRegenJuice"))
local LevelUpJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LevelUpJuice"))
local RecallJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RecallJuice"))
local RespawnJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RespawnJuice"))
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
	cue: string?,
	baseTransparency: number?,
	startedAt: number?,
	endsAt: number?,
	locked: boolean?,
}

type FloatPop = {
	key: string,
	kind: CombatFloat.FloatKind,
	amount: number,
	bornAt: number,
	origin: Vector3,
	part: BasePart,
	gui: BillboardGui,
	label: TextLabel,
	stroke: UIStroke,
}

local folder: Folder? = nil
local pool: { BasePart } = {}
local follows: { [string]: Follow } = {}
local lastAaAt: { [string]: number } = {}
local lastHealAt: { [string]: number } = {}
local loopBound = false
local floatsEnabled = false
local recallAllowed = false
local suppressRecallUntil: { [number]: number } = {}
local floatPops: { FloatPop } = {}
local floatMergeSlots: { CombatFloat.MergeSlot } = {}

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

local ensureLoop: () -> ()

local function clearFloat(pop: FloatPop)
	if pop.gui.Parent then
		pop.gui:Destroy()
	end
	if pop.part.Parent then
		pop.part:Destroy()
	end
end

local function pruneFloatSlots(now: number)
	local keep: { CombatFloat.MergeSlot } = {}
	for _, slot in floatMergeSlots do
		if (now - slot.bornAt) <= CombatFloat.MergeWindow then
			table.insert(keep, slot)
		end
	end
	floatMergeSlots = keep
end

local function paintFloat(pop: FloatPop)
	local rgb = CombatFloat.rgb(pop.kind)
	local color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	pop.label.Text = CombatFloat.label(pop.kind, pop.amount)
	pop.label.TextColor3 = color
	pop.label.TextSize = CombatFloat.textSize(pop.kind)
	pop.label.Font = if CombatFloat.isBold(pop.kind) then Theme.fontTitle else Theme.fontMono
	pop.stroke.Thickness = if CombatFloat.isBold(pop.kind) then 2.2 else 1.4
end

local function spawnFloat(kind: CombatFloat.FloatKind, amount: number, origin: Vector3, key: string, now: number)
	local part = Instance.new("Part")
	part.Name = "Float"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(origin + Vector3.new(0, 2.4, 0))
	part.Parent = fxFolder()

	local gui = Instance.new("BillboardGui")
	gui.Name = "MeoFloat"
	gui.Size = UDim2.fromOffset(88, 36)
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Adornee = part
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.fromRGB(CombatFloat.Ink[1], CombatFloat.Ink[2], CombatFloat.Ink[3])
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(CombatFloat.Ink[1], CombatFloat.Ink[2], CombatFloat.Ink[3])
	stroke.Transparency = 0.45
	stroke.Parent = label

	local pop: FloatPop = {
		key = key,
		kind = kind,
		amount = amount,
		bornAt = now,
		origin = origin,
		part = part,
		gui = gui,
		label = label,
		stroke = stroke,
	}
	paintFloat(pop)
	table.insert(floatPops, pop)
	local slotted = false
	for _, slot in floatMergeSlots do
		if slot.key == key and slot.kind == kind and (now - slot.bornAt) <= CombatFloat.MergeWindow then
			slot.amount = amount
			slotted = true
			break
		end
	end
	if not slotted then
		table.insert(floatMergeSlots, {
			key = key,
			amount = amount,
			kind = kind,
			bornAt = now,
		})
	end
end

local function playFloat(event: Types.CombatFxEvent)
	if not floatsEnabled then
		return
	end
	local amount = event.amount
	local kind = event.floatKind
	if typeof(amount) ~= "number" or typeof(kind) ~= "string" or amount <= 0 then
		return
	end
	local floatKind = kind :: CombatFloat.FloatKind
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return
	end
	local localId = localPlayer.UserId
	if not CombatFloat.caresAbout(localId, event.attackerUserId, event.userId) then
		return
	end
	local inVision = FogOfWar.isLit(event.origin.X, event.origin.Z)
	if not CombatFloat.fogAllows(localId, event.userId, inVision) then
		return
	end

	local now = os.clock()
	pruneFloatSlots(now)
	local key = CombatFloat.mergeKey(floatKind, event.origin.X, event.origin.Z, event.userId)
	local merged = CombatFloat.tryMerge(floatMergeSlots, key, floatKind, amount, now)
	if merged then
		for _, pop in floatPops do
			if pop.key == key and pop.kind == floatKind and (now - pop.bornAt) <= CombatFloat.MergeWindow then
				pop.amount = merged.amount
				paintFloat(pop)
				return
			end
		end
		if CombatFloat.canSpawn(#floatPops) then
			local jitter = Vector3.new((math.random() - 0.5) * 0.9, 0, (math.random() - 0.5) * 0.9)
			spawnFloat(floatKind, merged.amount, event.origin + jitter, key, now)
			ensureLoop()
		end
		return
	end
	if not CombatFloat.canSpawn(#floatPops) then
		return
	end
	-- Slight scatter so stacked new pops don't sit on one pixel.
	local jitter = Vector3.new((math.random() - 0.5) * 0.9, 0, (math.random() - 0.5) * 0.9)
	spawnFloat(floatKind, amount, event.origin + jitter, key, now)
	ensureLoop()
end

ensureLoop = function()
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
				local cue = follow.cue or "local"
				local serverNow = Workspace:GetServerTimeNow()
				local progress = RecallJuice.progress(follow.startedAt, follow.endsAt, serverNow)
				local reveal = RecallJuice.shouldReveal(cue, FogOfWar.isLit(root.Position.X, root.Position.Z))
				local hide = if reveal then 0 else 1
				local spin = now * RecallJuice.SwirlSpeed
				local ground = CFrame.new(root.Position.X, root.Position.Y - 2.15, root.Position.Z)
				local fill = follow.parts[1]
				if fill then
					local span = RecallJuice.fillSpan(cue, progress)
					fill.Size = Vector3.new(0.15, span, span)
					fill.Transparency = RecallJuice.fillTransparency(cue, progress)
					fill.CFrame = ground * CFrame.Angles(0, spin, math.rad(90))
					fill.LocalTransparencyModifier = hide
				end
				local track = follow.parts[2]
				if track then
					local span = RecallJuice.trackSpan(cue)
					track.Size = Vector3.new(0.1, span, span)
					track.Transparency = RecallJuice.trackTransparency(cue)
					track.CFrame = ground * CFrame.Angles(0, -spin * 0.45, math.rad(90))
					track.LocalTransparencyModifier = hide
				end
			elseif follow.kind == "levelup" then
				local ring = follow.parts[1]
				local born = follow.bornAt or now
				local life = math.max(follow.expiresAt - born, 0.2)
				local alpha = math.clamp((now - born) / life, 0, 1)
				local grow = 5.2 + alpha * 2.4
				if ring then
					ring.Size = Vector3.new(0.14, grow, grow)
					ring.Transparency = 0.28 + alpha * 0.55
					ring.CFrame = CFrame.new(root.Position.X, root.Position.Y - 2.1, root.Position.Z)
						* CFrame.Angles(0, now * 1.6, math.rad(90))
				end
			elseif follow.kind == "fountain" then
				local ring = follow.parts[1]
				if ring then
					local cue = (follow.cue :: FountainRegenJuice.CueKind?) or "local"
					local size = FountainRegenJuice.ringSize(cue)
					local baseT = follow.baseTransparency or FountainRegenJuice.ringTransparency(cue)
					local pulse = 0.04 * math.sin(now * 2.4)
					ring.Size = Vector3.new(0.11, size, size)
					ring.Transparency = math.clamp(baseT + pulse, 0.4, 0.88)
					ring.CFrame = CFrame.new(root.Position.X, root.Position.Y - 2.18, root.Position.Z)
						* CFrame.Angles(0, now * 0.9, math.rad(90))
					-- Fog-gate enemy fountain rings like other combat FX.
					if cue == "enemy" then
						local show = FogOfWar.isLit(root.Position.X, root.Position.Z)
						ring.LocalTransparencyModifier = if show then 0 else 1
					else
						ring.LocalTransparencyModifier = 0
					end
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

		local keepFloats: { FloatPop } = {}
		for _, pop in floatPops do
			local age = now - pop.bornAt
			if age >= CombatFloat.Duration then
				clearFloat(pop)
			else
				local alpha = age / CombatFloat.Duration
				local rise = CombatFloat.RiseStuds * alpha
				local fade = if alpha < 0.55 then 0 else (alpha - 0.55) / 0.45
				pop.part.CFrame = CFrame.new(pop.origin + Vector3.new(0, 2.4 + rise, 0))
				pop.label.TextTransparency = fade
				pop.label.TextStrokeTransparency = 0.35 + fade * 0.65
				pop.stroke.Transparency = 0.45 + fade * 0.55
				table.insert(keepFloats, pop)
			end
		end
		floatPops = keepFloats
	end)
end

local function recallSuppressed(userId: number): boolean
	local untilAt = suppressRecallUntil[userId]
	return untilAt ~= nil and os.clock() < untilAt
end

local function localTeamId(): Types.TeamId?
	local lp = Players.LocalPlayer
	local team = if lp then lp.Team else nil
	if not team then
		return nil
	end
	if team.Name == Constants.Teams.BlueInstance then
		return "Blue"
	end
	if team.Name == Constants.Teams.RedInstance then
		return "Red"
	end
	return nil
end

local function recallCueFor(userId: number, team: Types.TeamId?): RecallJuice.CueKind
	local lp = Players.LocalPlayer
	local localId = if lp then lp.UserId else 0
	if userId == localId then
		return "local"
	end
	local mine = localTeamId()
	if team ~= nil and mine ~= nil and team == mine then
		return "ally"
	end
	return "enemy"
end

local function rgbOf(triple: { number }): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

local function washModel(userId: number, triple: { number }, seconds: number, amount: number)
	local model = modelOf(userId)
	if not model then
		return
	end
	local tint = rgbOf(triple)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and child.Transparency < 0.95 then
			local part = child :: BasePart
			local baseColor = part.Color
			local baseTransparency = part.Transparency
			part.Color = baseColor:Lerp(tint, amount)
			task.delay(seconds, function()
				if not part.Parent then
					return
				end
				TweenService:Create(part, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Color = baseColor,
					Transparency = baseTransparency,
				}):Play()
			end)
		end
	end
end

local function shatterRecall(at: Vector3)
	local coral = rgbOf(RecallJuice.Coral)
	for i = 1, 5 do
		local bit = takePart("RecallShard")
		bit.Shape = Enum.PartType.Ball
		local angle = (i / 5) * math.pi * 2
		bit.Size = Vector3.new(0.32, 0.32, 0.32)
		bit.CFrame = CFrame.new(at + Vector3.new(math.cos(angle) * 1.6, 0.35, math.sin(angle) * 1.6))
		flashPart(bit, coral, 0.12)
		release(bit, RecallJuice.ShatterSeconds)
	end
end

-- Amber/cream foot swirl. Local gets a cream track + growing fill.
-- Allies get one faint fill. Enemies use the same part, fog-gated in the loop.
local function followRecallChannel(
	userId: number,
	cue: RecallJuice.CueKind,
	startedAt: number,
	endsAt: number,
	authoritative: boolean,
	fresh: boolean
)
	if not recallAllowed or not RecallJuice.shouldPaint(cue) then
		return
	end
	if fresh then
		suppressRecallUntil[userId] = nil
	elseif recallSuppressed(userId) then
		return
	end
	local key = `recall:{userId}`
	local existing = follows[key]
	if existing and existing.kind == "recall" then
		if authoritative or not existing.locked then
			existing.startedAt = startedAt
			existing.endsAt = endsAt
		end
		if authoritative then
			existing.locked = true
		end
		existing.cue = cue
		local liveEnds = existing.endsAt or endsAt
		local liveRemain = math.max(liveEnds - Workspace:GetServerTimeNow(), 0)
		existing.expiresAt = os.clock() + liveRemain + RecallJuice.HoldAfter
		ensureLoop()
		return
	end
	clearFollow(key)
	local fill = takePart("RecallFill")
	fill.Shape = Enum.PartType.Cylinder
	flashPart(fill, rgbOf(RecallJuice.Amber), RecallJuice.fillTransparency(cue, 0))
	local parts = { fill }
	if cue == "local" then
		local track = takePart("RecallTrack")
		track.Shape = Enum.PartType.Cylinder
		flashPart(track, rgbOf(RecallJuice.Cream), RecallJuice.trackTransparency(cue))
		table.insert(parts, track)
		washModel(userId, RecallJuice.Amber, RecallJuice.WashSeconds, 0.3)
	end
	local remain = math.max(endsAt - Workspace:GetServerTimeNow(), 0)
	follows[key] = {
		kind = "recall",
		userId = userId,
		parts = parts,
		expiresAt = os.clock() + remain + RecallJuice.HoldAfter,
		offset = 0,
		cue = cue,
		startedAt = startedAt,
		endsAt = endsAt,
		locked = authoritative,
		bornAt = os.clock(),
	}
	ensureLoop()
end

local function finishRecall(userId: number, outcome: string, at: Vector3?)
	local key = `recall:{userId}`
	local follow = follows[key]
	local cue = if follow and follow.cue then follow.cue else recallCueFor(userId, nil)
	suppressRecallUntil[userId] = os.clock() + RecallJuice.SuppressAfter
	clearFollow(key)
	if cue ~= "local" then
		return
	end
	if outcome == "success" then
		local pos = at
		if not pos then
			local root = rootOf(userId)
			pos = if root then root.Position else nil
		end
		if pos then
			local mint = rgbOf(RecallJuice.Mint)
			placeBurst(pos, mint, 2.6, RecallJuice.FlashSeconds)
			placeRing(pos, 3.2, mint, RecallJuice.FlashSeconds + 0.08)
		end
		washModel(userId, RecallJuice.Mint, RecallJuice.FlashSeconds, 0.42)
	elseif outcome == "cancel" then
		local root = rootOf(userId)
		local pos = if root then root.Position else nil
		if pos then
			shatterRecall(pos)
		end
	end
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

local function boltFollowKey(event: Types.CombatFxEvent): string
	if typeof(event.id) == "number" then
		return `bolt:{event.id}`
	end
	return `bolt:{event.userId or 0}:{math.floor(event.origin.X)}:{math.floor(event.origin.Z)}`
end

local function followProjectile(event: Types.CombatFxEvent)
	local dest = event.dest or event.origin
	local duration = math.max(event.duration or 0.2, 0.08)
	local key = boltFollowKey(event)
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
		-- Stop the traveling bolt at impact (range end or wall). Fog show/hide stays on the follow path.
		clearFollow(boltFollowKey(event))
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
		if not recallAllowed or not event.userId then
			return
		end
		local duration = event.duration or 0
		local origin = event.origin
		local outcome = RecallJuice.fxOutcome(duration, origin.X, origin.Y, origin.Z)
		if outcome == "channel" then
			local nowS = Workspace:GetServerTimeNow()
			local cue = recallCueFor(event.userId, event.team)
			followRecallChannel(event.userId, cue, nowS, nowS + duration, false, true)
		else
			local at = if outcome == "success" then origin else nil
			finishRecall(event.userId, outcome, at)
		end
	elseif event.kind == "cleave" then
		placeBurst(event.origin, Theme.pink, 3.4, 0.28)
	elseif event.kind == "float" then
		playFloat(event)
	end
end

function CombatFx.playUnknown(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.kind) ~= "string" or typeof(payload.origin) ~= "Vector3" then
		return
	end
	CombatFx.play(payload :: Types.CombatFxEvent)
end

function CombatFx.setFloatsEnabled(enabled: boolean)
	floatsEnabled = enabled
	if not enabled then
		for _, pop in floatPops do
			clearFloat(pop)
		end
		table.clear(floatPops)
		table.clear(floatMergeSlots)
	end
end

function CombatFx.localRecall(
	userId: number,
	recalling: boolean,
	remain: number,
	startedAt: number?,
	endsAt: number?,
	fresh: boolean?
)
	if not recallAllowed then
		clearFollow(`recall:{userId}`)
		return
	end
	if not recalling then
		local follow = follows[`recall:{userId}`]
		if follow and follow.kind == "recall" then
			follow.expiresAt = math.min(follow.expiresAt, os.clock() + RecallJuice.FinishGrace)
		end
		return
	end
	local nowS = Workspace:GetServerTimeNow()
	local ends = endsAt or (nowS + math.max(remain, 0.05))
	local started = startedAt or (ends - math.max(remain, RecallJuice.ChannelFallback))
	followRecallChannel(userId, "local", started, ends, true, fresh == true)
end

function CombatFx.recallChannelLive(userId: number): boolean
	if recallSuppressed(userId) then
		return false
	end
	local follow = follows[`recall:{userId}`]
	return follow ~= nil and follow.kind == "recall"
end

function CombatFx.recallWash(userId: number)
	if not recallAllowed or recallSuppressed(userId) then
		return
	end
	washModel(userId, RecallJuice.Amber, RecallJuice.WashSeconds, 0.28)
end

function CombatFx.clearRecallJuice()
	local drop: { string } = {}
	for key, follow in follows do
		if follow.kind == "recall" then
			table.insert(drop, key)
		end
	end
	for _, key in drop do
		clearFollow(key)
	end
	table.clear(suppressRecallUntil)
end

function CombatFx.setRecallAllowed(on: boolean)
	if recallAllowed == on then
		return
	end
	recallAllowed = on
	if not on then
		CombatFx.clearRecallJuice()
	end
end

local function flashSilhouette(userId: number)
	local model = modelOf(userId)
	if not model then
		return
	end
	local amber = Color3.fromRGB(LevelUpJuice.Amber[1], LevelUpJuice.Amber[2], LevelUpJuice.Amber[3])
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and child.Transparency < 0.95 then
			local part = child :: BasePart
			local baseColor = part.Color
			local baseMaterial = part.Material
			local baseTransparency = part.Transparency
			part.Color = amber
			if baseMaterial ~= Enum.Material.Neon and baseMaterial ~= Enum.Material.ForceField then
				part.Material = Enum.Material.Neon
			end
			task.delay(0.22, function()
				if not part.Parent then
					return
				end
				part.Material = baseMaterial
				TweenService:Create(part, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Color = baseColor,
					Transparency = baseTransparency,
				}):Play()
			end)
		end
	end
end

local function spawnLevelFloat(userId: number, level: number)
	local root = rootOf(userId)
	if not root then
		return
	end
	local origin = root.Position + Vector3.new(0, 3.2, 0)
	local part = Instance.new("Part")
	part.Name = "LevelFloat"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(origin)
	part.Parent = fxFolder()

	local gui = Instance.new("BillboardGui")
	gui.Name = "MeoLevelUp"
	gui.Size = UDim2.fromOffset(140, 40)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Adornee = part
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.fontTitle
	label.TextSize = 26
	label.TextColor3 = Color3.fromRGB(LevelUpJuice.Cream[1], LevelUpJuice.Cream[2], LevelUpJuice.Cream[3])
	label.TextStrokeColor3 = Color3.fromRGB(LevelUpJuice.Ink[1], LevelUpJuice.Ink[2], LevelUpJuice.Ink[3])
	label.TextStrokeTransparency = 0.3
	label.Text = LevelUpJuice.floatLabel(level)
	label.Parent = gui

	local born = os.clock()
	local duration = LevelUpJuice.FloatSeconds
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local age = os.clock() - born
		if age >= duration or not part.Parent then
			if conn then
				conn:Disconnect()
			end
			part:Destroy()
			return
		end
		local liveRoot = rootOf(userId)
		local base = if liveRoot then liveRoot.Position else origin
		local alpha = age / duration
		part.CFrame = CFrame.new(base + Vector3.new(0, 3.2 + alpha * 1.8, 0))
		local fade = if alpha < 0.5 then 0 else (alpha - 0.5) / 0.5
		label.TextTransparency = fade
		label.TextStrokeTransparency = 0.3 + fade * 0.7
	end)
end

local function followLevelUp(userId: number)
	local key = `levelup:{userId}`
	clearFollow(key)
	local ring = takePart("LevelUp")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.14, 5.2, 5.2)
	flashPart(ring, Theme.amber, 0.32)
	follows[key] = {
		kind = "levelup",
		userId = userId,
		parts = { ring },
		expiresAt = os.clock() + LevelUpJuice.RingSeconds,
		offset = 0,
		bornAt = os.clock(),
	}
	ensureLoop()
end

-- Local-only silhouette ring + soft neon flash + optional floating LEVEL n.
-- Driven from the combat level-change edge; teammates stay kill-feed only.
function CombatFx.localLevelUp(userId: number, level: number)
	followLevelUp(userId)
	flashSilhouette(userId)
	spawnLevelFloat(userId, level)
end

local function softMintWash(userId: number)
	local model = modelOf(userId)
	if not model then
		return
	end
	local mint = Color3.fromRGB(FountainRegenJuice.Mint[1], FountainRegenJuice.Mint[2], FountainRegenJuice.Mint[3])
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and child.Transparency < 0.95 then
			local part = child :: BasePart
			local baseColor = part.Color
			local baseTransparency = part.Transparency
			-- Soft wash: tint toward mint without neon punch (fountain rest).
			part.Color = baseColor:Lerp(mint, 0.35)
			task.delay(FountainRegenJuice.WashSeconds, function()
				if not part.Parent then
					return
				end
				TweenService:Create(part, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Color = baseColor,
					Transparency = baseTransparency,
				}):Play()
			end)
		end
	end
end

local function followFountain(userId: number, cue: FountainRegenJuice.CueKind, active: boolean)
	local key = `fountain:{userId}`
	if not active or not FountainRegenJuice.shouldPaint(cue) then
		clearFollow(key)
		return
	end
	local existing = follows[key]
	if existing and existing.kind == "fountain" then
		existing.expiresAt = os.clock() + FountainRegenJuice.RingRefresh
		existing.cue = cue
		existing.baseTransparency = FountainRegenJuice.ringTransparency(cue)
		ensureLoop()
		return
	end
	clearFollow(key)
	local size = FountainRegenJuice.ringSize(cue)
	local ring = takePart("FountainRegen")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.11, size, size)
	flashPart(ring, Theme.mint, FountainRegenJuice.ringTransparency(cue))
	follows[key] = {
		kind = "fountain",
		userId = userId,
		parts = { ring },
		expiresAt = os.clock() + FountainRegenJuice.RingRefresh,
		offset = 0,
		cue = cue,
		baseTransparency = FountainRegenJuice.ringTransparency(cue),
	}
	ensureLoop()
end

local function spawnFountainFloat(userId: number, kind: FountainRegenJuice.FloatKind, amount: number)
	if not floatsEnabled then
		return
	end
	local root = rootOf(userId)
	if not root then
		return
	end
	local origin = root.Position + Vector3.new(0, 2.8, 0)
	local part = Instance.new("Part")
	part.Name = "FountainFloat"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(origin)
	part.Parent = fxFolder()

	local gui = Instance.new("BillboardGui")
	gui.Name = "MeoFountainRegen"
	gui.Size = UDim2.fromOffset(100, 32)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 72
	gui.Adornee = part
	gui.Parent = part

	local rgb = FountainRegenJuice.rgb(kind)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.fontTitle
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	label.TextStrokeColor3 = Color3.fromRGB(FountainRegenJuice.Ink[1], FountainRegenJuice.Ink[2], FountainRegenJuice.Ink[3])
	label.TextStrokeTransparency = 0.4
	label.Text = FountainRegenJuice.floatLabel(kind, amount)
	label.Parent = gui

	local born = os.clock()
	local duration = 0.85
	local lateral = if kind == "mana" then 0.55 else -0.35
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local age = os.clock() - born
		if age >= duration or not part.Parent then
			if conn then
				conn:Disconnect()
			end
			part:Destroy()
			return
		end
		local liveRoot = rootOf(userId)
		local base = if liveRoot then liveRoot.Position else origin
		local alpha = age / duration
		part.CFrame = CFrame.new(base + Vector3.new(lateral, 2.8 + alpha * 1.6, 0))
		local fade = if alpha < 0.45 then 0 else (alpha - 0.45) / 0.55
		label.TextTransparency = fade
		label.TextStrokeTransparency = 0.4 + fade * 0.6
	end)
end

-- Sustained soft mint foot ring while regenerating in fountain.
-- cue = local (clear) / ally (faint) / enemy (fog-gated).
function CombatFx.fountainRegen(userId: number, cue: FountainRegenJuice.CueKind, active: boolean)
	followFountain(userId, cue, active)
end

-- Occasional mint +HP / +mana float + soft silhouette wash on a fountain tick.
function CombatFx.fountainTick(userId: number, kind: FountainRegenJuice.FloatKind, amount: number, wash: boolean?)
	if amount <= 0 then
		return
	end
	spawnFountainFloat(userId, kind, amount)
	if wash == true then
		softMintWash(userId)
	end
end

function CombatFx.clearFountainRegen(userId: number)
	clearFollow(`fountain:{userId}`)
end

-- One calm mint puff per return. No sparks, no heal SFX — fountain regen
-- keeps the sustained ring for actual pad ticks.
local respawnArrivalAt: { [number]: number } = {}

local function respawnPuff(at: Vector3, cue: string)
	local mint = rgbOf(RespawnJuice.Mint)
	local scale = RespawnJuice.puffScale(cue)
	local ball = takePart("RespawnPuff")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(scale, scale * 0.7, scale)
	ball.CFrame = CFrame.new(at + Vector3.new(0, 0.85, 0))
	ball.Material = Enum.Material.ForceField
	ball.Color = mint
	ball.Transparency = RespawnJuice.puffTransparency(cue)
	release(ball, RespawnJuice.PuffSeconds)

	local ring = takePart("RespawnRing")
	ring.Shape = Enum.PartType.Cylinder
	local span = RespawnJuice.ringSpan(cue)
	ring.Size = Vector3.new(0.1, span, span)
	ring.CFrame = CFrame.new(at.X, at.Y + 0.16, at.Z) * CFrame.Angles(0, 0, math.rad(90))
	flashPart(ring, mint, RespawnJuice.ringTransparency(cue))
	release(ring, RespawnJuice.PuffSeconds + 0.05)
end

local function spawnRespawnBack(at: Vector3)
	local part = Instance.new("Part")
	part.Name = "RespawnBack"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(at)
	part.Parent = fxFolder()

	local gui = Instance.new("BillboardGui")
	gui.Name = "MeoRespawnBack"
	gui.Size = UDim2.fromOffset(72, 22)
	gui.StudsOffset = Vector3.new(0, 1.1, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 52
	gui.Adornee = part
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.fontTitle
	label.TextSize = 14
	label.TextColor3 = rgbOf(RespawnJuice.Mint)
	label.TextStrokeColor3 = rgbOf(RespawnJuice.Ink)
	label.TextStrokeTransparency = 0.62
	label.TextTransparency = 0.38
	label.Text = RespawnJuice.backLabel()
	label.Parent = gui

	local born = os.clock()
	local life = RespawnJuice.BackSeconds
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local age = os.clock() - born
		if age >= life or not part.Parent then
			if conn then
				conn:Disconnect()
			end
			part:Destroy()
			return
		end
		local fade = if age < life * 0.4 then 0.38 else 0.38 + ((age / life) - 0.4) * 1.05
		label.TextTransparency = math.clamp(fade, 0, 1)
	end)
end

-- Local: mint pad puff + delayed silhouette wash.
-- Ally: smaller puff and a faint "back". Enemy: fog-gated faint ring, no label.
function CombatFx.respawnArrive(userId: number, cue: string, team: string?)
	if not RespawnJuice.shouldPaint(cue) then
		return
	end
	local nowClock = os.clock()
	local last = respawnArrivalAt[userId]
	if last ~= nil and not RespawnJuice.arrivalDue(last, nowClock) then
		return
	end
	respawnArrivalAt[userId] = nowClock
	local root = rootOf(userId)
	local x, z = RespawnJuice.arrivalXZ(team, if root then root.Position.X else nil, if root then root.Position.Z else nil)
	if typeof(x) ~= "number" or typeof(z) ~= "number" then
		return
	end
	local y = 3
	if root and x == root.Position.X and z == root.Position.Z then
		y = root.Position.Y
	end
	local at = Vector3.new(x, y, z)
	respawnPuff(at, cue)
	if RespawnJuice.wantsBackLabel(cue) then
		spawnRespawnBack(at + Vector3.new(0, 2.2, 0))
	end
	if RespawnJuice.wantsWash(cue) then
		local amount = RespawnJuice.washAmount(cue)
		task.delay(RespawnJuice.WashDelay, function()
			washModel(userId, RespawnJuice.Mint, RespawnJuice.WashSeconds, amount)
		end)
	end
end

return CombatFx
