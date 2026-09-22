-- Run through tools/test-announcer.py against AnnouncerLines.

assert(AnnouncerLines.OrdinaryCooldown == 8)
assert(AnnouncerLines.StreakWindow == 10)

assert(AnnouncerLines.catName("Nyan Rocket", "Nyan Rocket (Bot)") == "Nyan Rocket (Bot)")
assert(AnnouncerLines.catName("Scammy McMittens", "Alex") == "Scammy McMittens (Alex)")
assert(AnnouncerLines.catName(nil, "Alex") == "Alex")
assert(AnnouncerLines.catName(nil, nil) == "a cat")

assert(AnnouncerLines.causeFrom("minion", false) == "minion")
assert(AnnouncerLines.causeFrom("jungle", false) == "jungle")
assert(AnnouncerLines.causeFrom("tower", false) == "tower")
assert(AnnouncerLines.causeFrom("item", true) == "champion")
assert(AnnouncerLines.causeFrom("champion", true) == "champion")
assert(AnnouncerLines.causeFrom(nil, true) == "champion")
assert(AnnouncerLines.causeFrom(nil, false) == "minion")

assert(AnnouncerLines.isAce(0, 1) == false)
assert(AnnouncerLines.isAce(0, 2) == true)
assert(AnnouncerLines.isAce(1, 3) == false)
assert(AnnouncerLines.isAce(0, 3) == true)

assert(AnnouncerLines.streakBeat(1) == nil)
assert(AnnouncerLines.streakBeat(2) == "DoubleKill")
assert(AnnouncerLines.streakBeat(3) == "TripleKill")
assert(AnnouncerLines.streakBeat(4) == "QuadraKill")
assert(AnnouncerLines.streakBeat(5) == "PentaKill")
assert(AnnouncerLines.streakBeat(6) == "PentaKill")

assert(AnnouncerLines.allows(3, 0, true) == true)
assert(AnnouncerLines.allows(0, nil, false) == true)
assert(AnnouncerLines.allows(7.9, 0, false) == false)
assert(AnnouncerLines.allows(8, 0, false) == true)

local book = {}
local count
count, book = AnnouncerLines.advanceStreak(book, 7, 0)
assert(count == 1)
count, book = AnnouncerLines.advanceStreak(book, 7, 4)
assert(count == 2)
count, book = AnnouncerLines.advanceStreak(book, 7, 10)
assert(count == 3)
count, book = AnnouncerLines.advanceStreak(book, 7, 20.01)
assert(count == 1)
count, book = AnnouncerLines.advanceStreak(book, 8, 21)
assert(count == 1)
count, book = AnnouncerLines.advanceStreak(book, 7, 31)
assert(count == 1)

local function kill(overrides)
	local query = {
		now = 0,
		firstBloodTaken = false,
		cause = "champion",
		streak = 1,
		ace = false,
		lastOrdinaryAt = nil,
		killer = "Scammy McMittens (Alex)",
		victim = "Nyan Rocket (Bot)",
		victimTeam = "Red",
		finisher = "Scammy McMittens (Alex)",
		roll = 1,
	}
	for key, value in overrides do
		query[key] = value
	end
	return AnnouncerLines.decideKill(query)
end

local function noBrace(line: string)
	assert(string.find(line, "{", 1, true) == nil, line)
end

local first = kill({})
assert(first.speak == true)
assert(first.beat == "FirstBlood")
assert(first.priority == true)
assert(first.cue == "Announcer")
assert(first.line == "FIRST BLOOD — Scammy McMittens (Alex) just IPO'd Nyan Rocket (Bot).")
noBrace(first.line)

local firstLane = kill({
	cause = "minion",
	killer = nil,
	finisher = "lane kittens",
	streak = 0,
})
assert(firstLane.speak == true)
assert(firstLane.beat == "FirstBloodLane")
assert(firstLane.line == "FIRST BLOOD — lane kittens liquidated Nyan Rocket (Bot).")
assert(firstLane.cue == "Announcer")

local crowded = kill({
	firstBloodTaken = true,
	now = 3,
	lastOrdinaryAt = 0,
	streak = 1,
})
assert(crowded.speak == false)
assert(crowded.beat == "ChampionKill")
assert(crowded.line == nil)

local later = kill({
	firstBloodTaken = true,
	now = 8,
	lastOrdinaryAt = 0,
	streak = 1,
})
assert(later.speak == true)
assert(later.beat == "ChampionKill")
assert(later.cue == nil)
assert(later.line == "Scammy McMittens (Alex) deleted Nyan Rocket (Bot). The chart says thanks.")
local laterAlt = kill({
	firstBloodTaken = true,
	now = 8,
	lastOrdinaryAt = 0,
	streak = 1,
	roll = 2,
})
assert(laterAlt.line ~= later.line)
assert(string.find(laterAlt.line, "Scammy McMittens (Alex)", 1, true))

local double = kill({
	firstBloodTaken = true,
	now = 3,
	lastOrdinaryAt = 0,
	streak = 2,
})
assert(double.speak == true)
assert(double.beat == "DoubleKill")
assert(double.priority == true)
assert(string.find(double.line, "DOUBLE KILL", 1, true) == 1)

