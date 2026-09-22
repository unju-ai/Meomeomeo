-- Run through tools/test-rift-party.py against src/shared/CatRiftParty.luau.

local names = {
	[1] = "Alex",
	[2] = "Sam",
	[3] = "Mo",
	[4] = "Pat",
	[5] = "Nia",
}

local function opts(now: number)
	return {
		ttl = CatRiftParty.InviteSeconds,
		maxSize = 5,
		names = names,
		now = now,
	}
end

local function joined(state, leaderId, memberId)
	return CatRiftParty.role(state, leaderId) == "leader"
		and CatRiftParty.role(state, memberId) == "member"
		and CatRiftParty.sameParty(state, leaderId, memberId)
end

local state = CatRiftParty.empty()
assert(CatRiftParty.role(state, 1) == "solo")
assert(CatRiftParty.pendingCount(state, 0) == 0)

local invited, sent = CatRiftParty.invite(state, 1, 2, opts(100))
assert(sent.ok, sent.error)
assert(CatRiftParty.role(invited, 1) == "solo", "Invite must not join until Accept")
assert(CatRiftParty.role(invited, 2) == "solo")
assert(CatRiftParty.incoming(invited, 2, 100) ~= nil)
assert(CatRiftParty.outgoing(invited, 1, 100) ~= nil)
assert(invited.notices[1].text:find("Invite sent to Sam", 1, true))
assert(invited.notices[2].text:find("Alex invited you", 1, true))

local again, dup = CatRiftParty.invite(invited, 1, 2, opts(105))
assert(dup.ok)
assert(CatRiftParty.pendingCount(again, 105) == 1, "A fresh invite replaces the pending one")
assert(CatRiftParty.incoming(again, 2, 105).expiresAt == 105 + CatRiftParty.InviteSeconds)

local selfInvite, selfErr = CatRiftParty.invite(again, 1, 1, opts(105))
assert(selfErr.ok == false)
assert(CatRiftParty.role(selfInvite, 1) == "solo")

local declined, decline = CatRiftParty.decline(again, 2, opts(106))
assert(decline.ok)
assert(CatRiftParty.role(declined, 1) == "solo")
assert(CatRiftParty.incoming(declined, 2, 106) == nil)
assert(declined.notices[1].text:find("declined", 1, true))
local noCard, missing = CatRiftParty.decline(declined, 2, opts(106))
assert(missing.ok == false)
assert(CatRiftParty.role(noCard, 2) == "solo")

local reinvite, resent = CatRiftParty.invite(declined, 1, 2, opts(110))
assert(resent.ok)
local late, lateErr = CatRiftParty.accept(reinvite, 2, opts(110 + CatRiftParty.InviteSeconds))
assert(lateErr.ok == false and lateErr.error:find("expired", 1, true))
assert(CatRiftParty.role(late, 2) == "solo")
local expiredState, swept = CatRiftParty.sweep(reinvite, opts(110 + CatRiftParty.InviteSeconds))
assert(swept)
assert(CatRiftParty.incoming(expiredState, 2, 130) == nil)
assert(expiredState.notices[1].text:find("expired", 1, true))
assert(expiredState.notices[2].text:find("expired", 1, true))

local pending, _ = CatRiftParty.invite(CatRiftParty.empty(), 1, 2, opts(200))
local party, accepted = CatRiftParty.accept(pending, 2, opts(201))
assert(accepted.ok, accepted.error)
assert(joined(party, 1, 2))
local members = CatRiftParty.membersOf(party, 2)
assert(members[1] == 1 and members[2] == 2, "Leader stays first")
assert(party.notices[1].text:find("Sam joined your party", 1, true))
assert(party.notices[2].text:find("You joined Alex's party", 1, true))
assert(CatRiftParty.incoming(party, 2, 201) == nil)

