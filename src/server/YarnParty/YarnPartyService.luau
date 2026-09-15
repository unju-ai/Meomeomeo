--!strict

-- Server-authoritative Yarn Party. 3 micro-rounds, bots fill to 4 cats.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local YarnPartyCatalog = require(Shared:WaitForChild("YarnPartyCatalog"))

local ModeService = require(script.Parent.Parent.Mode.ModeService)
local YarnPartyBuilder = require(script.Parent.YarnPartyBuilder)

type Contestant = {
	id: number,
	player: Player?,
	name: string,
	championId: string,
	isBot: boolean,
	alive: boolean,
	score: number,
	model: Model?,
	walkSpeed: number,
	jumpUntil: number,
	charConn: RBXScriptConnection?,
}

type Party = {
	phase: Types.YarnPartyPhase,
	roundIndex: number,
	kind: YarnPartyCatalog.RoundKind,
	phaseEnds: number,
	event: string?,
	eventUntil: number,
	yarn: Vector3,
	yarnVel: Vector3,
	safe: { boolean },
	musicOn: boolean,
	freeze: boolean,
	pulseChecked: number,
	contestants: { Contestant },
	elimOrder: { number },
	winnerName: string?,
	winnerId: number?,
	sendAcc: number,
}

local YarnPartyService = {}

local party: Party? = nil
local bound = false

local function clockNow(): number
	return os.clock()
end

local function origin(): Vector3
	return Constants.YarnPartyOrigin
end

local function shout(state: Party, text: string, hold: number?)
	state.event = text
	state.eventUntil = clockNow() + (hold or 1.4)
end

local function seatOf(con: Contestant): Types.YarnPartySeat
	return {
		id = con.id,
		name = con.name,
		championId = con.championId,
		isBot = con.isBot,
		alive = con.alive,
		score = con.score,
	}
end

local function snapshotOf(state: Party): Types.YarnPartySnapshot
	local seats = {}
	for _, con in state.contestants do
		table.insert(seats, seatOf(con))
	end
	table.sort(seats, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.id < b.id
	end)
	local remain = math.max(0, state.phaseEnds - clockNow())
	return {
		phase = state.phase,
		roundIndex = state.roundIndex,
		roundKind = state.kind,
		roundTitle = YarnPartyCatalog.titleOf(state.kind),
		hint = YarnPartyCatalog.hintOf(state.kind),
		event = if clockNow() < state.eventUntil then state.event else nil,
		countdown = remain,
		yarnX = state.yarn.X,
		yarnZ = state.yarn.Z,
		safePads = { state.safe[1] == true, state.safe[2] == true, state.safe[3] == true, state.safe[4] == true },
		musicOn = state.musicOn,
		freeze = state.freeze,
		seats = seats,
		winnerName = state.winnerName,
		winnerId = state.winnerId,
		roundCount = YarnPartyCatalog.RoundCount,
	}
end

local function fire(state: Party)
	local snap = snapshotOf(state)
	for _, con in state.contestants do
		if con.player then
			Remotes.event("YarnPartyUpdated"):FireClient(con.player, snap)
		end
	end
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

local function restoreWalk(con: Contestant)
	if not con.player then
		return
	end
	local character = con.player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = con.walkSpeed
		humanoid.JumpPower = 50
	end
end

local function partyWalk(con: Contestant)
	if not con.player then
		return
	end
	local character = con.player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = YarnPartyCatalog.WalkSpeed
		humanoid.JumpPower = 55
	end
end

local function placeHuman(con: Contestant, index: number)
	if not con.player then
		return
	end
	local character = con.player.Character
	if not character then
		return
	end
	local cf = YarnPartyBuilder.spawnCFrame(index)
	pcall(function()
		character:PivotTo(cf)
	end)
	partyWalk(con)
end

local function rootOf(con: Contestant): BasePart?
	if con.model then
		local root = con.model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return root
		end
	end
	if con.player and con.player.Character then
		local root = con.player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return root
		end
	end
	return nil
