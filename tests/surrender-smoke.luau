-- Cat Rift surrender vote rules. Run through tools/test-surrender.py.

assert(SurrenderLogic.UnlockSeconds == 480)
assert(SurrenderLogic.WindowSeconds == 30)
assert(SurrenderLogic.CooldownSeconds == 90)
assert(SurrenderLogic.unlocked(0) == false)
assert(SurrenderLogic.unlocked(479) == false)
assert(SurrenderLogic.unlocked(480) == true)
assert(SurrenderLogic.unlocked(481) == true)
assert(SurrenderLogic.elapsed(1000, nil) == 0)
assert(SurrenderLogic.elapsed(1000, 520) == 480)

assert(SurrenderLogic.needed(0) == 0)
assert(SurrenderLogic.needed(1) == 1)
assert(SurrenderLogic.needed(2) == 2)
assert(SurrenderLogic.needed(3) == 2)
assert(SurrenderLogic.needed(4) == 3)
assert(SurrenderLogic.opponent("Blue") == "Red")
assert(SurrenderLogic.opponent("Red") == "Blue")
assert(string.find(SurrenderLogic.failedNotice(), "90", 1, true) ~= nil)
assert(SurrenderLogic.cooldownToast(90) == "Surrender cooling down — 90s.")
assert(SurrenderLogic.openedNotice("Whiskers") == "Whiskers called a surrender. Yes or No.")

local function human(id: number, team: string, alive: boolean?, connected: boolean?): SurrenderLogic.Seat
	return {
		userId = id,
		team = team,
		isBot = false,
		alive = if alive == nil then true else alive,
		connected = if connected == nil then true else connected,
	}
end

local function bot(id: number, team: string): SurrenderLogic.Seat
	return {
		userId = id,
		team = team,
		isBot = true,
		alive = true,
		connected = true,
	}
end

local function ballot(team: string, yes: { number }, no: { number }): SurrenderLogic.Ballot
	return { team = team, yesUserIds = yes, noUserIds = no }
end

local function ready(): SurrenderLogic.StartQuery
	return {
		phase = "InProgress",
		elapsed = 480,
		isBot = false,
		alive = true,
		connected = true,
		voteOpen = false,
		cooldownUntil = nil,
		now = 1000,
	}
end

-- Unlock toast before 8:00. Practice is the same query — there is no practice gate.
local early = ready()
early.elapsed = 479
assert(SurrenderLogic.startRefusal(early) == SurrenderLogic.UnlockToast)
assert(SurrenderLogic.startRefusal(ready()) == nil)
local lobby = ready()
lobby.phase = "Lobby"
assert(SurrenderLogic.startRefusal(lobby) == SurrenderLogic.QuietToast)
local downStart = ready()
downStart.alive = false
assert(SurrenderLogic.startRefusal(downStart) == SurrenderLogic.DownToast)
local open = ready()
open.voteOpen = true
assert(SurrenderLogic.startRefusal(open) == SurrenderLogic.OpenToast)

-- Cooldown blocks until the stamp, then the team may start again.
local cooling = ready()
cooling.cooldownUntil = 1090
cooling.now = 1000
assert(SurrenderLogic.startRefusal(cooling) == "Surrender cooling down — 90s.")
local almost = ready()
almost.cooldownUntil = 1000
almost.now = 999
assert(SurrenderLogic.startRefusal(almost) ~= nil)
local cooled = ready()
cooled.cooldownUntil = 1000
cooled.now = 1000
assert(SurrenderLogic.startRefusal(cooled) == nil)

-- Bots never start, even after unlock, and they are not the refusal for a quiet phase first.
local botStart = ready()
botStart.isBot = true
botStart.elapsed = 900
assert(SurrenderLogic.startRefusal(botStart) == SurrenderLogic.BotToast)
local botLobby = ready()
botLobby.isBot = true
botLobby.phase = "Lobby"
assert(SurrenderLogic.startRefusal(botLobby) == SurrenderLogic.BotToast)
assert(SurrenderLogic.voteRefusal({
	isBot = true,
	alive = true,
	connected = true,
	voteOpen = true,
	already = false,
}) == SurrenderLogic.BotToast)

-- 1 living human passes alone. Bots on the team do not count and do not vote.
local solo = { human(1, "Blue"), bot(-1, "Blue"), bot(-2, "Blue"), bot(-3, "Red") }
local soloBallot = ballot("Blue", { 1, -1 }, {})
local soloTally = SurrenderLogic.tally(solo, soloBallot)
assert(soloTally.living == 1)
assert(soloTally.needed == 1)
assert(soloTally.yes == 1)
assert(soloTally.no == 0)
assert(soloTally.outcome == "pass")
assert(SurrenderLogic.countLine(soloTally.yes, soloTally.no, soloTally.needed) == "Yes 1 · No 0 · need 1")

