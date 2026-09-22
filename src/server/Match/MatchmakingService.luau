--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)
local MatchService = require(script.Parent.MatchService)
local MatchTeleport = require(script.Parent.MatchTeleport)
local ModeService = require(script.Parent.Parent.Mode.ModeService)
local CatRiftParty = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CatRiftParty"))
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local MatchmakingService = {}

local queue: { Player } = {}
local queuedAt: { [number]: number } = {}
local lastDifficulty: Types.BotDifficulty = Config.Bots.DefaultDifficulty
local queuePhase: Types.QueuePhase = "Idle"
local partyState = CatRiftParty.empty()
local pendingTeleport: Types.MatchTeleportData? = nil
local NOTICE_FRESH_SECONDS = 12
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

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function displayName(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.DisplayName
	end
	return "Cat"
end

local function nameMap(): { [number]: string }
	local names: { [number]: string } = {}
	for _, player in Players:GetPlayers() do
		names[player.UserId] = player.DisplayName
	end
	return names
end

local function partyOptions(): CatRiftParty.Options
	return {
		ttl = CatRiftParty.InviteSeconds,
		maxSize = Config.Match.TeamSize,
		names = nameMap(),
		now = now(),
	}
end

local function riftFree(member: Player): boolean
	return ModeService.get(member) == "Hub"
end

local function partyEditsOpen(): (boolean, string?)
	if queuePhase == "Found" or queuePhase == "Teleporting" then
		return false, "A match is already forming."
	end
	if MatchService.isBusy() and not MatchService.isEnded() then
		return false, "Wait until you're back in the lobby."
	end
	return true, nil
end

local function partyLabels(userId: number): { string }
	if CatRiftParty.role(partyState, userId) == "solo" then
		return {}
	end
	local leader = CatRiftParty.leaderOf(partyState, userId)
	local labels = {}
	for _, id in CatRiftParty.membersOf(partyState, userId) do
		local name = if id == userId then "You" else displayName(id)
		if id == leader then
			name ..= " (leader)"
		end
		table.insert(labels, name)
	end
	return labels
end

local function partyMemberIds(userId: number): { number }
	if CatRiftParty.role(partyState, userId) == "solo" then
		return {}
	end
	return CatRiftParty.membersOf(partyState, userId)
end

local function inviteCard(invite: CatRiftParty.Invite?, at: number, incoming: boolean): Types.PartyInviteCard?
	if not invite then
		return nil
	end
	if incoming then
		return {
			fromUserId = invite.fromUserId,
			fromName = displayName(invite.fromUserId),
			expiresIn = math.max(0, invite.expiresAt - at),
		}
	end
	return {
		toUserId = invite.toUserId,
		toName = displayName(invite.toUserId),
		expiresIn = math.max(0, invite.expiresAt - at),
	}
end

local function freshNotice(userId: number, at: number): (number?, string?)
	local notice = partyState.notices[userId]
	if notice and at - notice.at <= NOTICE_FRESH_SECONDS then
		return notice.id, notice.text
	end
	return nil, nil
end

local function pickTarget(player: Player): Player?
	local fallback: Player? = nil
	for _, candidate in Players:GetPlayers() do
		if candidate ~= player and not CatRiftParty.sameParty(partyState, player.UserId, candidate.UserId) then
			if CatRiftParty.role(partyState, candidate.UserId) == "solo" then
				return candidate
			end
			if not fallback then
				fallback = candidate
			end
		end
	end
	return fallback
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
			else "Match found — starting draft in-place."
	elseif #players == 0 then
		detail = `Need {need} cat(s) to start. Set MinPlayersToStart to 6 or 10 for a real pop.`
	elseif missing > 0 then
		detail = `Waiting for {missing} more. Bots pad empty slots after {Config.Match.MaxWaitSeconds}s.`
	else
		detail = "Enough cats — forming a match."
	end
	local at = now()
	local noticeId: number? = nil
	local noticeText: string? = nil
	if player then
		noticeId, noticeText = freshNotice(player.UserId, at)
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
		party = if player then partyLabels(player.UserId) else {},
		canCancel = inQueue and phase ~= "Found" and phase ~= "Teleporting",
		partyRole = if player then CatRiftParty.role(partyState, player.UserId) else "solo",
		partyMemberIds = if player then partyMemberIds(player.UserId) else {},
		incomingInvite = if player then inviteCard(CatRiftParty.incoming(partyState, player.UserId, at), at, true) else nil,
		outgoingInvite = if player then inviteCard(CatRiftParty.outgoing(partyState, player.UserId, at), at, false) else nil,
		noticeId = noticeId,
		notice = noticeText,
	}