end

local function aliveCount(state: Party): number
	local n = 0
	for _, con in state.contestants do
		if con.alive then
			n += 1
		end
	end
	return n
end

local function humanCount(state: Party): number
	local n = 0
	for _, con in state.contestants do
		if con.player then
			n += 1
		end
	end
	return n
end

local function findCon(state: Party, id: number): Contestant?
	for _, con in state.contestants do
		if con.id == id then
			return con
		end
	end
	return nil
end

local function eliminate(state: Party, con: Contestant, reason: string)
	if not con.alive then
		return
	end
	con.alive = false
	table.insert(state.elimOrder, con.id)
	shout(state, `{con.name}  ·  {reason}`, 1.35)
	fire(state)
end

local function awardRound(state: Party)
	local remaining: { Contestant } = {}
	for _, con in state.contestants do
		if con.alive then
			table.insert(remaining, con)
		end
	end
	local nextPlace = 1
	if #remaining == 1 then
		remaining[1].score += YarnPartyCatalog.pointsForPlace(1)
		nextPlace = 2
	else
		for _, con in remaining do
			con.score += YarnPartyCatalog.pointsForPlace(2)
		end
		nextPlace = #remaining + 1
	end
	for i = #state.elimOrder, 1, -1 do
		local con = findCon(state, state.elimOrder[i])
		if con then
			con.score += YarnPartyCatalog.pointsForPlace(nextPlace)
			nextPlace += 1
		end
	end
end

local function crown(state: Party)
	local rows = {}
	for _, con in state.contestants do
		table.insert(rows, { id = con.id, score = con.score, alive = con.alive })
	end
	local ranked = YarnPartyCatalog.rankByScore(rows)
	local winner = findCon(state, ranked[1])
	state.winnerId = if winner then winner.id else nil
	state.winnerName = if winner then winner.name else "Loaf"
	state.phase = "Podium"
	state.phaseEnds = clockNow() + 12
	shout(state, `{state.winnerName}  CROWNED`, 2.4)
	fire(state)
end

local function startIntro(state: Party)
	state.kind = YarnPartyCatalog.roundAt(state.roundIndex)
	state.phase = "Intro"
	state.phaseEnds = clockNow() + YarnPartyCatalog.IntroSeconds
	state.elimOrder = {}
	state.yarn = origin() + Vector3.new(0, 2.6, 0)
	state.yarnVel = Vector3.new(9, 0, 7)
	state.safe = { false, false, false, false }
	state.musicOn = true
	state.freeze = false
	state.pulseChecked = 0
	for _, con in state.contestants do
		con.alive = true
		con.jumpUntil = 0
	end
	for i, con in state.contestants do
		if con.isBot and con.model then
			local root = con.model:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				root.CFrame = YarnPartyBuilder.spawnCFrame(i)
			end
		else
			placeHuman(con, i)
		end
	end
	if state.kind == "Dodge" then
		YarnPartyBuilder.setYarn(state.yarn)
		YarnPartyBuilder.setPads({ false, false, false, false }, false)
	else
		YarnPartyBuilder.hideYarn()
		YarnPartyBuilder.setPads({ true, true, true, true }, false)
	end
	shout(state, YarnPartyCatalog.titleOf(state.kind), 2)
	fire(state)
end

local function startPlaying(state: Party)
	state.phase = "Playing"
	local dur = if state.kind == "Dodge" then YarnPartyCatalog.DodgeSeconds else YarnPartyCatalog.PillowSeconds
	state.phaseEnds = clockNow() + dur
	shout(state, "GO", 0.8)
	fire(state)
end

local function startRecap(state: Party)
	awardRound(state)
	state.phase = "Recap"
	state.phaseEnds = clockNow() + YarnPartyCatalog.RecapSeconds
	shout(state, `ROUND {state.roundIndex}  DONE`, 1.6)
	fire(state)
end