-- A bot id in the yes list still does not count when no human has voted.
local botOnly = SurrenderLogic.tally(solo, ballot("Blue", { -1 }, {}))
assert(botOnly.yes == 0)
assert(botOnly.outcome == "open")

-- 2 living humans need both. One yes stays open. Yes+No fails. Two yes passes.
local pair = { human(1, "Blue"), human(2, "Blue"), bot(-4, "Blue") }
local oneYes = SurrenderLogic.tally(pair, ballot("Blue", { 1 }, {}))
assert(oneYes.living == 2)
assert(oneYes.needed == 2)
assert(oneYes.yes == 1)
assert(oneYes.outcome == "open")
assert(SurrenderLogic.timeoutOutcome(oneYes) == "fail")
local split = SurrenderLogic.tally(pair, ballot("Blue", { 1 }, { 2 }))
assert(split.outcome == "fail")
assert(SurrenderLogic.timeoutOutcome(split) == "fail")
local both = SurrenderLogic.tally(pair, ballot("Blue", { 1, 2 }, {}))
assert(both.yes == 2)
assert(both.outcome == "pass")
assert(SurrenderLogic.timeoutOutcome(both) == "pass")

-- 3 living humans need 2. Two yes passes before the third votes.
local trio = { human(1, "Red"), human(2, "Red"), human(3, "Red"), bot(-5, "Red") }
local twoOfThree = SurrenderLogic.tally(trio, ballot("Red", { 1, 2, -5 }, {}))
assert(twoOfThree.living == 3)
assert(twoOfThree.needed == 2)
assert(twoOfThree.yes == 2)
assert(twoOfThree.outcome == "pass")
local oneOfThree = SurrenderLogic.tally(trio, ballot("Red", { 1 }, { 2 }))
assert(oneOfThree.outcome == "open")
assert(oneOfThree.no == 1)
local nos = SurrenderLogic.tally(trio, ballot("Red", { 1 }, { 2, 3 }))
assert(nos.outcome == "fail")

-- Dead and disconnected humans leave the electorate. A dead yes does not count.
local down = { human(1, "Blue", true), human(2, "Blue", false), bot(-6, "Blue") }
local alivePasses = SurrenderLogic.tally(down, ballot("Blue", { 1 }, { 2 }))
assert(alivePasses.living == 1)
assert(alivePasses.needed == 1)
assert(alivePasses.yes == 1)
assert(alivePasses.no == 0)
assert(alivePasses.outcome == "pass")

local gone = { human(1, "Blue", true, false), human(2, "Blue") }
local onlyConnected = SurrenderLogic.tally(gone, ballot("Blue", { 2 }, { 1 }))
assert(onlyConnected.living == 1)
assert(onlyConnected.yes == 1)
assert(onlyConnected.outcome == "pass")

-- Nobody living can pass.
local empty = SurrenderLogic.tally({ human(1, "Blue", false), bot(-7, "Blue") }, ballot("Blue", { 1 }, {}))
assert(empty.living == 0)
assert(empty.outcome == "fail")

-- The other team is a different ballot.
local cross = SurrenderLogic.tally({ human(1, "Blue"), human(9, "Red") }, ballot("Blue", { 9 }, {}))
assert(cross.yes == 0)
assert(cross.living == 1)
assert(cross.outcome == "open")

assert(SurrenderLogic.mySide(ballot("Blue", { 1 }, { 2 }), 1) == "yes")
assert(SurrenderLogic.mySide(ballot("Blue", { 1 }, { 2 }), 2) == "no")
assert(SurrenderLogic.mySide(ballot("Blue", { 1 }, { 2 }), 3) == nil)
assert(SurrenderLogic.voted(ballot("Blue", { 1 }, {}), 1) == true)
assert(SurrenderLogic.voteRefusal({
	isBot = false,
	alive = true,
	connected = true,
	voteOpen = false,
	already = false,
}) == SurrenderLogic.NoVoteToast)
assert(SurrenderLogic.voteRefusal({
	isBot = false,
	alive = false,
	connected = true,
	voteOpen = true,
	already = false,
}) == SurrenderLogic.DownToast)
assert(SurrenderLogic.voteRefusal({
	isBot = false,
	alive = true,
	connected = true,
	voteOpen = true,
	already = true,
}) == SurrenderLogic.VotedToast)

print("surrender vote ok")