end

function MatchmakingService.queueCount(): number
	return #snapshotQueue()
end

local function assignSeats(players: { Player }): { Types.MatchTeleportSeat }
	local ids = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	local teams = CatRiftParty.assignTeams(partyState, ids, Config.Match.TeamSize)
	local seats = {}
	for _, player in players do
		table.insert(seats, {
			userId = player.UserId,
			displayName = player.DisplayName,
			team = teams[player.UserId] or "Blue",
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
	local ids = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	local selectedIds = CatRiftParty.selectForMatch(partyState, ids, Config.Match.TeamSize * 2)
	local enough = #selectedIds >= need
	local timedOut = force
		or (
			Config.Match.PadQueueWithBots
			and #selectedIds > 0
			and waited >= Config.Match.MaxWaitSeconds
		)
	if not enough and not timedOut then
		return
	end
	if #selectedIds == 0 then
		return
	end

	local taken = {}
	for _, userId in selectedIds do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			table.insert(taken, player)
		end
	end
	for _, player in taken do
		remove(player)
	end
	if #taken == 0 then
		return
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
	local options = partyOptions()
	local roster, rosterError = CatRiftParty.queueRoster(partyState, player.UserId, options.names)
	if not roster then
		return { ok = false, error = rosterError }
	end
	local added = 0
	local skipped = {}
	local joined: { Player } = {}
	for _, userId in roster do
		local member = Players:GetPlayerByUserId(userId)
		if member and riftFree(member) and not queued(member) then
			table.insert(queue, member)
			queuedAt[member.UserId] = options.now
			added += 1
			table.insert(joined, member)
		elseif member and member ~= player and not riftFree(member) then
			table.insert(skipped, member)
		end
	end
	if added == 0 and queued(player) then
		return { ok = false, error = "Already in queue." }
	end
	if added == 0 then
		return { ok = false, error = "Nobody in the party could queue." }
	end
	for _, member in joined do
		if member ~= player then
			partyState = CatRiftParty.tell(partyState, member.UserId, `{player.DisplayName} queued the party.`, options.now)
		end
	end
	for _, member in skipped do
		partyState = CatRiftParty.tell(
			partyState,
			member.UserId,
			`{player.DisplayName} queued the party. You're in another stall, so you stayed out.`,
			options.now
		)
	end
	local skippedNames = {}
	for _, member in skipped do
		table.insert(skippedNames, member.DisplayName)
	end
	local text = if #roster > 1 then "Party queued." else "Queued — waiting for more cats."
	if #skippedNames > 0 then
		text ..= ` {table.concat(skippedNames, ", ")} stayed in another stall.`
	end
	partyState = CatRiftParty.tell(partyState, player.UserId, text, options.now)
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
	local options = partyOptions()
	local role = CatRiftParty.role(partyState, player.UserId)
	if role == "leader" and #CatRiftParty.membersOf(partyState, player.UserId) > 1 then
		for _, userId in CatRiftParty.leaveQueueRoster(partyState, player.UserId) do
			local member = Players:GetPlayerByUserId(userId)
			if member and queued(member) then
				remove(member)
				if member ~= player then
					partyState = CatRiftParty.tell(
						partyState,
						userId,
						`{player.DisplayName} left the queue, so the party did too.`,
						options.now
					)
				end
			end
		end
		partyState = CatRiftParty.tell(partyState, player.UserId, "Party left the queue.", options.now)
	else
		remove(player)
		if role == "member" then
			local leaderId = CatRiftParty.leaderOf(partyState, player.UserId)
			if leaderId then
				partyState = CatRiftParty.tell(partyState, leaderId, `{player.DisplayName} left the queue.`, options.now)
			end
			partyState = CatRiftParty.tell(partyState, player.UserId, "You left the queue.", options.now)
		end
	end
	if #snapshotQueue() == 0 then
		queuePhase = "Idle"
	end
	broadcastQueue()
	return { ok = true }
end

function MatchmakingService.invite(player: Player, targetUserId: unknown): Types.TradeResult
	local open, closed = partyEditsOpen()
	if not open then
		return { ok = false, error = closed }
	end
	local target: Player? = nil
	if typeof(targetUserId) == "number" then
		target = Players:GetPlayerByUserId(targetUserId)
		if not target then
			return { ok = false, error = "That cat is not in this lobby." }
		end
	else
		target = pickTarget(player)
		if not target then
			return { ok = false, error = "No friend in this server to invite." }
		end
	end
	if target == player then
		return { ok = false, error = "You are already in your party." }
	end
	local result: CatRiftParty.Result
	partyState, result = CatRiftParty.invite(partyState, player.UserId, target.UserId, partyOptions())
	broadcastQueue()
	if not result.ok then
		return { ok = false, error = result.error }
	end
	return { ok = true }
end

function MatchmakingService.acceptInvite(player: Player): Types.TradeResult
	local open, closed = partyEditsOpen()
	if not open then
		return { ok = false, error = closed }
	end
	local options = partyOptions()
	local incoming = CatRiftParty.incoming(partyState, player.UserId, options.now)
	if incoming and not Players:GetPlayerByUserId(incoming.fromUserId) then
		partyState = CatRiftParty.disconnect(partyState, incoming.fromUserId, options)
		broadcastQueue()
		return { ok = false, error = "That cat left the lobby." }
	end
	local result: CatRiftParty.Result
	partyState, result = CatRiftParty.accept(partyState, player.UserId, options)
	if not result.ok then
		broadcastQueue()
		return { ok = false, error = result.error }
	end
	local leaderId = CatRiftParty.leaderOf(partyState, player.UserId)
	local leader = if leaderId then Players:GetPlayerByUserId(leaderId) else nil
	if leader and queued(leader) and riftFree(player) and not queued(player) then
		table.insert(queue, player)
		queuedAt[player.UserId] = options.now
		if queuePhase == "Idle" then
			queuePhase = "Queued"
		end
		partyState = CatRiftParty.tell(partyState, player.UserId, "You joined the party and the queue.", options.now)
		partyState = CatRiftParty.tell(
			partyState,
			leader.UserId,
			`{player.DisplayName} joined the party and the queue.`,
			options.now
		)
	end
	broadcastQueue()
	tryForm(false)
	return { ok = true }
end

function MatchmakingService.declineInvite(player: Player): Types.TradeResult
	local result: CatRiftParty.Result
	partyState, result = CatRiftParty.decline(partyState, player.UserId, partyOptions())
	broadcastQueue()
	if not result.ok then
		return { ok = false, error = result.error }
	end
	return { ok = true }
end

function MatchmakingService.leaveParty(player: Player): Types.TradeResult
	local open, closed = partyEditsOpen()
	if not open then
		return { ok = false, error = closed }
	end
	if CatRiftParty.role(partyState, player.UserId) == "solo" then
		return { ok = false, error = "You are not in a party." }
	end
	local options = partyOptions()
	local roster = CatRiftParty.membersOf(partyState, player.UserId)
	local wasLeader = CatRiftParty.role(partyState, player.UserId) == "leader"
	local wasQueued: { [number]: boolean } = {}
	for _, userId in roster do
		local member = Players:GetPlayerByUserId(userId)
		wasQueued[userId] = member ~= nil and queued(member)
	end
	local result: CatRiftParty.Result
	partyState, result = CatRiftParty.leave(partyState, player.UserId, options)
	if not result.ok then
		return { ok = false, error = result.error }
	end
	local pull = if wasLeader then roster else { player.UserId }
	local pulled = false
	for _, userId in pull do
		if wasQueued[userId] then
			local member = Players:GetPlayerByUserId(userId)
			if member then
				remove(member)
			end
			pulled = true
		end
	end
	if pulled then
		if wasLeader then
			for _, userId in roster do
				if wasQueued[userId] then
					local text = if userId == player.UserId
						then "You left the party and the queue."
						else `{player.DisplayName} left the party, so you left the queue.`
					partyState = CatRiftParty.tell(partyState, userId, text, options.now)
				end
			end
		else
			partyState = CatRiftParty.tell(partyState, player.UserId, "You left the party and the queue.", options.now)
			local oldLeader = roster[1]
			if oldLeader and oldLeader ~= player.UserId then
				partyState = CatRiftParty.tell(
					partyState,
					oldLeader,
					`{player.DisplayName} left the party and the queue.`,
					options.now
				)
			end
		end
	end
	if #snapshotQueue() == 0 and queuePhase ~= "Found" and queuePhase ~= "Teleporting" then
		queuePhase = "Idle"
	end
	broadcastQueue()
	return { ok = true }
end

function MatchmakingService.practice(player: Player, difficulty: unknown, anyMember: boolean?): Types.TradeResult
	if not Config.Match.PracticeEnabled then
		return { ok = false, error = "Practice is disabled." }
	end
	if MatchService.isBusy() then
		return { ok = false, error = "A match is already running." }
	end
	local options = partyOptions()
	local roster, rosterError = CatRiftParty.practiceRoster(partyState, player.UserId, options.names, anyMember == true)
	if not roster then
		return { ok = false, error = rosterError }
	end
	if not riftFree(player) then
		return { ok = false, error = "Leave the other stall before Practice." }
	end
	local humans = {}
	local skipped = {}
	for _, userId in roster do
		local member = Players:GetPlayerByUserId(userId)
		if member and riftFree(member) then
			remove(member)
			table.insert(humans, member)
		elseif member and member ~= player then
			table.insert(skipped, member.DisplayName)
		end
	end
	if not table.find(humans, player) then
		return { ok = false, error = "Leave the other stall before Practice." }
	end
	lastDifficulty = parseDifficulty(difficulty)
	-- In-place. Party humans share Blue. Practice adds PracticeAllies Blue bots
	-- and PracticeEnemies Red bots, all on lastDifficulty. MatchPlaceId stays unused.
	local ok, err = MatchService.start(humans, true, lastDifficulty)
	if not ok then
		return { ok = false, error = err }
	end
	if #humans > 1 then
		local extra = if #skipped > 0 then ` {table.concat(skipped, ", ")} stayed in another stall.` else ""
		for _, member in humans do
			partyState = CatRiftParty.tell(
				partyState,
				member.UserId,
				`Practice with your party — Blue team, {Config.Bots.PracticeAllies} ally bots, {Config.Bots.PracticeEnemies} red bots.{extra}`,
				options.now
			)
		end
	elseif #skipped > 0 then
		partyState = CatRiftParty.tell(
			partyState,
			player.UserId,
			`{table.concat(skipped, ", ")} stayed in another stall.`,
			options.now
		)
	end
	if #snapshotQueue() == 0 then
		queuePhase = "Idle"
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
	return MatchmakingService.practice(player, lastDifficulty, true)
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
		local options = partyOptions()
		options.names[player.UserId] = player.DisplayName
		partyState = CatRiftParty.disconnect(partyState, player.UserId, options)
		if #snapshotQueue() == 0 and queuePhase == "Queued" then
			queuePhase = "Idle"
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
			local options = partyOptions()
			local swept
			partyState, swept = CatRiftParty.sweep(partyState, options)
			if not MatchService.isBusy() then
				tryForm(false)
			end
			local pending = CatRiftParty.pendingCount(partyState, options.now)
			if #snapshotQueue() > 0 or queuePhase ~= "Idle" or pending > 0 or swept then
				broadcastQueue()
			end
		end
	end)
end

return MatchmakingService
