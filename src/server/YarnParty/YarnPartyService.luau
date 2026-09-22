--!strict

-- Server-authoritative Yarn Party. 3 micro-rounds.
-- Lobby keeps seats 1–4 filled; a human Play reclaims a bot seat.
-- Mid-round Play waits for the next party and does not enter combat.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local YarnPartyCatalog = require(Shared:WaitForChild("YarnPartyCatalog"))
local YarnPartyLobby = require(Shared:WaitForChild("YarnPartyLobby"))

type Seat = YarnPartyLobby.Seat

local ModeService = require(script.Parent.Parent.Mode.ModeService)
local CosmeticService = require(script.Parent.Parent.Cosmetics.CosmeticService)
local YarnPartyBuilder = require(script.Parent.YarnPartyBuilder)

type Contestant = {
	id: number,
	player: Player?,
	name: string,
	championId: string,
	isBot: boolean,
	kind: YarnPartyLobby.SeatKind,
	botSlot: number?,
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

local function seatOf(con: Contestant, index: number): Types.YarnPartySeat
	local open = con.kind == "empty"
	return {
		id = con.id,
		name = if open then "Open" else con.name,
		championId = con.championId,
		isBot = con.kind == "bot",
		alive = not open and con.alive,
		score = con.score,
		seat = index,
	}
end

local function snapshotOf(state: Party): Types.YarnPartySnapshot
	local seats = {}
	for i, con in state.contestants do
		if state.phase ~= "Lobby" and con.kind == "empty" then
			continue
		end
		table.insert(seats, seatOf(con, i))
	end
	if state.phase ~= "Lobby" then
		table.sort(seats, function(a, b)
			if a.score ~= b.score then
				return a.score > b.score
			end
			return a.id < b.id
		end)
	end
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
	local player = con.player
	if not player then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local cf = YarnPartyBuilder.spawnCFrame(index)
	pcall(function()
		character:PivotTo(cf)
	end)
	partyWalk(con)
	CosmeticService.dress(player)
end

local function characterReady(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart")
end

local function placeHumanSoon(con: Contestant, index: number)
	local player = con.player
	if not player then
		return
	end
	if characterReady(player) then
		placeHuman(con, index)
		return
	end
	task.spawn(function()
		for _ = 1, 12 do
			local state = party
			if not state or state.contestants[index] ~= con then
				return
			end
			if characterReady(player) then
				placeHuman(con, index)
				return
			end
			task.wait(0.15)
		end
	end)
end

local function dropRuntime(con: Contestant)
	if con.charConn then
		con.charConn:Disconnect()
		con.charConn = nil
	end
	if con.model then
		con.model:Destroy()
		con.model = nil
	end
end

local function makeEmpty(): Contestant
	return {
		id = 0,
		player = nil,
		name = "",
		championId = "",
		isBot = false,
		kind = "empty",
		botSlot = nil,
		alive = false,
		score = 0,
		model = nil,
		walkSpeed = 16,
		jumpUntil = 0,
		charConn = nil,
	}
end

local function makeBot(seat: Seat): Contestant
	local id = -500 - seat.index
	local model = YarnPartyBuilder.spawnBot(id, seat.name, seat.championId, YarnPartyBuilder.spawnCFrame(seat.index))
	return {
		id = id,
		player = nil,
		name = seat.name,
		championId = seat.championId,
		isBot = true,
		kind = "bot",
		botSlot = seat.botSlot,
		alive = true,
		score = 0,
		model = model,
		walkSpeed = 16,
		jumpUntil = 0,
		charConn = nil,
	}
end

local function makeHuman(player: Player, seat: Seat): Contestant
	local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
	local walk = if humanoid then humanoid.WalkSpeed else 16
	local con: Contestant = {
		id = player.UserId,
		player = player,
		name = if seat.name ~= "" then seat.name else player.DisplayName,
		championId = if seat.championId ~= "" then seat.championId else YarnPartyLobby.HumanChampion,
		isBot = false,
		kind = "human",
		botSlot = nil,
		alive = true,
		score = seat.score,
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
				if row == con then
					placeHumanSoon(con, i)
					return
				end
			end
		end)
	end)
	return con
end

local function seatsFrom(state: Party): { Seat }
	local seats = {}
	for i, con in state.contestants do
		seats[i] = {
			index = i,
			kind = con.kind,
			userId = if con.kind == "human" and con.player then con.player.UserId else nil,
			name = con.name,
			botSlot = con.botSlot,
			championId = con.championId,
			alive = con.alive,
			score = con.score,
		}
	end
	return seats
end

local function sameOccupant(con: Contestant, seat: Seat): boolean
	if con.kind ~= seat.kind then
		return false
	end
	if seat.kind == "human" then
		return con.player ~= nil and con.player.UserId == seat.userId
	end
	if seat.kind == "bot" then
		return con.botSlot == seat.botSlot
	end
	return true
end

local function adoptBots(state: Party, seats: { Seat })
	for i, seat in seats do
		local prev = state.contestants[i]
		if seat.kind == "human" or (prev and sameOccupant(prev, seat)) then
			continue
		end
		if prev then
			dropRuntime(prev)
		end
		if seat.kind == "bot" then
			state.contestants[i] = makeBot(seat)
		elseif seat.kind == "empty" then
			state.contestants[i] = makeEmpty()
		end
	end
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
		if con.kind ~= "empty" and con.alive then
			n += 1
		end
	end
	return n
end

local function humanCount(state: Party): number
	local n = 0
	for _, con in state.contestants do
		if con.kind == "human" and con.player then
			n += 1
		end
	end
	return n
end

local function findCon(state: Party, id: number): Contestant?
	if id == 0 then
		return nil
	end
	for _, con in state.contestants do
		if con.kind ~= "empty" and con.id == id then
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
		if con.kind ~= "empty" and con.alive then
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
		if con.kind ~= "empty" then
			table.insert(rows, { id = con.id, score = con.score, alive = con.alive })
		end
	end
	local ranked = YarnPartyCatalog.rankByScore(rows)
	local winner = findCon(state, ranked[1])
	state.winnerId = if winner then winner.id else nil
	state.winnerName = if winner then winner.name else "Loaf"
	state.phase = "Podium"
	state.phaseEnds = clockNow() + 12
	shout(state, `{state.winnerName}  CROWNED`, 2.4)
	if winner and winner.player and not winner.isBot then
		ModeService.notePartyWin(winner.player.UserId)
		CosmeticService.refresh(winner.player)
	end
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
	for i, con in state.contestants do
		if con.kind == "empty" then
			continue
		end
		con.alive = true
		con.jumpUntil = 0
		if con.kind == "bot" and con.model then
			local root = con.model:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				root.CFrame = YarnPartyBuilder.spawnCFrame(i)
			end
		elseif con.kind == "human" then
			placeHumanSoon(con, i)
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
				adoptBots(state, YarnPartyLobby.ensureBots(seatsFrom(state)))
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
	if ModeService.is(player, "MemeArcade") then
		return { ok = false, error = "Leave the arcade first." }
	end
	if YarnPartyService.isPlaying(player) then
		return { ok = false, error = "Already at the party." }
	end
	YarnPartyBuilder.ensure()
	bind()

	local state = party
	if state then
		if state.phase ~= "Lobby" then
			return { ok = false, error = YarnPartyLobby.waitCopy(state.phase) }
		end
		local remaining = math.max(0, state.phaseEnds - clockNow())
		local newSeats, decision = YarnPartyLobby.claim(seatsFrom(state), "Lobby", player.UserId, player.DisplayName, remaining)
		if decision.action ~= "seated" or not decision.seat then
			return { ok = false, error = decision.error or "Could not join the party." }
		end
		local idx = decision.seat
		local prev = state.contestants[idx]
		if prev then
			dropRuntime(prev)
		end
		local con = makeHuman(player, newSeats[idx])
		state.contestants[idx] = con
		if decision.countdown and decision.countdown > remaining + 0.001 then
			state.phaseEnds = clockNow() + decision.countdown
		end
		ModeService.set(player, "YarnParty")
		placeHumanSoon(con, idx)
		shout(state, `{con.name} took seat {idx}`, 1.4)
		fire(state)
		return { ok = true }
	end

	local seats = YarnPartyLobby.open(player.UserId, player.DisplayName)
	local contestants: { Contestant } = {}
	for i, seat in seats do
		if seat.kind == "human" then
			contestants[i] = makeHuman(player, seat)
		elseif seat.kind == "bot" then
			contestants[i] = makeBot(seat)
		else
			contestants[i] = makeEmpty()
		end
	end
	local fresh: Party = {
		phase = "Lobby",
		roundIndex = 1,
		kind = "Dodge",
		phaseEnds = clockNow() + YarnPartyCatalog.CountdownSeconds,
		event = "Seats 1–4 · bots hold the open ones",
		eventUntil = clockNow() + 2.2,
		yarn = origin() + Vector3.new(0, 2.6, 0),
		yarnVel = Vector3.new(9, 0, 7),
		safe = { false, false, false, false },
		musicOn = true,
		freeze = false,
		pulseChecked = -1,
		contestants = contestants,
		elimOrder = {},
		winnerName = nil,
		winnerId = nil,
		sendAcc = 1,
	}
	party = fresh
	ModeService.set(player, "YarnParty")
	placeHumanSoon(contestants[1], 1)
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
	local idx = 0
	for i, con in state.contestants do
		if con.player == player then
			idx = i
			break
		end
	end
	if idx == 0 then
		ModeService.set(player, "Hub")
		sendHome(player)
		return { ok = true }
	end
	local con = state.contestants[idx]
	restoreWalk(con)
	local newSeats, decision = YarnPartyLobby.release(seatsFrom(state), state.phase, player.UserId)
	dropRuntime(con)
	con.player = nil
	ModeService.set(player, "Hub")
	sendHome(player)
	if decision.partyEmpty then
		teardown()
		return { ok = true }
	end
	if decision.refilledBot then
		state.contestants[idx] = makeBot(newSeats[idx])
		shout(state, `{newSeats[idx].name} took seat {idx}`, 1.2)
	else
		state.contestants[idx] = makeEmpty()
	end
	fire(state)
	return { ok = true }
end

function YarnPartyService.retry(player: Player): Types.TradeResult
	local wasIn = YarnPartyService.isPlaying(player)
	YarnPartyService.leave(player)
	local state = party
	if wasIn and state and state.phase == "Podium" then
		teardown()
	end
	return YarnPartyService.start(player)
end

function YarnPartyService.clear(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		YarnPartyService.leave(player)
	end
end

return YarnPartyService
