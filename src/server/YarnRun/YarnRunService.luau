--!strict

-- Server-authoritative 3-lane Yarn Run. Score / hits / death live here.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local YarnRunCatalog = require(Shared:WaitForChild("YarnRunCatalog"))

local ChampionAppearance = require(script.Parent.Parent.World.ChampionAppearance)
local ModeService = require(script.Parent.Parent.Mode.ModeService)
local YarnTrackBuilder = require(script.Parent.YarnTrackBuilder)

type Run = {
	player: Player,
	championId: string,
	phase: Types.YarnRunPhase,
	lane: number,
	z: number,
	y: number,
	sliding: boolean,
	jumping: boolean,
	jumpT: number,
	slideT: number,
	speed: number,
	score: number,
	combo: number,
	yarn: number,
	bestCombo: number,
	seed: number,
	startedAt: number,
	boostUntil: number,
	failReason: string?,
	event: string?,
	eventUntil: number,
	consumed: { [string]: boolean },
	walkSpeed: number,
	sendAcc: number,
}

local YarnRunService = {}

local runs: { [number]: Run } = {}
local bound = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function keyOf(kind: string, z: number, lane: number): string
	return `{kind}:{math.floor(z + 0.5)}:{lane}`
end

local function snapshotOf(run: Run): Types.YarnRunSnapshot
	return {
		phase = run.phase,
		championId = run.championId,
		lane = run.lane,
		z = run.z,
		y = run.y,
		sliding = run.sliding,
		jumping = run.jumping,
		speed = run.speed,
		score = math.floor(run.score + 0.5),
		combo = run.combo,
		yarn = run.yarn,
		bestScore = ModeService.yarnBestOf(run.player.UserId),
		bestCombo = run.bestCombo,
		seed = run.seed,
		meters = math.floor(run.z),
		event = if os.clock() < run.eventUntil then run.event else nil,
		failReason = run.failReason,
	}
end

local function fire(run: Run)
	Remotes.event("YarnRunUpdated"):FireClient(run.player, snapshotOf(run))
end

local function shout(run: Run, text: string)
	run.event = text
	run.eventUntil = os.clock() + 1.35
end

local function freezeCharacter(player: Player, on: boolean, walkSpeed: number?)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if on then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
	else
		humanoid.WalkSpeed = walkSpeed or 16
		humanoid.JumpPower = 50
		humanoid.AutoRotate = true
	end
end

local function place(run: Run)
	local character = run.player.Character
	if not character then
		return
	end
	local at = YarnTrackBuilder.world(run.lane, 3.1 + run.y, run.z)
	local cf = CFrame.lookAt(at, at + Vector3.new(0, 0, 12))
	local ok = pcall(function()
		character:PivotTo(cf)
	end)
	if not ok then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.CFrame = cf
		end
	end
end

local function dress(run: Run)
	local character = run.player.Character
	if not character then
		return
	end
	ChampionAppearance.apply(character, {
		championId = run.championId,
		team = "Blue",
		displayName = run.player.DisplayName,
		isBot = false,
	})
end

local function sendHome(player: Player)
	local map = Workspace:FindFirstChild(Constants.MapFolderName)
	local spawns = if map then map:FindFirstChild("Spawns") else nil
	local spawn = if spawns then spawns:FindFirstChild("Lobby") else nil
	if spawn and spawn:IsA("BasePart") then
		player.RespawnLocation = spawn
		local character = player.Character
		if character then
			pcall(function()
				character:PivotTo(spawn.CFrame + Vector3.new(0, 5, 0))
			end)
		end
	end
end

local function finish(run: Run, reason: string)
	run.phase = "Dead"
	run.failReason = reason
	run.sliding = false
	run.jumping = false
	ModeService.noteYarnBest(run.player.UserId, math.floor(run.score + 0.5))
	freezeCharacter(run.player, true, run.walkSpeed)
	fire(run)
end

local function collect(run: Run, amount: number, label: string)
	run.combo += 1
	if run.combo > run.bestCombo then
		run.bestCombo = run.combo
	end
	run.yarn += 1
	run.score += amount * math.max(1, run.combo)
	if run.combo >= 8 then
		shout(run, "MEGA YARN")
	elseif run.combo >= 4 then
		shout(run, `COMBO x{run.combo}`)
	else
		shout(run, label)
	end
end

local function collide(run: Run)
	for _, obstacle in YarnRunCatalog.obstaclesAround(run.seed, run.z, 6, 10) do
		if obstacle.lane ~= run.lane then
			continue
		end
		if math.abs(obstacle.z - run.z) > YarnRunCatalog.HitWindow then
			continue
		end
		local id = keyOf(obstacle.kind, obstacle.z, obstacle.lane)
		if run.consumed[id] then
			continue
		end
		if obstacle.kind == "dog" then
			if run.y < 2.6 then
				finish(run, "A dog got the zoomies")
				return
			end
		elseif obstacle.kind == "sign" then
			if not run.sliding then
				finish(run, "Bonked a laundry sign")
				return
			end
		elseif obstacle.kind == "yarn" then
			run.consumed[id] = true
			collect(run, 50, "YARN")
		elseif obstacle.kind == "roomba" then
			run.consumed[id] = true
			run.boostUntil = os.clock() + 1.1
			collect(run, 120, "ROOMBA RAIL")
		end
	end
