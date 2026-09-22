-- Cat Rift early remake vote rules. Run through tools/test-remake.py.

assert(RemakeLogic.CloseSeconds == 180)
assert(RemakeLogic.WindowSeconds == 30)
assert(RemakeLogic.CooldownSeconds == 60)
assert(RemakeLogic.open(0) == true)
assert(RemakeLogic.open(179) == true)
assert(RemakeLogic.open(179.9) == true)
assert(RemakeLogic.open(180) == false)
assert(RemakeLogic.open(181) == false)
assert(RemakeLogic.elapsed(1000, nil) == 0)
assert(RemakeLogic.elapsed(1000, 820) == 180)

-- Same living-human majority as surrender.
assert(RemakeLogic.needed(0) == 0)
assert(RemakeLogic.needed(1) == 1)
assert(RemakeLogic.needed(2) == 2)
assert(RemakeLogic.needed(3) == 2)
assert(RemakeLogic.needed(4) == 3)
assert(string.find(RemakeLogic.failedNotice(), "60", 1, true) ~= nil)
assert(RemakeLogic.cooldownToast(60) == "Remake cooling down — 60s.")
assert(RemakeLogic.openedNotice("Whiskers") == "Whiskers called a remake. Yes or No.")
assert(RemakeLogic.blocksFold(false) == nil)
assert(RemakeLogic.blocksFold(true) == RemakeLogic.BlocksFoldToast)

local function human(id: number, team: string, alive: boolean?, connected: boolean?): RemakeLogic.Seat
	return RemakeLogic.seat(id, team, false, if alive == false then 1 else nil, connected)
end

local function bot(id: number, team: string): RemakeLogic.Seat
	return RemakeLogic.seat(id, team, true, nil, true)
end

local function ballot(team: string, yes: { number }, no: { number }): RemakeLogic.Ballot
	return { team = team, yesUserIds = yes, noUserIds = no, endsAt = 30 }
end

local function ready(): RemakeLogic.StartQuery
	return {
		phase = "InProgress",
		elapsed = 20,
		isBot = false,
		alive = true,
		connected = true,
		voteOpen = false,
		surrenderOpen = false,
		practice = true,
		allyMissing = false,
		cooldownUntil = nil,
		now = 1000,
	}
end

assert(RemakeLogic.startRefusal(ready()) == nil)

local closed = ready()
closed.elapsed = 180
assert(RemakeLogic.startRefusal(closed) == RemakeLogic.ClosedToast)
closed.elapsed = 240
assert(RemakeLogic.startRefusal(closed) == RemakeLogic.ClosedToast)

local earlyEdge = ready()
earlyEdge.elapsed = 179
assert(RemakeLogic.startRefusal(earlyEdge) == nil)

-- Practice may start with every human connected. A real fight may not.
local realFull = ready()
realFull.practice = false
realFull.allyMissing = false
assert(RemakeLogic.startRefusal(realFull) == RemakeLogic.MissingToast)
local realMissing = ready()
realMissing.practice = false
realMissing.allyMissing = true
assert(RemakeLogic.startRefusal(realMissing) == nil)
assert(RemakeLogic.allyMissing({ human(1, "Blue", true, true), human(2, "Blue", true, false) }, "Blue") == true)
assert(RemakeLogic.allyMissing({ human(1, "Blue", true, true), bot(-3, "Blue") }, "Blue") == false)
assert(RemakeLogic.allyMissing({ human(1, "Blue", true, true), human(9, "Red", true, false) }, "Blue") == false)
-- A dead teammate who is still connected is not "missing".
assert(RemakeLogic.allyMissing({ human(1, "Blue"), human(2, "Blue", false, true) }, "Blue") == false)

local lobby = ready()
lobby.phase = "Lobby"
assert(RemakeLogic.startRefusal(lobby) == RemakeLogic.QuietToast)

local downStart = ready()
downStart.alive = false
assert(RemakeLogic.startRefusal(downStart) == RemakeLogic.DownToast)

local open = ready()
open.voteOpen = true
assert(RemakeLogic.startRefusal(open) == RemakeLogic.OpenToast)

local folding = ready()
folding.surrenderOpen = true
assert(RemakeLogic.startRefusal(folding) == RemakeLogic.SurrenderOpenToast)

local cooling = ready()
cooling.cooldownUntil = 1060
cooling.now = 1000
assert(RemakeLogic.startRefusal(cooling) == "Remake cooling down — 60s.")
local almost = ready()
almost.cooldownUntil = 1000.4
almost.now = 1000
assert(RemakeLogic.startRefusal(almost) ~= nil)
local cooled = ready()
cooled.cooldownUntil = 1000
cooled.now = 1000
assert(RemakeLogic.startRefusal(cooled) == nil)

-- Closed window wins over the missing-teammate toast.
local lateMissing = ready()
lateMissing.practice = false
lateMissing.allyMissing = false
lateMissing.elapsed = 180
assert(RemakeLogic.startRefusal(lateMissing) == RemakeLogic.ClosedToast)

