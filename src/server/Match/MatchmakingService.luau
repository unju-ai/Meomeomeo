--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)
local MatchService = require(script.Parent.MatchService)
local MatchTeleport = require(script.Parent.MatchTeleport)
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local MatchmakingService = {}

local queue: { Player } = {}
local queuedAt: { [number]: number } = {}
local lastDifficulty: Types.BotDifficulty = Config.Bots.DefaultDifficulty
local queuePhase: Types.QueuePhase = "Idle"
local parties: { [number]: { number } } = {}
local pendingTeleport: Types.MatchTeleportData? = nil
local arrivalDeadline = 0

local function parseDifficulty(value: unknown): Types.BotDifficulty
	if value == "Easy" then
		return "Easy"
	elseif value == "Hard" then
		return "Hard"
	end
	return "Normal"
end

local function neededHumans(): number
	local cap = Config.Match.TeamSize * 2
	return math.clamp(Config.Match.MinPlayersToStart, 1, cap)
end

local function queued(player: Player): boolean
	return table.find(queue, player) ~= nil
end

local function remove(player: Player)
	local index = table.find(queue, player)
	if index then
		table.remove(queue, index)
	end
	queuedAt[player.UserId] = nil
end

local function snapshotQueue(): { Player }
	local living = {}
	for _, player in queue do
		if player.Parent then
			table.insert(living, player)
		else
			queuedAt[player.UserId] = nil
		end
	end
	queue = living
	return living
end

local function partyOf(userId: number): { number }
	for leader, members in parties do
		if leader == userId or table.find(members, userId) then
			local all = { leader }
			for _, member in members do
				if member ~= leader then
					table.insert(all, member)
				end
			end
			return all
		end
	end
	return { userId }
end

local function partyNames(userId: number): { string }
	local names = {}
	for _, id in partyOf(userId) do
		local player = Players:GetPlayerByUserId(id)
		table.insert(names, if player then player.DisplayName else `Cat {id}`)
	end
	return names
end

local function oldestWait(): number
	local now = Workspace:GetServerTimeNow()
	local best = 0
	for _, at in queuedAt do
		best = math.max(best, now - at)
	end
	return best
end

local function broadcastQueue()
	for _, player in Players:GetPlayers() do
		Remotes.event("QueueUpdated"):FireClient(player, MatchmakingService.statusFor(player))
	end
end

