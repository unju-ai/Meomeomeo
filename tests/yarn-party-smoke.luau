-- Run through tools/test-party.py against src/shared/YarnPartyCatalog.luau.

assert(YarnPartyCatalog.SeatCount == 4)
assert(YarnPartyCatalog.RoundCount == 3)
assert(#YarnPartyCatalog.Plan == 3)
assert(YarnPartyCatalog.roundAt(1) == "Dodge")
assert(YarnPartyCatalog.roundAt(2) == "Pillows")
assert(YarnPartyCatalog.roundAt(3) == "Dodge")
assert(YarnPartyCatalog.roundAt(99) == "Dodge")
local kinds = YarnPartyCatalog.kinds()
assert(#kinds == 2, "Need two distinct mini-round types")
assert(YarnPartyCatalog.titleOf("Dodge") == "YARN DODGE")
assert(YarnPartyCatalog.titleOf("Pillows") == "STALL FREEZE")
assert(YarnPartyCatalog.ruleBanner("Dodge") == "Space hop · last loaf standing")
assert(YarnPartyCatalog.ruleBanner("Pillows") == "Lit pillow = safe · lanterns blink")
assert(YarnPartyCatalog.lobbyTitle(3.2) == "STARTS IN 4")
assert(YarnPartyCatalog.lobbyTitle(2.1) == "STARTS IN 3")
assert(YarnPartyCatalog.lobbyTitle(0.4) == "STARTS IN 1")
assert(YarnPartyCatalog.lobbyTitle(0) == "STARTS IN 0")
assert(YarnPartyCatalog.seatRole(true, false, false) == "YOU")
assert(YarnPartyCatalog.seatRole(false, true, false) == "BOT")
assert(YarnPartyCatalog.seatRole(false, false, true) == "OPEN")
assert(YarnPartyCatalog.seatRole(false, false, false) == "CAT")
assert(YarnPartyCatalog.seatLine(2, "BOT", "LoafBot") == "2  [BOT]  LoafBot")
assert(YarnPartyCatalog.isElimPop("Alex  ·  YARN BONK") == true)
assert(YarnPartyCatalog.isElimPop("Mo  ·  WRONG PILLOW") == true)
assert(YarnPartyCatalog.isElimPop("YARN DODGE") == false)
assert(YarnPartyCatalog.isElimPop(nil) == false)
assert(YarnPartyCatalog.isRoundTitle("YARN DODGE") == true)
assert(YarnPartyCatalog.isRoundTitle("STALL FREEZE") == true)
assert(YarnPartyCatalog.isRoundTitle("GO") == false)
assert(YarnPartyCatalog.podiumWinnerLine("Alex") == "Alex  ·  WINNER")
assert(YarnPartyCatalog.podiumRecapLine(1, "Alex", 6, false) == "#1  6  Alex  CAT")
assert(YarnPartyCatalog.podiumRecapLine(2, "LoafBot", 3, true) == "#2  3  LoafBot  BOT")
assert(YarnPartyCatalog.pointsForPlace(1) == 3)
assert(YarnPartyCatalog.pointsForPlace(2) == 2)
assert(YarnPartyCatalog.pointsForPlace(3) == 1)
assert(YarnPartyCatalog.pointsForPlace(4) == 0)
assert(YarnPartyCatalog.botName(1) == "LoafBot")
assert(YarnPartyCatalog.botChampion(2) == "Bytekit")
local ranked = YarnPartyCatalog.rankByScore({
	{ id = 2, score = 4, alive = false },
	{ id = 1, score = 6, alive = true },
	{ id = 3, score = 6, alive = false },
})
assert(ranked[1] == 1, "Higher score + alive wins ties")
assert(ranked[2] == 3)

local function botNames(seats)
	local names = {}
	for _, seat in seats do
		if seat.kind == "bot" then
			assert(not names[seat.name], "duplicate bot " .. seat.name)
			names[seat.name] = true
		end
	end
	return names
end

local function blankSeat(seat, index)
	seat.index = index
	seat.kind = "empty"
	seat.userId = nil
	seat.name = ""
	seat.botSlot = nil
	seat.championId = ""
	seat.alive = false
	seat.score = 0
end

local lobby = YarnPartyLobby.open(101, "Alex")
assert(#lobby == YarnPartyCatalog.SeatCount)
assert(lobby[1].kind == "human" and lobby[1].userId == 101 and lobby[1].name == "Alex")
assert(lobby[2].name == "LoafBot" and lobby[2].kind == "bot")
assert(lobby[3].name == "NibBot")
assert(lobby[4].name == "PurrBot")
assert(YarnPartyLobby.humanCount(lobby) == 1)
assert(YarnPartyLobby.botCount(lobby) == 3)
botNames(lobby)

local withSam, joined = YarnPartyLobby.claim(lobby, "Lobby", 202, "Sam", 3)
assert(joined.action == "seated" and joined.seat == 2 and joined.replacedBot == true)
assert(joined.countdown == 3, "joining must not restart a healthy countdown")
assert(withSam[1].userId == 101 and withSam[1].kind == "human")
assert(withSam[2].kind == "human" and withSam[2].userId == 202 and withSam[2].name == "Sam")
assert(withSam[2].championId == YarnPartyLobby.HumanChampion)
assert(withSam[3].name == "NibBot" and withSam[4].name == "PurrBot")
assert(lobby[2].kind == "bot" and lobby[2].name == "LoafBot", "claim must not mutate the live table")
botNames(withSam)

local withMo, third = YarnPartyLobby.claim(withSam, "Lobby", 303, "Mo", 2.2)
assert(third.seat == 3 and third.replacedBot == true)
assert(withMo[3].userId == 303 and withMo[2].userId == 202)

local sameSam, dup = YarnPartyLobby.claim(withMo, "Lobby", 202, "Sam", 2)
assert(dup.action == "already" and dup.seat == 2)
assert(sameSam == withMo)

local withPat, fourth = YarnPartyLobby.claim(withMo, "Lobby", 404, "Pat", 2)
assert(fourth.action == "seated" and fourth.seat == 4 and fourth.replacedBot == true)
assert(YarnPartyLobby.humanCount(withPat) == 4)
assert(YarnPartyLobby.botCount(withPat) == 0)
local sameFull, full = YarnPartyLobby.claim(withPat, "Lobby", 505, "Kit", 2)
assert(full.action == "full")
assert(sameFull == withPat)
assert(withPat[1].userId == 101 and withPat[4].userId == 404)

local lateSeats, late = YarnPartyLobby.claim(lobby, "Lobby", 808, "Late", 0.05)
assert(late.action == "seated" and late.seat == 2)
assert(late.countdown == YarnPartyLobby.JoinGraceSeconds)
assert(YarnPartyLobby.countdownAfterJoin(YarnPartyCatalog.CountdownSeconds) == YarnPartyCatalog.CountdownSeconds)
assert(YarnPartyLobby.countdownAfterJoin(0) == YarnPartyLobby.JoinGraceSeconds)

local stillBots, waiting = YarnPartyLobby.claim(lobby, "Playing", 909, "Nope", 6)
assert(waiting.action == "wait")
assert(stillBots == lobby)
assert(string.find(waiting.error, "next party", 1, true))
assert(lobby[2].kind == "bot")
local stillCrown, crowned = YarnPartyLobby.claim(lobby, "Podium", 909, "Nope", 2)
assert(stillCrown == lobby and crowned.action == "wait")
assert(string.find(crowned.error, "crown", 1, true))
local stillIntro, introWait = YarnPartyLobby.claim(lobby, "Intro", 909, "Nope", 1)
assert(stillIntro == lobby and introWait.action == "wait")
local _, recapWait = YarnPartyLobby.claim(lobby, "Recap", 909, "Nope", 1)
assert(recapWait.action == "wait")

local holes = YarnPartyLobby.open(1, "A")
blankSeat(holes[2], 2)
blankSeat(holes[3], 3)
blankSeat(holes[4], 4)
local tookEmpty, emptyJoin = YarnPartyLobby.claim(holes, "Lobby", 2, "B", 2)
assert(emptyJoin.action == "seated" and emptyJoin.seat == 2 and emptyJoin.replacedBot == false)
assert(tookEmpty[2].kind == "human" and tookEmpty[2].userId == 2)
assert(holes[2].kind == "empty")

local refilled, left = YarnPartyLobby.release(withMo, "Lobby", 202)
assert(left.found and left.seat == 2 and left.refilledBot and left.partyEmpty == false)
assert(refilled[2].kind == "bot" and refilled[2].name == "LoafBot")
assert(refilled[3].userId == 303 and refilled[1].userId == 101)
assert(withMo[2].kind == "human", "release must not mutate the live table")
botNames(refilled)

local mid, midLeft = YarnPartyLobby.release(withMo, "Playing", 303)
assert(midLeft.found and midLeft.refilledBot == false and midLeft.partyEmpty == false)
assert(mid[3].kind == "empty")
assert(mid[2].kind == "human" and mid[1].kind == "human")
assert(YarnPartyLobby.botCount(mid) == 1)

local closed, hostLeft = YarnPartyLobby.release(lobby, "Lobby", 101)
assert(hostLeft.partyEmpty and hostLeft.refilledBot == false)
assert(closed[1].kind == "empty")
botNames(closed)

local gap = YarnPartyLobby.open(7, "Host")
blankSeat(gap[2], 2)
local patched = YarnPartyLobby.ensureBots(gap)
assert(patched[2].kind == "bot" and patched[2].name == "LoafBot")
assert(patched[1].userId == 7 and patched[3].name == "NibBot" and patched[4].name == "PurrBot")
assert(gap[2].kind == "empty")
botNames(patched)
assert(lateSeats[2].userId == 808)

print("PASS: yarn party rounds, scoring, bot fill names, lobby seat takeover, juice helpers")
