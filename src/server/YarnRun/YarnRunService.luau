--!strict

-- Server-authoritative 3-lane Yarn Run. Score / hits / pickups / death live here.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local YarnRunCatalog = require(Shared:WaitForChild("YarnRunCatalog"))
local YarnBoardLogic = require(Shared:WaitForChild("YarnBoardLogic"))

local ChampionAppearance = require(script.Parent.Parent.World.ChampionAppearance)
local ModeService = require(script.Parent.Parent.Mode.ModeService)
local YarnBoardStore = require(script.Parent.YarnBoardStore)
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
	dayKey: string,
	startedAt: number,
	boostUntil: number,
	speedUntil: number,
	magnetUntil: number,
	doubleUntil: number,
	shield: boolean,
	invulnUntil: number,
	failReason: string?,
	event: string?,
	eventUntil: number,
	consumed: { [string]: boolean },
	walkSpeed: number,
	sendAcc: number,
	ghostAcc: number,
	samples: { YarnRunCatalog.GhostSample },
	ghost: YarnRunCatalog.YarnBest?,
	nearUntil: number,
	newBest: boolean,
	dailyRank: number?,
	podium: boolean,
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

local function clockNow(): number
	return os.clock()
end

local function ghostPose(run: Run): (number?, number?, number?, boolean?)
	local record = run.ghost
	if not record or #record.samples == 0 then
		return nil, nil, nil, nil
	end
	local elapsed = now() - run.startedAt
	local pose = YarnRunCatalog.ghostAt(record.samples, elapsed)
	if not pose then
		return nil, nil, nil, nil
	end
	local last = record.samples[#record.samples]
	local alive = elapsed <= last.t + 0.05
	return pose.lane, pose.z, pose.y, alive
end

local function snapshotOf(run: Run): Types.YarnRunSnapshot
	local t = clockNow()
	local gLane, gZ, gY, gAlive = ghostPose(run)
	local record = ModeService.yarnRecord(run.player.UserId)
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
		bestMeters = if record then record.meters else 0,
		bestCombo = run.bestCombo,
		seed = run.seed,
		dayKey = run.dayKey,
		meters = math.floor(run.z),
		event = if t < run.eventUntil then run.event else nil,
		failReason = run.failReason,
		powers = {
			speed = t < run.speedUntil,
			magnet = t < run.magnetUntil,
			shield = run.shield,
			double = t < run.doubleUntil,
		},
		ghostLane = gLane,
		ghostZ = gZ,
		ghostY = gY,
		ghostAlive = gAlive,
		newBest = if run.phase == "Dead" then run.newBest else nil,
		dailyRank = run.dailyRank,
		podium = if run.phase == "Dead" then run.podium else nil,
	}
end

local function fire(run: Run)
	Remotes.event("YarnRunUpdated"):FireClient(run.player, snapshotOf(run))
end

local function shout(run: Run, text: string, hold: number?)
	run.event = text
	run.eventUntil = clockNow() + (hold or 1.35)
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

local function remember(run: Run)
	ModeService.noteYarnBest(
		run.player.UserId,
		math.floor(run.score + 0.5),
		math.floor(run.z),
		run.samples,
		run.bestCombo
	)
end

local function finish(run: Run, reason: string)
	run.phase = "Dead"
	run.failReason = reason
	run.sliding = false
	run.jumping = false
	local prev = ModeService.yarnBestOf(run.player.UserId)
	local score = math.floor(run.score + 0.5)
	run.newBest = score > prev
	if run.combo >= 2 then
		shout(run, "COMBO BREAK", 1.6)
	elseif run.newBest then
		shout(run, "NEW PB", 1.8)
	end
	remember(run)
	freezeCharacter(run.player, true, run.walkSpeed)
	fire(run)
	task.spawn(function()
		if math.floor(run.score + 0.5) <= 0 then
			return
		end
		if not runs[run.player.UserId] or runs[run.player.UserId] ~= run then
			return
		end
		local posted = YarnBoardStore.submit(
			run.player,
			math.floor(run.score + 0.5),
			math.floor(run.z),
			run.championId,
			now()
		)
		if not runs[run.player.UserId] or runs[run.player.UserId] ~= run then
			return
		end
		run.dailyRank = posted.rank
		run.podium = posted.rank ~= nil and posted.rank <= 3
		local title = if posted.rank then YarnBoardLogic.podiumTitle(posted.rank) else nil
		if title then
			shout(run, title, 2.2)
		elseif posted.rank then
			shout(run, `DAILY #{posted.rank}`, 1.6)
		end
		fire(run)
		Remotes.event("YarnBoardUpdated"):FireClient(run.player, posted.board)
	end)
end

local function scoreMul(run: Run): number
	return if clockNow() < run.doubleUntil then 2 else 1
end

local function collect(run: Run, amount: number, label: string)
	run.combo += 1
	if run.combo > run.bestCombo then
		run.bestCombo = run.combo
	end
	run.yarn += 1
	run.score += amount * math.max(1, run.combo) * scoreMul(run)
	if run.combo >= 8 then
		shout(run, "MEGA YARN")
	elseif run.combo >= 4 then
		shout(run, `COMBO x{run.combo}`)
	else
		shout(run, label)
	end
end

local function grantPower(run: Run, kind: YarnRunCatalog.ObstacleKind)
	local t = clockNow()
	if kind == "speed" then
		run.speedUntil = t + YarnRunCatalog.SpeedBurstSeconds
	elseif kind == "magnet" then
		run.magnetUntil = t + YarnRunCatalog.MagnetSeconds
	elseif kind == "shield" then
		run.shield = true
	elseif kind == "double" then
		run.doubleUntil = t + YarnRunCatalog.DoubleSeconds
	end
	collect(run, 80, YarnRunCatalog.pickupLabel(kind))
	shout(run, YarnRunCatalog.pickupLabel(kind), 1.55)