local triple = kill({ firstBloodTaken = true, streak = 3, lastOrdinaryAt = 0, now = 1 })
assert(triple.beat == "TripleKill" and triple.speak == true)
local quadra = kill({ firstBloodTaken = true, streak = 4, lastOrdinaryAt = 0, now = 1 })
assert(quadra.beat == "QuadraKill" and quadra.speak == true)
local penta = kill({ firstBloodTaken = true, streak = 5, ace = true, lastOrdinaryAt = 0, now = 1 })
assert(penta.beat == "PentaKill" and penta.speak == true)
assert(penta.cue == "Announcer")

local ace = kill({
	firstBloodTaken = true,
	streak = 1,
	ace = true,
	now = 1,
	lastOrdinaryAt = 0,
})
assert(ace.speak == true)
assert(ace.beat == "Ace")
assert(ace.line == "ACE — Red is a ghost town. Scammy McMittens (Alex) took the last cat.")

local laneQuiet = kill({
	cause = "minion",
	firstBloodTaken = true,
	ace = false,
	streak = 0,
	killer = nil,
	now = 30,
})
assert(laneQuiet.speak == false)
assert(laneQuiet.line == nil)

local jungleQuiet = kill({
	cause = "jungle",
	firstBloodTaken = true,
	ace = false,
	streak = 0,
	killer = nil,
})
assert(jungleQuiet.speak == false)

local laneAce = kill({
	cause = "minion",
	firstBloodTaken = true,
	ace = true,
	streak = 0,
	killer = nil,
	finisher = "lane kittens",
	now = 1,
	lastOrdinaryAt = 0,
})
assert(laneAce.speak == true)
assert(laneAce.beat == "AceLane")
assert(laneAce.line == "ACE — lane kittens emptied Red.")

local tower = kill({
	cause = "tower",
	firstBloodTaken = true,
	streak = 0,
	killer = nil,
	finisher = "a scratching post",
	now = 9,
	lastOrdinaryAt = 0,
})
assert(tower.speak == true)
assert(tower.beat == "TowerKill")
assert(tower.cue == nil)
assert(tower.line == "Nyan Rocket (Bot) facetanked a scratching post.")

local towerQuiet = kill({
	cause = "tower",
	firstBloodTaken = true,
	streak = 0,
	killer = nil,
	now = 2,
	lastOrdinaryAt = 0,
})
assert(towerQuiet.speak == false)
assert(towerQuiet.beat == "TowerKill")

local outer = AnnouncerLines.structures({
	kind = "Tower",
	tier = "Outer",
	team = "Red",
	lane = "Mid",
	who = "Scammy McMittens (Alex)",
	coreOpened = false,
	roll = 1,
})
assert(#outer == 1)
assert(outer[1].beat == "OuterDown")
assert(outer[1].cue == nil)
assert(outer[1].line == "Scammy McMittens (Alex) dropped the Red Mid scratching post. Stall's open.")

local stall = AnnouncerLines.structures({
	kind = "Tower",
	tier = "Inner",
	team = "Blue",
	lane = "Bot",
	who = "Lane kittens",
	coreOpened = true,
	roll = 1,
})
assert(#stall == 2)
assert(stall[1].beat == "StallDown")
assert(stall[1].line == "Lane kittens snuffed the Blue Bot lantern stall.")
assert(stall[2].beat == "CoreOpen")
assert(stall[2].cue == "Announcer")
assert(stall[2].line == "Blue yarn core is OPEN. Send it.")

local nexus = AnnouncerLines.structures({
	kind = "Nexus",
	tier = "Core",
	team = "Red",
	lane = "Base",
	who = "Scammy McMittens (Alex)",
	coreOpened = true,
	roll = 1,
})
assert(#nexus == 1)
assert(nexus[1].beat == "CoreDestroyed")
assert(nexus[1].cue == nil)
assert(string.find(nexus[1].line, "yarn core", 1, true))

local unknown = AnnouncerLines.structures({
	kind = "Ward",
	tier = "Outer",
	team = "Red",
	lane = "Mid",
	who = "Someone",
	coreOpened = true,
	roll = 1,
})
assert(#unknown == 0)

local practice = AnnouncerLines.draft(true, "Hard", 1)
assert(practice.speak == true)
assert(practice.beat == "DraftPractice")
assert(practice.line == "Practice draft is open. Red is 3 bots (Hard). Lock a cat.")
assert(practice.cue == "Announcer")

local ranked = AnnouncerLines.draft(false, nil, 1)
assert(ranked.beat == "Draft")
assert(string.find(ranked.line, "lock a cat", 1, true) or string.find(ranked.line, "Lock a cat", 1, true))

local live = AnnouncerLines.live(1)
assert(live.beat == "MatchLive")
assert(live.line == "WE ARE LIVE. Posts, then stalls, then the yarn core.")
assert(live.cue == "Announcer")

local victory = AnnouncerLines.matchEnd(true, "Blue", 1)
assert(victory.beat == "Victory")
assert(victory.cue == "MatchFound")
assert(victory.line == "VICTORY — Blue halted the tape. We are so back.")

local defeat = AnnouncerLines.matchEnd(false, "Blue", 1)
assert(defeat.beat == "Defeat")
assert(defeat.cue == "Announcer")
assert(defeat.line == "DEFEAT — your yarn core rug-pulled. GG.")
assert(string.find(defeat.line, "VICTORY", 1, true) == nil)

print("announcer smoke ok")