end

local function step(dt: number)
	for userId, run in runs do
		if run.phase ~= "Running" then
			continue
		end
		if not run.player.Parent then
			runs[userId] = nil
			continue
		end
		local mul = if os.clock() < run.boostUntil then 1.45 else 1
		run.speed = math.min(YarnRunCatalog.MaxSpeed, YarnRunCatalog.BaseSpeed + (now() - run.startedAt) * YarnRunCatalog.SpeedPerSecond)
		run.z += run.speed * mul * dt
		run.score += dt * 4 * mul

		if run.jumping then
			run.jumpT += dt
			local t = math.clamp(run.jumpT / YarnRunCatalog.JumpSeconds, 0, 1)
			run.y = YarnRunCatalog.JumpHeight * math.sin(math.pi * t)
			if t >= 1 then
				run.jumping = false
				run.y = 0
			end
		else
			run.y = 0
		end
		if run.sliding then
			run.slideT += dt
			if run.slideT >= YarnRunCatalog.SlideSeconds then
				run.sliding = false
			end
		end

		collide(run)
		if run.phase ~= "Running" then
			continue
		end
		place(run)
		YarnTrackBuilder.sync(run.z, run.seed)
		run.sendAcc += dt
		if run.sendAcc >= 1 / 12 then
			run.sendAcc = 0
			fire(run)
		end
	end
end

local function bind()
	if bound then
		return
	end
	bound = true
	RunService.Heartbeat:Connect(function(dt)
		if next(runs) == nil then
			return
		end
		step(math.clamp(dt, 0, 0.05))
	end)
end

function YarnRunService.playingCount(): number
	local n = 0
	for _, run in runs do
		if run.phase == "Running" then
			n += 1
		end
	end
	return n
end

function YarnRunService.isPlaying(player: Player): boolean
	local run = runs[player.UserId]
	return run ~= nil and run.phase ~= "Idle"
end

function YarnRunService.snapshot(player: Player): Types.YarnRunSnapshot?
	local run = runs[player.UserId]
	if not run then
		return nil
	end
	return snapshotOf(run)
end

function YarnRunService.start(player: Player, championId: unknown): Types.TradeResult
	if ModeService.busyMatch() then
		return { ok = false, error = "Cat Rift is live on this server — try Yarn Run after." }
	end
	if ModeService.is(player, "Moba") then
		return { ok = false, error = "Leave the Rift first." }
	end
	local champ = YarnRunCatalog.parseRunner(championId)
	local existing = runs[player.UserId]
	if existing and existing.phase == "Running" then
		return { ok = false, error = "Already dashing." }
	end

	local seed = player.UserId + math.floor(now() * 1000)
	for _, other in runs do
		if other.phase == "Running" then
			seed = other.seed
			break
		end
	end
	if YarnRunService.playingCount() == 0 then
		YarnTrackBuilder.reset(seed)
	end
	YarnTrackBuilder.sync(0, seed)

	local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
	local run: Run = {
		player = player,
		championId = champ,
		phase = "Running",
		lane = 1,
		z = 4,
		y = 0,
		sliding = false,
		jumping = false,
		jumpT = 0,
		slideT = 0,
		speed = YarnRunCatalog.BaseSpeed,
		score = 0,
		combo = 0,
		yarn = 0,
		bestCombo = 0,
		seed = seed,
		startedAt = now(),
		boostUntil = 0,
		failReason = nil,
		event = "GO GO YARN",
		eventUntil = os.clock() + 1.2,
		consumed = {},
		walkSpeed = if humanoid then humanoid.WalkSpeed else 16,
		sendAcc = 1,
	}
	runs[player.UserId] = run
	ModeService.set(player, "YarnRun")
	freezeCharacter(player, true, run.walkSpeed)
	dress(run)
	place(run)
	bind()
	fire(run)
	return { ok = true }
end

function YarnRunService.input(player: Player, payload: unknown): Types.TradeResult
	local run = runs[player.UserId]
	if not run or run.phase ~= "Running" then
		return { ok = false, error = "Not in a Yarn Run." }
	end
	if typeof(payload) ~= "table" then
		return { ok = false, error = "Bad input." }
	end
	local body = payload :: Types.YarnRunInput
	if typeof(body.lane) == "number" then
		run.lane = math.clamp(math.floor(body.lane), 0, 2)
	end
	if body.jump == true and not run.jumping and not run.sliding then
		run.jumping = true
		run.jumpT = 0
	end
	if body.slide == true and not run.sliding and not run.jumping then
		run.sliding = true
		run.slideT = 0
	end
	return { ok = true }
end

function YarnRunService.leave(player: Player): Types.TradeResult
	local run = runs[player.UserId]
	if run then
		ModeService.noteYarnBest(player.UserId, math.floor(run.score + 0.5))
		freezeCharacter(player, false, run.walkSpeed)
	end
	runs[player.UserId] = nil
	ModeService.set(player, "Hub")
	sendHome(player)
	return { ok = true }
end

function YarnRunService.retry(player: Player): Types.TradeResult
	local run = runs[player.UserId]
	local champ = if run then run.championId else "NyanRocket"
	runs[player.UserId] = nil
	return YarnRunService.start(player, champ)
end

function YarnRunService.clear(userId: number)
	runs[userId] = nil
end

return YarnRunService