end

local function lethal(run: Run, reason: string)
	if clockNow() < run.invulnUntil then
		return false
	end
	if run.shield then
		run.shield = false
		run.invulnUntil = clockNow() + 0.4
		run.combo = 0
		shout(run, "SHIELD POP", 1.2)
		return false
	end
	finish(run, reason)
	return true
end

local function inWindow(run: Run, obstacle: YarnRunCatalog.Obstacle, window: number): boolean
	return math.abs(obstacle.z - run.z) <= window
end

local function collide(run: Run)
	local magnet = clockNow() < run.magnetUntil
	for _, obstacle in YarnRunCatalog.obstaclesAround(run.seed, run.z, 8, 14) do
		local id = keyOf(obstacle.kind, obstacle.z, obstacle.lane)
		if run.consumed[id] then
			continue
		end
		local same = obstacle.lane == run.lane
		local magnetYarn = magnet and obstacle.kind == "yarn" and math.abs(obstacle.lane - run.lane) <= 1
		if not same and not magnetYarn then
			continue
		end
		local window = if magnetYarn then YarnRunCatalog.HitWindow * 1.7 else YarnRunCatalog.HitWindow
		if not inWindow(run, obstacle, window) then
			continue
		end
		if obstacle.kind == "dog" then
			if run.y < 2.6 then
				if lethal(run, "A dog got the zoomies") then
					return
				end
				run.consumed[id] = true
			end
		elseif obstacle.kind == "sign" then
			if not run.sliding then
				if lethal(run, "Bonked a laundry sign") then
					return
				end
				run.consumed[id] = true
			end
		elseif obstacle.kind == "wall" then
			if lethal(run, "Night-market furniture") then
				return
			end
			run.consumed[id] = true
		elseif obstacle.kind == "yarn" then
			run.consumed[id] = true
			collect(run, 50, if magnetYarn and not same then "MAGNET YARN" else "YARN")
		elseif obstacle.kind == "roomba" then
			run.consumed[id] = true
			run.boostUntil = clockNow() + 1.1
			collect(run, 120, "ROOMBA RAIL")
		elseif YarnRunCatalog.isPickup(obstacle.kind) then
			run.consumed[id] = true
			grantPower(run, obstacle.kind)
		end
	end
end

local function nearMiss(run: Run)
	if clockNow() < run.nearUntil then
		return
	end
	for _, obstacle in YarnRunCatalog.obstaclesAround(run.seed, run.z, 4, 8) do
		if not YarnRunCatalog.isLethal(obstacle.kind) then
			continue
		end
		local dz = obstacle.z - run.z
		if dz < 0.4 or dz > 4.2 then
			continue
		end
		if obstacle.lane == run.lane then
			if obstacle.kind == "dog" and run.y > 2.1 then
				shout(run, "CLOSE!", 0.7)
				run.nearUntil = clockNow() + 0.85
				return
			end
			if obstacle.kind == "sign" and run.sliding then
				shout(run, "CLOSE!", 0.7)
				run.nearUntil = clockNow() + 0.85
				return
			end
		elseif math.abs(obstacle.lane - run.lane) == 1 and math.abs(dz) < 2.2 then
			shout(run, "CLOSE!", 0.65)
			run.nearUntil = clockNow() + 0.9
			return
		end
	end
end

local function speedMul(run: Run): number
	local t = clockNow()
	if t < run.speedUntil then
		return YarnRunCatalog.SpeedBurstMul
	end
	if t < run.boostUntil then
		return YarnRunCatalog.RoombaMul
	end
	return 1
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
		local mul = speedMul(run)
		run.speed = math.min(YarnRunCatalog.MaxSpeed, YarnRunCatalog.BaseSpeed + (now() - run.startedAt) * YarnRunCatalog.SpeedPerSecond)
		run.z += run.speed * mul * dt
		run.score += dt * 4 * mul * scoreMul(run)

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

		run.ghostAcc += dt
		if run.ghostAcc >= 1 / YarnRunCatalog.GhostHz then
			run.ghostAcc = 0
			if #run.samples < YarnRunCatalog.GhostCap then
				table.insert(run.samples, {
					t = now() - run.startedAt,
					lane = run.lane,
					y = run.y,
					z = run.z,
				})
			end
		end

		collide(run)
		if run.phase ~= "Running" then
			continue
		end
		nearMiss(run)
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

	local unix = now()
	local seed = YarnRunCatalog.dailySeed(unix)
	local dayKey = YarnRunCatalog.dayKey(unix)
	for _, other in runs do
		if other.phase == "Running" then
			seed = other.seed
			dayKey = other.dayKey
			break
		end
	end
	if YarnRunService.playingCount() == 0 then
		YarnTrackBuilder.reset(seed)
	end
	local record = ModeService.yarnRecord(player.UserId)
	YarnTrackBuilder.sync(0, seed)
	YarnTrackBuilder.markBest(if record then record.meters else 0)

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
		dayKey = dayKey,
		startedAt = unix,
		boostUntil = 0,
		speedUntil = 0,
		magnetUntil = 0,
		doubleUntil = 0,
		shield = false,
		invulnUntil = 0,
		failReason = nil,
		event = "GO GO YARN",
		eventUntil = clockNow() + 1.2,
		consumed = {},
		walkSpeed = if humanoid then humanoid.WalkSpeed else 16,
		sendAcc = 1,
		ghostAcc = 0,
		samples = { { t = 0, lane = 1, y = 0, z = 4 } },
		ghost = record,
		nearUntil = 0,
		newBest = false,
		dailyRank = YarnBoardStore.rankOf(player.UserId, unix),
		podium = false,
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
		remember(run)
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