local function fillBots(state: Party)
	local used: { [string]: boolean } = {}
	for _, con in state.contestants do
		used[con.championId] = true
	end
	local botIndex = 0
	while #state.contestants < YarnPartyCatalog.SeatCount do
		botIndex += 1
		local champ = YarnPartyCatalog.botChampion(botIndex)
		if used[champ] then
			champ = YarnPartyCatalog.botChampion(botIndex + 1)
		end
		used[champ] = true
		local id = -500 - botIndex
		local name = YarnPartyCatalog.botName(botIndex)
		local slot = #state.contestants + 1
		local model = YarnPartyBuilder.spawnBot(id, name, champ, YarnPartyBuilder.spawnCFrame(slot))
		table.insert(state.contestants, {
			id = id,
			player = nil,
			name = name,
			championId = champ,
			isBot = true,
			alive = true,
			score = 0,
			model = model,
			walkSpeed = 16,
			jumpUntil = 0,
			charConn = nil,
		})
	end
end

local function moveBot(con: Contestant, dest: Vector3, dt: number, jumping: boolean)
	local root = rootOf(con)
	if not root then
		return
	end
	local pos = root.Position
	local y = if jumping then origin().Y + 6.2 else origin().Y + 3.2
	local delta = Vector3.new(dest.X - pos.X, 0, dest.Z - pos.Z)
	local step = dest
	if delta.Magnitude > 0.35 then
		local move = math.min(YarnPartyCatalog.WalkSpeed * dt, delta.Magnitude)
		step = pos + delta.Unit * move
	else
		step = pos
	end
	root.CFrame = CFrame.new(Vector3.new(step.X, y, step.Z), Vector3.new(dest.X, y, dest.Z))
end

local function botThink(state: Party, con: Contestant, dt: number)
	if not con.alive or not con.isBot then
		return
	end
	if state.kind == "Dodge" then
		local root = rootOf(con)
		if not root then
			return
		end
		local away = root.Position - Vector3.new(state.yarn.X, root.Position.Y, state.yarn.Z)
		local horiz = Vector3.new(away.X, 0, away.Z)
		local dest = root.Position
		if horiz.Magnitude < 9 then
			con.jumpUntil = clockNow() + 0.45
			if horiz.Magnitude > 0.1 then
				dest = root.Position + horiz.Unit * 8
			end
		else
			dest = origin() + Vector3.new(math.sin(clockNow() + con.id) * 8, 0, math.cos(clockNow() * 0.7 + con.id) * 8)
		end
		moveBot(con, dest, dt, clockNow() < con.jumpUntil)
	else
		local dest = origin()
		if state.freeze then
			for i, on in state.safe do
				if on then
					dest = YarnPartyBuilder.padWorld(i)
					break
				end
			end
		else
			local i = (math.abs(con.id) % 4) + 1
			dest = YarnPartyBuilder.padWorld(i)
		end
		moveBot(con, dest, dt, false)
	end
end

local function checkDodgeHits(state: Party)
	for _, con in state.contestants do
		if not con.alive then
			continue
		end
		local root = rootOf(con)
		if not root then
			continue
		end
		local dx = root.Position.X - state.yarn.X
		local dz = root.Position.Z - state.yarn.Z
		local dist = math.sqrt(dx * dx + dz * dz)
		local hopping = root.Position.Y >= origin().Y + YarnPartyCatalog.JumpSafeY or clockNow() < con.jumpUntil
		if dist <= YarnPartyCatalog.YarnRadius and not hopping then
			eliminate(state, con, "YARN BONK")
		end
	end
end

local function onPad(con: Contestant, index: number): boolean
	local root = rootOf(con)
	if not root then
		return false
	end
	local pad = YarnPartyBuilder.padWorld(index)
	local dx = root.Position.X - pad.X
	local dz = root.Position.Z - pad.Z
	return math.sqrt(dx * dx + dz * dz) <= YarnPartyCatalog.PadRadius
end