local roster, queueErr = CatRiftParty.queueRoster(party, 1, names)
assert(queueErr == nil and roster[1] == 1 and roster[2] == 2)
local blocked, blockErr = CatRiftParty.queueRoster(party, 2, names)
assert(blocked == nil and blockErr:find("Alex leads", 1, true))
local leaveAll = CatRiftParty.leaveQueueRoster(party, 1)
assert(#leaveAll == 2, "Leader leave-queue pulls the party")
local leaveOne = CatRiftParty.leaveQueueRoster(party, 2)
assert(#leaveOne == 1 and leaveOne[1] == 2)

local practice, practiceErr = CatRiftParty.practiceRoster(party, 1, names, false)
assert(practiceErr == nil and #practice == 2)
local memberPractice, memberErr = CatRiftParty.practiceRoster(party, 2, names, false)
assert(memberPractice == nil and memberErr:find("Practice", 1, true))
local playAgain, playErr = CatRiftParty.practiceRoster(party, 2, names, true)
assert(playErr == nil and #playAgain == 2, "Practice again can bring the party")

local teams = CatRiftParty.assignTeams(party, { 1, 2 }, 5)
assert(teams[1] == "Blue" and teams[2] == "Blue", "Party humans share a team")
local solos = CatRiftParty.assignTeams(CatRiftParty.empty(), { 20, 10 }, 5)
assert(solos[20] == "Blue" and solos[10] == "Red", "Two solos still split in queue order")

local withMo, moSent = CatRiftParty.invite(party, 2, 3, opts(210))
assert(moSent.ok, "A member can invite into the leader's party")
local three, moIn = CatRiftParty.accept(withMo, 3, opts(211))
assert(moIn.ok)
assert(CatRiftParty.leaderOf(three, 3) == 1)
assert(CatRiftParty.role(three, 2) == "member")
assert(#CatRiftParty.membersOf(three, 1) == 3)

local promoted, alexLeft = CatRiftParty.leave(three, 1, opts(220))
assert(alexLeft.ok)
assert(CatRiftParty.role(promoted, 1) == "solo")
assert(CatRiftParty.leaderOf(promoted, 2) == 2, "Next member leads when the leader leaves")
assert(CatRiftParty.role(promoted, 3) == "member")
assert(promoted.notices[2].text:find("You lead", 1, true))

local soloSam, samLeft = CatRiftParty.leave(promoted, 3, opts(221))
assert(samLeft.ok)
assert(CatRiftParty.role(soloSam, 2) == "solo", "Last member leaving dissolves the party")
assert(CatRiftParty.role(soloSam, 3) == "solo")

local pair, _ = CatRiftParty.accept(CatRiftParty.invite(CatRiftParty.empty(), 1, 2, opts(300)), 2, opts(301))
local afterSam, samGone = CatRiftParty.leave(pair, 2, opts(302))
assert(samGone.ok)
assert(CatRiftParty.role(afterSam, 1) == "solo")
assert(afterSam.notices[1].text:find("You are solo", 1, true))

local busy = CatRiftParty.accept(CatRiftParty.invite(CatRiftParty.empty(), 4, 5, opts(400)), 5, opts(401))
local other, otherSent = CatRiftParty.invite(busy, 1, 5, opts(402))
assert(otherSent.ok == false and otherSent.error:find("another party", 1, true))
local fullParty = busy
for _, id in { 1, 2, 3 } do
	local nextState, added = CatRiftParty.accept(CatRiftParty.invite(fullParty, 4, id, opts(410 + id)), id, opts(411 + id))
	assert(added.ok, added.error)
	fullParty = nextState
end
assert(#CatRiftParty.membersOf(fullParty, 4) == 5)
local overflow, fullErr = CatRiftParty.invite(fullParty, 4, 9, opts(430))
assert(fullErr.ok == false and fullErr.error:find("full", 1, true))

local queuedIds = { 8, 1, 9 }
local paired = CatRiftParty.accept(CatRiftParty.invite(CatRiftParty.empty(), 1, 9, opts(500)), 9, opts(501))
local picked = CatRiftParty.selectForMatch(paired, queuedIds, 2)
assert(picked[1] == 1 and picked[2] == 9, "A later partner is pulled in instead of splitting")
assert(table.find(picked, 8) == nil)
local wide = CatRiftParty.selectForMatch(paired, queuedIds, 10)
assert(wide[1] == 1 and wide[2] == 9 and wide[3] == 8, "A party is seated before a solo when both fit")

local blueParty = CatRiftParty.accept(CatRiftParty.invite(CatRiftParty.empty(), 1, 2, opts(600)), 2, opts(601))
local both = CatRiftParty.accept(CatRiftParty.invite(blueParty, 3, 4, opts(602)), 4, opts(603))
local sides = CatRiftParty.assignTeams(both, { 1, 2, 3, 4 }, 5)
assert(sides[1] == "Blue" and sides[2] == "Blue")
assert(sides[3] == "Red" and sides[4] == "Red")

local hanging = CatRiftParty.invite(CatRiftParty.empty(), 1, 2, opts(700))
local gone = CatRiftParty.disconnect(hanging, 1, opts(701))
assert(CatRiftParty.incoming(gone, 2, 701) == nil)
assert(gone.notices[2].text:find("cancelled", 1, true))
local live = CatRiftParty.accept(CatRiftParty.invite(CatRiftParty.empty(), 1, 2, opts(710)), 2, opts(711))
local dropped = CatRiftParty.disconnect(live, 1, opts(712))
assert(CatRiftParty.role(dropped, 2) == "solo")
assert(CatRiftParty.role(dropped, 1) == "solo")

print("PASS: Cat Rift invite, accept, decline, expiry, leave, queue roster, Practice roster, same-team seats")
