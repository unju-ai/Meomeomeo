--!strict

-- Cat Rift surrender vote. Pure rules — MatchService owns the clock and the
-- match-end call. Bots are never an electorate and never start a vote.
-- Practice uses the same rules. Hub modes do not call this.

local SurrenderLogic = {}

-- Match clock. 8:00 from startedAt.
SurrenderLogic.UnlockSeconds = 480
-- Open ballot.
SurrenderLogic.WindowSeconds = 30
-- After a failed or timed-out vote, that team waits.
SurrenderLogic.CooldownSeconds = 90

SurrenderLogic.UnlockToast = "Surrender opens at 8:00."
SurrenderLogic.DownToast = "You're down."
SurrenderLogic.BotToast = "Bots don't vote."
SurrenderLogic.OpenToast = "Vote already open."
SurrenderLogic.VotedToast = "You already voted."
SurrenderLogic.NoVoteToast = "No surrender vote."
SurrenderLogic.QuietToast = "No fight to fold."

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

function SurrenderLogic.unlocked(elapsed: number): boolean
	return elapsed >= SurrenderLogic.UnlockSeconds
end

function SurrenderLogic.elapsed(now: number, startedAt: number?): number
	if typeof(startedAt) ~= "number" then
		return 0
	end
	return math.max(0, now - startedAt)
end

function SurrenderLogic.seat(userId: number, team: string, isBot: boolean, respawnAt: number?, connected: boolean?): Seat
	return {
		userId = userId,
		team = team,
		isBot = isBot == true,
		alive = respawnAt == nil,
		connected = connected ~= false,
	}
end

function SurrenderLogic.needed(livingCount: number): number
	if livingCount <= 0 then
		return 0
	end
	-- Majority of the living humans. One human passes alone. Two need both.
	return math.floor(livingCount / 2) + 1
end

function SurrenderLogic.living(seats: { Seat }, team: string): { number }
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

function SurrenderLogic.voted(ballot: Ballot, userId: number): boolean
	return listed(ballot.yesUserIds, userId) or listed(ballot.noUserIds, userId)
end

function SurrenderLogic.mySide(ballot: Ballot, userId: number): string?
	if listed(ballot.yesUserIds, userId) then
		return "yes"
	end
	if listed(ballot.noUserIds, userId) then
		return "no"
	end
	return nil
end

function SurrenderLogic.ballotForTeam(ballots: { Ballot }?, team: string): Ballot?
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

function SurrenderLogic.tally(seats: { Seat }, ballot: Ballot): Tally
	local ids = SurrenderLogic.living(seats, ballot.team)
	local yes, no = 0, 0
	for _, id in ids do
		if listed(ballot.yesUserIds, id) then
			yes += 1
		elseif listed(ballot.noUserIds, id) then
			no += 1
		end
	end
	local living = #ids
	local need = SurrenderLogic.needed(living)
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
function SurrenderLogic.timeoutOutcome(result: Tally): "pass" | "fail"
	if result.outcome == "pass" then
		return "pass"
	end
	return "fail"
end

function SurrenderLogic.cooldownToast(left: number): string
	local secs = math.max(1, math.ceil(left - 1e-6))
	return `Surrender cooling down — {secs}s.`
end

function SurrenderLogic.failedNotice(): string
	return `Surrender vote failed. {SurrenderLogic.CooldownSeconds}s cooldown.`
end

function SurrenderLogic.openedNotice(name: string): string
	if name == "" then
		return "Surrender vote is open. Yes or No."
	end
	return `{name} called a surrender. Yes or No.`
end

function SurrenderLogic.countLine(yes: number, no: number, needed: number): string
	return `Yes {yes} · No {no} · need {needed}`
end

function SurrenderLogic.opponent(team: string): string
	if team == "Blue" then
		return "Red"
	end
	return "Blue"
end

function SurrenderLogic.startRefusal(query: StartQuery): string?
	if query.isBot then
		return SurrenderLogic.BotToast
	end
	if query.phase ~= "InProgress" then
		return SurrenderLogic.QuietToast
	end
	if not query.connected or not query.alive then
		return SurrenderLogic.DownToast
	end
	if not SurrenderLogic.unlocked(query.elapsed) then
		return SurrenderLogic.UnlockToast
	end
	if query.cooldownUntil ~= nil and query.now < query.cooldownUntil then
		return SurrenderLogic.cooldownToast(query.cooldownUntil - query.now)
	end
	if query.voteOpen then
		return SurrenderLogic.OpenToast
	end
	return nil
end

function SurrenderLogic.voteRefusal(query: VoteQuery): string?
	if query.isBot then
		return SurrenderLogic.BotToast
	end
	if not query.voteOpen then
		return SurrenderLogic.NoVoteToast
	end
	if not query.connected or not query.alive then
		return SurrenderLogic.DownToast
	end
	if query.already then
		return SurrenderLogic.VotedToast
	end
	return nil
end

return SurrenderLogic