local function checkPillows(state: Party)
	for _, con in state.contestants do
		if not con.alive then
			continue
		end
		local safe = false
		for i, on in state.safe do
			if on and onPad(con, i) then
				safe = true
				break
			end
		end
		if not safe then
			eliminate(state, con, "WRONG PILLOW")
		end
	end
end

local function tickDodge(state: Party, dt: number)
	local nextPos = state.yarn + state.yarnVel * dt
	local half = YarnPartyCatalog.ArenaHalf
	local o = origin()
	if math.abs(nextPos.X - o.X) > half then
		state.yarnVel = Vector3.new(-state.yarnVel.X, 0, state.yarnVel.Z)
		nextPos = Vector3.new(o.X + math.clamp(nextPos.X - o.X, -half, half), nextPos.Y, nextPos.Z)
	end
	if math.abs(nextPos.Z - o.Z) > half then
		state.yarnVel = Vector3.new(state.yarnVel.X, 0, -state.yarnVel.Z)
		nextPos = Vector3.new(nextPos.X, nextPos.Y, o.Z + math.clamp(nextPos.Z - o.Z, -half, half))
	end
	state.yarn = Vector3.new(nextPos.X, o.Y + 2.6, nextPos.Z)
	YarnPartyBuilder.setYarn(state.yarn)
	checkDodgeHits(state)
end

local function tickPillows(state: Party)
	local elapsed = YarnPartyCatalog.PillowSeconds - math.max(0, state.phaseEnds - clockNow())
	local cycle = 5.1
	local pulse = math.floor(elapsed / cycle)
	local into = elapsed - pulse * cycle
	if into < 3.3 then
		state.musicOn = true
		state.freeze = false
		state.safe = { true, true, true, true }
		YarnPartyBuilder.setPads(state.safe, false)
	else
		if not state.freeze or state.pulseChecked ~= pulse then
			state.musicOn = false
			state.freeze = true
			local a = (pulse % 4) + 1
			local b = ((pulse + 2) % 4) + 1
			state.safe = { false, false, false, false }
			state.safe[a] = true
			state.safe[b] = true
			YarnPartyBuilder.setPads(state.safe, true)
			if state.pulseChecked ~= pulse then
				state.pulseChecked = pulse
				shout(state, "STALL FREEZE", 0.9)
				checkPillows(state)
			end
		end
	end
end

local function teardown()
	local state = party
	if not state then
		return
	end
	for _, con in state.contestants do
		if con.charConn then
			con.charConn:Disconnect()
		end
		restoreWalk(con)
		if con.player then
			ModeService.set(con.player, "Hub")
			sendHome(con.player)
		end
	end
	YarnPartyBuilder.clearBots()
	party = nil
end

local function bind()
	if bound then
		return
	end
	bound = true
	RunService.Heartbeat:Connect(function(dt)
		local state = party
		if not state then
			return
		end
		if humanCount(state) <= 0 then
			teardown()
			return
		end
		local now = clockNow()
		if state.phase == "Lobby" then
			if now >= state.phaseEnds then
				fillBots(state)
				state.roundIndex = 1
				startIntro(state)
			end
		elseif state.phase == "Intro" then
			if now >= state.phaseEnds then
				startPlaying(state)
			end
		elseif state.phase == "Playing" then
			if state.kind == "Dodge" then
				tickDodge(state, dt)
			else
				tickPillows(state)
			end
			for _, con in state.contestants do
				botThink(state, con, dt)
			end
			if aliveCount(state) <= 1 or now >= state.phaseEnds then
				startRecap(state)
			end
		elseif state.phase == "Recap" then
			if now >= state.phaseEnds then
				if state.roundIndex >= YarnPartyCatalog.RoundCount then
					crown(state)
				else
					state.roundIndex += 1
					startIntro(state)
				end
			end
		end
		state.sendAcc += dt
		if state.sendAcc >= 0.12 then
			state.sendAcc = 0
			fire(state)
		end
	end)
end

function YarnPartyService.playingCount(): number
	local state = party
	if not state then
		return 0
	end
	return humanCount(state)
