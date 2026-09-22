--!strict

-- Cat Rift early remake vote. Pure rules — MatchService owns the clock and
-- the match-end call. Bots are never an electorate and never start a vote.
-- Practice can start any time the window is open so a solo fight is testable.
-- A real fight also needs an allied human who never connected or already left.
-- Hub modes do not call this. Surrender stays on its own clock.

local RemakeLogic = {}

-- Match clock. Open only while under 3:00 from startedAt.
RemakeLogic.CloseSeconds = 180
-- Open ballot.
RemakeLogic.WindowSeconds = 30
-- After a failed or timed-out vote, that team waits.
RemakeLogic.CooldownSeconds = 60

RemakeLogic.ClosedToast = "Remake closes at 3:00."
RemakeLogic.MissingToast = "Need a teammate who never connected."
RemakeLogic.DownToast = "You're down."
RemakeLogic.BotToast = "Bots don't vote."
RemakeLogic.OpenToast = "Vote already open."
RemakeLogic.SurrenderOpenToast = "Surrender vote is open."
RemakeLogic.BlocksFoldToast = "Remake vote is open."
RemakeLogic.VotedToast = "You already voted."
RemakeLogic.NoVoteToast = "No remake vote."
RemakeLogic.QuietToast = "No fight to remake."

export type Seat = {
	userId: number,
	team: string,
	isBot: boolean,
	alive: boolean,
	connected: boolean,
}

export type Ballot = {
	team: string,
	yesUserIds: { number },
	noUserIds: { number },
	endsAt: number?,
}

export type Tally = {
	yes: number,
	no: number,
	living: number,
	needed: number,
	outcome: "open" | "pass" | "fail",
}

export type StartQuery = {
	phase: string,
	elapsed: number,
	isBot: boolean,
	alive: boolean,
	connected: boolean,
	voteOpen: boolean,
	surrenderOpen: boolean,
	practice: boolean,
	allyMissing: boolean,
	cooldownUntil: number?,
	now: number,
}

export type VoteQuery = {
	isBot: boolean,
	alive: boolean,
	connected: boolean,
	voteOpen: boolean,
	already: boolean,
}

function RemakeLogic.open(elapsed: number): boolean
	return elapsed < RemakeLogic.CloseSeconds
end

function RemakeLogic.elapsed(now: number, startedAt: number?): number
	if typeof(startedAt) ~= "number" then
		return 0
	end
	return math.max(0, now - startedAt)
end

function RemakeLogic.seat(userId: number, team: string, isBot: boolean, respawnAt: number?, connected: boolean?): Seat
	return {
		userId = userId,
		team = team,
		isBot = isBot == true,
		alive = respawnAt == nil,
		connected = connected ~= false,
	}
end

-- A human roster slot on this side that never connected, or already left.
-- MatchService sets connected true again on PlayerAdded and on character
-- restore, so a rejoin clears this. A seat that stays false is still missing.
function RemakeLogic.allyMissing(seats: { Seat }, team: string): boolean
	for _, seat in seats do
		if seat.team == team and not seat.isBot and not seat.connected then
			return true
		end
	end
	return false
end

function RemakeLogic.needed(livingCount: number): number
	if livingCount <= 0 then
		return 0
	end
	-- Same living-human majority as surrender. One human passes alone.
	return math.floor(livingCount / 2) + 1
end

function RemakeLogic.living(seats: { Seat }, team: string): { number }
	local ids: { number } = {}
	for _, seat in seats do
		if seat.team == team and not seat.isBot and seat.alive and seat.connected then
			table.insert(ids, seat.userId)
		end
	end
	return ids
end

local function listed(ids: { number }, userId: number): boolean
	for _, id in ids do
		if id == userId then
			return true
		end
	end
	return false
end

function RemakeLogic.voted(ballot: Ballot, userId: number): boolean
	return listed(ballot.yesUserIds, userId) or listed(ballot.noUserIds, userId)
end

function RemakeLogic.mySide(ballot: Ballot, userId: number): string?
	if listed(ballot.yesUserIds, userId) then
		return "yes"
	end
	if listed(ballot.noUserIds, userId) then
		return "no"
	end
	return nil
end

function RemakeLogic.ballotForTeam(ballots: { Ballot }?, team: string): Ballot?
	if not ballots then
		return nil
	end
	for _, ballot in ballots do
		if ballot.team == team then
			return ballot
		end
	end
	return nil
end

function RemakeLogic.tally(seats: { Seat }, ballot: Ballot): Tally
	local ids = RemakeLogic.living(seats, ballot.team)
	local yes, no = 0, 0
	for _, id in ids do
		if listed(ballot.yesUserIds, id) then
			yes += 1
		elseif listed(ballot.noUserIds, id) then
			no += 1
		end
	end
	local living = #ids
	local need = RemakeLogic.needed(living)
	local outcome: "open" | "pass" | "fail" = "open"
	if living <= 0 or (yes + no >= living and yes < need) then
		outcome = "fail"
	elseif yes >= need then
		outcome = "pass"
	end
	return {
		yes = yes,
		no = no,
		living = living,
		needed = need,
		outcome = outcome,
	}
end

-- The window ended. A passing tally still passes. Anything else fails.
function RemakeLogic.timeoutOutcome(result: Tally): "pass" | "fail"
	if result.outcome == "pass" then
		return "pass"
	end
	return "fail"
end

function RemakeLogic.cooldownToast(left: number): string
	local secs = math.max(1, math.ceil(left - 1e-6))
	return `Remake cooling down — {secs}s.`
end

function RemakeLogic.failedNotice(): string
	return `Remake vote failed. {RemakeLogic.CooldownSeconds}s cooldown.`
end

function RemakeLogic.openedNotice(name: string): string
	if name == "" then
		return "Remake vote is open. Yes or No."
	end
	return `{name} called a remake. Yes or No.`
end

function RemakeLogic.countLine(yes: number, no: number, needed: number): string
	return `Yes {yes} · No {no} · need {needed}`
end

-- Surrender cannot start while this team's remake ballot is open.
function RemakeLogic.blocksFold(remakeOpen: boolean): string?
	if remakeOpen then
		return RemakeLogic.BlocksFoldToast
	end
	return nil
end

function RemakeLogic.startRefusal(query: StartQuery): string?
	if query.isBot then
		return RemakeLogic.BotToast
	end
	if query.phase ~= "InProgress" then
		return RemakeLogic.QuietToast
	end
	if not query.connected or not query.alive then
		return RemakeLogic.DownToast
	end
	if not RemakeLogic.open(query.elapsed) then
		return RemakeLogic.ClosedToast
	end
	-- Practice always may start inside the window. A real fight needs a
	-- human ally who never connected or already left.
	if not query.practice and not query.allyMissing then
		return RemakeLogic.MissingToast
	end
	if query.cooldownUntil ~= nil and query.now < query.cooldownUntil then
		return RemakeLogic.cooldownToast(query.cooldownUntil - query.now)
	end
	if query.voteOpen then
		return RemakeLogic.OpenToast
	end
	if query.surrenderOpen then
		return RemakeLogic.SurrenderOpenToast
	end
	return nil
end

function RemakeLogic.voteRefusal(query: VoteQuery): string?
	if query.isBot then
		return RemakeLogic.BotToast
	end
	if not query.voteOpen then
		return RemakeLogic.NoVoteToast
	end
	if not query.connected or not query.alive then
		return RemakeLogic.DownToast
	end
	if query.already then
		return RemakeLogic.VotedToast
	end
	return nil
end

return RemakeLogic