local botStart = ready()
botStart.isBot = true
assert(RemakeLogic.startRefusal(botStart) == RemakeLogic.BotToast)
local botLobby = ready()
botLobby.isBot = true
botLobby.phase = "Lobby"
assert(RemakeLogic.startRefusal(botLobby) == RemakeLogic.BotToast)
assert(RemakeLogic.voteRefusal({
	isBot = true,
	alive = true,
	connected = true,
	voteOpen = true,
	already = false,
}) == RemakeLogic.BotToast)

local solo = { human(1, "Blue"), bot(-4, "Blue"), human(8, "Red") }
local soloBallot = ballot("Blue", { 1 }, {})
local soloTally = RemakeLogic.tally(solo, soloBallot)
assert(soloTally.outcome == "pass")
assert(soloTally.living == 1)
assert(soloTally.needed == 1)
assert(soloTally.yes == 1)
assert(RemakeLogic.countLine(soloTally.yes, soloTally.no, soloTally.needed) == "Yes 1 · No 0 · need 1")
assert(RemakeLogic.timeoutOutcome(soloTally) == "pass")

local botOnly = RemakeLogic.tally(solo, ballot("Blue", { -4 }, {}))
assert(botOnly.yes == 0)
assert(botOnly.outcome == "open")

local pair = { human(1, "Blue"), human(2, "Blue"), human(9, "Red") }
local oneYes = RemakeLogic.tally(pair, ballot("Blue", { 1 }, {}))
assert(oneYes.outcome == "open")
assert(oneYes.needed == 2)
assert(RemakeLogic.timeoutOutcome(oneYes) == "fail")
local split = RemakeLogic.tally(pair, ballot("Blue", { 1 }, { 2 }))
assert(split.outcome == "fail")
assert(RemakeLogic.timeoutOutcome(split) == "fail")
local both = RemakeLogic.tally(pair, ballot("Blue", { 1, 2 }, {}))
assert(both.outcome == "pass")
assert(RemakeLogic.timeoutOutcome(both) == "pass")

local trio = { human(1, "Red"), human(2, "Red"), human(3, "Red"), bot(-5, "Red") }
local twoOfThree = RemakeLogic.tally(trio, ballot("Red", { 1, 2, -5 }, {}))
assert(twoOfThree.outcome == "pass")
assert(twoOfThree.needed == 2)
assert(twoOfThree.yes == 2)
local oneOfThree = RemakeLogic.tally(trio, ballot("Red", { 1 }, { 2 }))
assert(oneOfThree.outcome == "open")
local nos = RemakeLogic.tally(trio, ballot("Red", { 1 }, { 2, 3 }))
assert(nos.outcome == "fail")

-- A down human is out of the count, so the living Yes can pass.
local down = { human(1, "Blue"), human(2, "Blue"), human(3, "Blue", false) }
local alivePasses = RemakeLogic.tally(down, ballot("Blue", { 1 }, { 2 }))
assert(alivePasses.living == 2)
assert(alivePasses.outcome == "fail")
local aliveYes = RemakeLogic.tally(down, ballot("Blue", { 1, 2 }, {}))
assert(aliveYes.outcome == "pass")

-- A disconnected human is out of the living count (and is the missing ally).
local gone = { human(1, "Blue", true, false), human(2, "Blue", true, true) }
local onlyConnected = RemakeLogic.tally(gone, ballot("Blue", { 2 }, { 1 }))
assert(onlyConnected.living == 1)
assert(onlyConnected.yes == 1)
assert(onlyConnected.outcome == "pass")

local empty = RemakeLogic.tally({ human(1, "Blue", false), bot(-7, "Blue") }, ballot("Blue", { 1 }, {}))
assert(empty.living == 0)
assert(empty.outcome == "fail")

local cross = RemakeLogic.tally({ human(1, "Blue"), human(9, "Red") }, ballot("Blue", { 9 }, {}))
assert(cross.yes == 0)
assert(cross.outcome == "open")

assert(RemakeLogic.mySide(ballot("Blue", { 1 }, { 2 }), 1) == "yes")
assert(RemakeLogic.mySide(ballot("Blue", { 1 }, { 2 }), 2) == "no")
assert(RemakeLogic.mySide(ballot("Blue", { 1 }, { 2 }), 3) == nil)
assert(RemakeLogic.voted(ballot("Blue", { 1 }, {}), 1) == true)
assert(RemakeLogic.voteRefusal({
	isBot = false,
	alive = true,
	connected = true,
	voteOpen = false,
	already = false,
}) == RemakeLogic.NoVoteToast)
assert(RemakeLogic.voteRefusal({
	isBot = false,
	alive = false,
	connected = true,
	voteOpen = true,
	already = false,
}) == RemakeLogic.DownToast)
assert(RemakeLogic.voteRefusal({
	isBot = false,
	alive = true,
	connected = true,
	voteOpen = true,
	already = true,
}) == RemakeLogic.VotedToast)

print("remake vote ok")