end

function YarnPartyService.isPlaying(player: Player): boolean
	local state = party
	if not state then
		return false
	end
	for _, con in state.contestants do
		if con.player == player then
			return true
		end
	end
	return false
end

function YarnPartyService.start(player: Player): Types.TradeResult
	if ModeService.busyMatch() then
		return { ok = false, error = "Cat Rift is live on this server — try Yarn Party after." }
	end
	if ModeService.is(player, "Moba") then
		return { ok = false, error = "Leave the Rift first." }
	end
	if ModeService.is(player, "YarnRun") then
		return { ok = false, error = "Leave Yarn Run first." }
	end
	if ModeService.is(player, "KoiPond") then
		return { ok = false, error = "Leave the pond first." }
	end
	if YarnPartyService.isPlaying(player) then
		return { ok = false, error = "Already at the party." }
	end
	YarnPartyBuilder.ensure()
	bind()
	local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
	local walk = if humanoid then humanoid.WalkSpeed else 16
	local con: Contestant = {
		id = player.UserId,
		player = player,
		name = player.DisplayName,
		championId = "NyanRocket",
		isBot = false,
		alive = true,
		score = 0,
		model = nil,
		walkSpeed = walk,
		jumpUntil = 0,
		charConn = nil,
	}
	con.charConn = player.CharacterAdded:Connect(function()
		task.defer(function()
			local state = party
			if not state then
				return
			end
			for i, row in state.contestants do
				if row.id == player.UserId then
					placeHuman(row, i)
					return
				end
			end
		end)
	end)

	local state = party
	if state and state.phase == "Lobby" and #state.contestants < YarnPartyCatalog.SeatCount then
		table.insert(state.contestants, con)
		ModeService.set(player, "YarnParty")
		placeHuman(con, #state.contestants)
		shout(state, `{con.name} hopped in`, 1.1)
		fire(state)
		return { ok = true }
	end
	if state and state.phase ~= "Podium" and state.phase ~= "Lobby" then
		if con.charConn then
			con.charConn:Disconnect()
		end
		return { ok = false, error = "Party in progress — try after the crown." }
	end
	if state and state.phase == "Podium" then
		teardown()
	end

	local fresh: Party = {
		phase = "Lobby",
		roundIndex = 1,
		kind = "Dodge",
		phaseEnds = clockNow() + YarnPartyCatalog.CountdownSeconds,
		event = "Yarn Party · bots fill empty seats",
		eventUntil = clockNow() + 2,
		yarn = origin() + Vector3.new(0, 2.6, 0),
		yarnVel = Vector3.new(9, 0, 7),
		safe = { false, false, false, false },
		musicOn = true,
		freeze = false,
		pulseChecked = -1,
		contestants = { con },
		elimOrder = {},
		winnerName = nil,
		winnerId = nil,
		sendAcc = 1,
	}
	party = fresh
	ModeService.set(player, "YarnParty")
	placeHuman(con, 1)
	fire(fresh)
	return { ok = true }
end

function YarnPartyService.leave(player: Player): Types.TradeResult
	local state = party
	if not state then
		ModeService.set(player, "Hub")
		sendHome(player)
		return { ok = true }
	end
	local kept: { Contestant } = {}
	for _, con in state.contestants do
		if con.player == player then
			if con.charConn then
				con.charConn:Disconnect()
			end
			restoreWalk(con)
		else
			table.insert(kept, con)
		end
	end
	state.contestants = kept
	ModeService.set(player, "Hub")
	sendHome(player)
	if humanCount(state) <= 0 then
		YarnPartyBuilder.clearBots()
		party = nil
	else
		fire(state)
	end
	return { ok = true }
end

function YarnPartyService.retry(player: Player): Types.TradeResult
	YarnPartyService.leave(player)
	return YarnPartyService.start(player)
end

function YarnPartyService.clear(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		YarnPartyService.leave(player)
	end
end

return YarnPartyService