function MatchmakingService.statusFor(player: Player?): Types.QueueStatus
	local players = snapshotQueue()
	local need = neededHumans()
	local missing = math.max(0, need - #players)
	local waited = oldestWait()
	local estimated = if missing == 0 then 0 else missing * Config.Match.EstimatedSecondsPerMissing
	if Config.Match.PadQueueWithBots then
		estimated = math.min(estimated, math.max(0, Config.Match.MaxWaitSeconds - waited))
	end
	local inQueue = if player then queued(player) else false
	local phase = queuePhase
	if phase == "Idle" and #players > 0 then
		phase = "Queued"
	end
	local detail: string
	if phase == "Found" or phase == "Teleporting" then
		detail = if MatchTeleport.shouldReserve()
			then "Match found — reserving a private server…"
			else "Match found — starting draft here."
	elseif #players == 0 then
		detail = `Need {need} cat(s) to start. Set MinPlayersToStart to 6 or 10 for a real pop.`
	elseif missing > 0 then
		detail = `Waiting for {missing} more. Bots pad empty slots after {Config.Match.MaxWaitSeconds}s.`
	else
		detail = "Enough cats — forming a match."
	end
	return {
		phase = phase,
		mode = MatchTeleport.mode(),
		count = #players,
		needed = need,
		estimatedSeconds = math.floor(estimated),
		waitedSeconds = math.floor(waited),
		maxWaitSeconds = Config.Match.MaxWaitSeconds,
		inQueue = inQueue,
		detail = detail,
		party = if player then partyNames(player.UserId) else {},
		canCancel = inQueue and phase ~= "Found" and phase ~= "Teleporting",
	}
end

function MatchmakingService.queueCount(): number
	return #snapshotQueue()
end

local function assignSeats(players: { Player }): { Types.MatchTeleportSeat }
	local seats = {}
	for index, player in players do
		table.insert(seats, {
			userId = player.UserId,
			displayName = player.DisplayName,
			team = if index % 2 == 1 then "Blue" else "Red",
			championId = nil,
		})
	end
	return seats
end

local function startInPlace(players: { Player }, seats: { Types.MatchTeleportSeat })
	queuePhase = "Found"
	broadcastQueue()
	task.wait(0.7)
	local ok, err = MatchService.start(players, false, lastDifficulty, seats, {
		lobbyPlaceId = game.PlaceId,
		reserved = false,
		padWithBots = Config.Match.PadQueueWithBots,
	})
	queuePhase = "Idle"
	if not ok then
		for _, player in players do
			if player.Parent and not queued(player) then
				table.insert(queue, player)
				queuedAt[player.UserId] = queuedAt[player.UserId] or Workspace:GetServerTimeNow()
			end
		end
		broadcastQueue()
		return false, err
	end
	broadcastQueue()
	return true, nil
end

local function launchReserved(players: { Player }, seats: { Types.MatchTeleportSeat })
	queuePhase = "Found"
	broadcastQueue()
	local payload: Types.MatchTeleportData = {
		kind = "MeoMatch",
		matchId = `meo-{os.time()}-{players[1].UserId}`,
		lobbyPlaceId = game.PlaceId,
		practice = false,
		padWithBots = Config.Match.PadQueueWithBots,
		botDifficulty = lastDifficulty,
		seats = seats,
	}
	queuePhase = "Teleporting"
	broadcastQueue()
	local sent, err = MatchTeleport.reserveAndTeleport(players, payload)
	if not sent then
		warn(`[Meo Meo Meo] Reserved launch failed ({err}). Falling back in-place.`)
		return startInPlace(players, seats)
	end
	queuePhase = "Idle"
	broadcastQueue()
	return true, nil
end

local function tryForm(force: boolean?)
	if MatchService.isBusy() then
		return
	end
	if MatchTeleport.isReservedInstance() then
		return
	end
	if queuePhase == "Found" or queuePhase == "Teleporting" then
		return
	end
	local players = snapshotQueue()
	local need = neededHumans()
	local waited = oldestWait()
	local enough = #players >= need
	local timedOut = force
		or (
			Config.Match.PadQueueWithBots
			and #players > 0
			and waited >= Config.Match.MaxWaitSeconds
		)
	if not enough and not timedOut then
		return
	end

	local take = math.min(#players, Config.Match.TeamSize * 2)
	local taken = {}
	for i = 1, take do
		table.insert(taken, players[i])
	end
	for _, player in taken do
		remove(player)
	end
	local seats = assignSeats(taken)
	task.spawn(function()
		if MatchTeleport.shouldReserve() then
			launchReserved(taken, seats)
		else
			startInPlace(taken, seats)
		end
	end)
end

function MatchmakingService.queue(player: Player): Types.TradeResult
	if MatchTeleport.isReservedInstance() then
		return { ok = false, error = "This reserved match instance is not a queue lobby." }
	end
	if MatchService.isBusy() then
		return { ok = false, error = "A match is already running on this server." }
	end
	if queuePhase == "Found" or queuePhase == "Teleporting" then
		return { ok = false, error = "A match is already forming." }
	end
	local invited = partyOf(player.UserId)
	local added = 0
	for _, userId in invited do
		local member = Players:GetPlayerByUserId(userId)
		if member and not queued(member) then
			table.insert(queue, member)
			queuedAt[member.UserId] = Workspace:GetServerTimeNow()
			added += 1
		end
	end
	if added == 0 and queued(player) then
		return { ok = false, error = "Already in queue." }
	end
	queuePhase = "Queued"
	broadcastQueue()
	tryForm(false)
	return { ok = true }
end

function MatchmakingService.leave(player: Player): Types.TradeResult
	if queuePhase == "Found" or queuePhase == "Teleporting" then
		return { ok = false, error = "Too late — match is already found." }
	end
	if not queued(player) then
		return { ok = false, error = "Not in queue." }
	end
	remove(player)
	if #snapshotQueue() == 0 then
		queuePhase = "Idle"
	end
	broadcastQueue()
	return { ok = true }
end

function MatchmakingService.invite(player: Player, targetUserId: unknown): Types.TradeResult
	if typeof(targetUserId) ~= "number" then
		local other: Player? = nil
		for _, candidate in Players:GetPlayers() do
			if candidate ~= player then
				other = candidate
				break
			end
		end
		if not other then
			return { ok = false, error = "No friend in this server to invite." }
		end
		targetUserId = other.UserId
	end
	local target = Players:GetPlayerByUserId(targetUserId :: number)
	if not target then
		return { ok = false, error = "That cat is not in this lobby." }
	end
	if target == player then
		return { ok = false, error = "You are already in your party." }
	end
	local leader = player.UserId
	for otherLeader, members in parties do
		if otherLeader ~= leader and (otherLeader == target.UserId or table.find(members, target.UserId)) then
			return { ok = false, error = "They are already in another party." }
		end
	end
	local bag = parties[leader]
	if not bag then
		bag = {}
		parties[leader] = bag
	end
	if table.find(bag, target.UserId) then
		return { ok = true }
	end
	if 1 + #bag >= Config.Match.TeamSize then
		return { ok = false, error = "Party is full." }
	end
	table.insert(bag, target.UserId)
	broadcastQueue()
	return { ok = true }
end

function MatchmakingService.practice(player: Player, difficulty: unknown): Types.TradeResult
	if not Config.Match.PracticeEnabled then
		return { ok = false, error = "Practice is disabled." }
	end
	if MatchService.isBusy() then
		return { ok = false, error = "A match is already running." }
	end
	remove(player)
	lastDifficulty = parseDifficulty(difficulty)
	local ok, err = MatchService.start({ player }, true, lastDifficulty)
	if not ok then
		return { ok = false, error = err }
	end
	broadcastQueue()
	return { ok = true }
end

local function sendHumansHome()
	if not MatchTeleport.isReservedInstance() and not MatchService.isReserved() then
		return false
	end
	local lobbyId = MatchService.lobbyPlaceId()
	local humans = {}
	for _, player in Players:GetPlayers() do
		table.insert(humans, player)
	end
	return MatchTeleport.returnToLobby(humans, lobbyId)
end

function MatchmakingService.leaveMatch(_player: Player): Types.TradeResult
	if not MatchService.snapshot() then
		return { ok = true }
	end
	if not MatchService.isEnded() then
		return { ok = false, error = "Wait for the match to end." }
	end
	if sendHumansHome() then
		return { ok = true }
	end
	MatchService.returnToLobby(true)
	broadcastQueue()
	return { ok = true }
end

function MatchmakingService.playAgain(player: Player): Types.TradeResult
	if MatchService.snapshot() and not MatchService.isEnded() then
		return { ok = false, error = "The match is still on." }
	end
	if MatchService.isEnded() then
		if MatchTeleport.isReservedInstance() or MatchService.isReserved() then
			sendHumansHome()
			return { ok = true }
		end
		MatchService.returnToLobby(false)
	end
	return MatchmakingService.practice(player, lastDifficulty)
end

local function tryStartArrivals()
	if not pendingTeleport or MatchService.isBusy() then
		return
	end
	local present = MatchTeleport.presentSeats(pendingTeleport.seats)
	local expected = #pendingTeleport.seats
	local now = Workspace:GetServerTimeNow()
	if #present < expected and now < arrivalDeadline then
		return
	end
	if #present == 0 then
		return
	end
	local payload = pendingTeleport
	pendingTeleport = nil
	MatchService.start(present, false, payload.botDifficulty, payload.seats, {
		lobbyPlaceId = payload.lobbyPlaceId,
		reserved = true,
		padWithBots = payload.padWithBots,
		matchId = payload.matchId,
	})
end

function MatchmakingService.init()
	Players.PlayerRemoving:Connect(function(player)
		remove(player)
		parties[player.UserId] = nil
		for _, members in parties do
			local index = table.find(members, player.UserId)
			if index then
				table.remove(members, index)
			end
		end
		broadcastQueue()
	end)
	MatchService.init(function()
		tryForm(false)
		broadcastQueue()
	end)

	if MatchTeleport.isReservedInstance() then
		queuePhase = "Teleporting"
		Players.PlayerAdded:Connect(function(player)
			local data = MatchTeleport.read(player)
			if data then
				pendingTeleport = pendingTeleport or data
				if arrivalDeadline == 0 then
					arrivalDeadline = Workspace:GetServerTimeNow() + Config.Match.ArrivalTimeoutSeconds
				end
			end
			task.defer(tryStartArrivals)
		end)
		for _, player in Players:GetPlayers() do
			local data = MatchTeleport.read(player)
			if data then
				pendingTeleport = pendingTeleport or data
				if arrivalDeadline == 0 then
					arrivalDeadline = Workspace:GetServerTimeNow() + Config.Match.ArrivalTimeoutSeconds
				end
			end
		end
		if arrivalDeadline == 0 then
			arrivalDeadline = Workspace:GetServerTimeNow() + Config.Match.ArrivalTimeoutSeconds
		end
		task.defer(tryStartArrivals)
		task.spawn(function()
			while pendingTeleport and not MatchService.isBusy() do
				task.wait(1)
				tryStartArrivals()
			end
		end)
	end

	task.spawn(function()
		while true do
			task.wait(1)
			if MatchTeleport.isReservedInstance() then
				continue
			end
			if not MatchService.isBusy() then
				tryForm(false)
			end
			if #snapshotQueue() > 0 or queuePhase ~= "Idle" then
				broadcastQueue()
			end
		end
	end)
end

return MatchmakingService
