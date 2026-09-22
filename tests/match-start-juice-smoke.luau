-- Cat Rift fight-begin cue. MatchService still owns the phase edge. This only reads it.

local start = 1000

assert(MatchStartJuice.blocksInput() == false, "the cue does not lock movement")
assert(MatchStartJuice.FightText == "Fight!")
assert(MatchStartJuice.StingCue == "PingSoft", "quiet existing tick, not a new caster line")
assert(MatchStartJuice.FreshSeconds >= 1 and MatchStartJuice.FreshSeconds <= 3)
assert(MatchStartJuice.CountdownRoom >= 2.8 and MatchStartJuice.CountdownRoom <= 3.2)
assert(MatchStartJuice.BlueX == -176 and MatchStartJuice.RedX == 176 and MatchStartJuice.PadZ == 0)
assert(MatchStartJuice.padX("Blue") == -176)
assert(MatchStartJuice.padX("Red") == 176)

assert(MatchStartJuice.modeAllows("Moba", "InProgress"))
assert(not MatchStartJuice.modeAllows("Moba", "ChampionSelect"))
assert(not MatchStartJuice.modeAllows("Moba", "Lobby"))
assert(not MatchStartJuice.modeAllows("Moba", "Ended"))
assert(not MatchStartJuice.modeAllows("Moba", nil))
assert(not MatchStartJuice.modeAllows("Hub", "InProgress"))
assert(not MatchStartJuice.modeAllows("YarnRun", "InProgress"))
assert(not MatchStartJuice.modeAllows("KoiPond", "InProgress"))
assert(not MatchStartJuice.modeAllows("YarnParty", "InProgress"))
assert(not MatchStartJuice.modeAllows("MemeArcade", "InProgress"))

-- Live stamp: startedAt is now. One Fight!, glow, sting. No digit.
local abrupt = MatchStartJuice.decide("Moba", "InProgress", start, start + 0.02, true, nil, nil)
assert(abrupt ~= nil and abrupt.kind == "fight" and abrupt.text == "Fight!")
assert(abrupt.glow and abrupt.sting)
assert(MatchStartJuice.decide("Moba", "InProgress", start, start + 0.4, true, start, nil) == nil, "one cue per stamp")

-- A few milliseconds of client lag is not a 3.
assert(MatchStartJuice.decide("Moba", "InProgress", start, start - 0.04, true, nil, nil) == nil)
assert(MatchStartJuice.shouldWatch("Moba", "InProgress", start, start - 0.04, true, nil))
local caught = MatchStartJuice.decide("Moba", "InProgress", start, start + 0.01, true, nil, nil)
assert(caught ~= nil and caught.kind == "fight")

-- Rejoin deep into the fight stays quiet, and does not keep a watcher.
assert(MatchStartJuice.decide("Moba", "InProgress", start, start + 30, true, nil, nil) == nil)
assert(not MatchStartJuice.shouldWatch("Moba", "InProgress", start, start + 30, true, nil))

-- Draft, spectators, and the other stalls.
assert(MatchStartJuice.decide("Moba", "ChampionSelect", nil, start, true, nil, nil) == nil)
assert(MatchStartJuice.decide("Moba", "Lobby", nil, start, true, nil, nil) == nil)
assert(MatchStartJuice.decide("Moba", "Ended", start, start, true, nil, nil) == nil)
assert(MatchStartJuice.decide("Moba", "InProgress", start, start, false, nil, nil) == nil)
for _, mode in { "Hub", "YarnRun", "KoiPond", "YarnParty", "MemeArcade" } do
	assert(MatchStartJuice.decide(mode, "InProgress", start, start, true, nil, nil) == nil)
	assert(not MatchStartJuice.shouldWatch(mode, "InProgress", start, start, true, nil))
end

-- A stamp already ~3s ahead may count. Anything shorter waits, then Fight!.
assert(MatchStartJuice.decide("Moba", "InProgress", start, start - 10, true, nil, nil) == nil)
assert(MatchStartJuice.decide("Moba", "InProgress", start, start - 1.2, true, nil, nil) == nil)
local short = MatchStartJuice.decide("Moba", "InProgress", start, start + 0.02, true, nil, nil)
assert(short ~= nil and short.kind == "fight")

local three = MatchStartJuice.decide("Moba", "InProgress", start, start - 2.4, true, nil, nil)
assert(three ~= nil and three.kind == "count" and three.text == "3")
assert(not three.glow and not three.sting)
local two = MatchStartJuice.decide("Moba", "InProgress", start, start - 1.5, true, nil, start)
assert(two ~= nil and two.text == "2" and two.kind == "count")
local one = MatchStartJuice.decide("Moba", "InProgress", start, start - 0.4, true, nil, start)
assert(one ~= nil and one.text == "1")
local go = MatchStartJuice.decide("Moba", "InProgress", start, start + 0.05, true, nil, start)
assert(go ~= nil and go.kind == "fight" and go.text == "Fight!" and go.glow and go.sting)
assert(MatchStartJuice.decide("Moba", "InProgress", start, start + 0.2, true, start, start) == nil)

-- A later match gets its own cue.
local again = MatchStartJuice.decide("Moba", "InProgress", start + 500, start + 500.01, true, start, nil)
assert(again ~= nil and again.kind == "fight" and again.startedAt == start + 500)

assert(MatchStartJuice.digit(2.4) == "3")
assert(MatchStartJuice.digit(2) == "2")
assert(MatchStartJuice.digit(1) == "1")
assert(MatchStartJuice.digit(0) == nil)
assert(MatchStartJuice.digit(4) == nil)
