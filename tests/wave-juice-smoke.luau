-- Lane wave telegraph. MinionService still owns the waits. This only predicts them.

local function findCue(rows, id)
	for _, row in rows do
		if row.id == id then
			return row
		end
	end
	return nil
end

local sched = WaveJuice.defaultSchedule()

assert(WaveJuice.FirstWaveDelay == 6, "first wave still waits 6s")
assert(WaveJuice.WaveInterval == 22, "interval between spawn loops is still 22s")
assert(WaveJuice.PerLane == 3, "three kittens per lane")
assert(WaveJuice.KittenStep == 0.35, "between-kitten wait stays 0.35s")
assert(WaveJuice.LeadSeconds >= 2 and WaveJuice.LeadSeconds <= 3, "lead stays inside 2–3s")
assert(WaveJuice.SpawnX == 148 and WaveJuice.SpawnY == 2.2)

assert(WaveJuice.modeAllows("Moba", "InProgress"), "Cat Rift fight may paint")
assert(not WaveJuice.modeAllows("Hub", "InProgress"))
assert(not WaveJuice.modeAllows("YarnRun", "InProgress"))
assert(not WaveJuice.modeAllows("KoiPond", "InProgress"))
assert(not WaveJuice.modeAllows("YarnParty", "InProgress"))
assert(not WaveJuice.modeAllows("MemeArcade", "InProgress"))
assert(not WaveJuice.modeAllows("Moba", "Lobby"))
assert(not WaveJuice.modeAllows("Moba", "ChampionSelect"))
assert(not WaveJuice.modeAllows("Moba", "Ended"))
assert(not WaveJuice.modeAllows("Moba", nil))

local mouths = WaveJuice.mouths()
assert(#mouths == 6, "three lanes, two sides")
local seenMouth = {}
for _, mouth in mouths do
	assert(seenMouth[mouth.id] == nil)
	seenMouth[mouth.id] = true
	assert(mouth.id ~= "CanalLevi")
	assert(string.find(mouth.id, "Pigeon", 1, true) == nil)
	assert(string.find(mouth.id, "Golem", 1, true) == nil)
	assert(mouth.y == WaveJuice.SpawnY)
end
local blueMid = nil
local redBot = nil
for _, mouth in mouths do
	if mouth.id == "Blue-Mid" then
		blueMid = mouth
	elseif mouth.id == "Red-Bot" then
		redBot = mouth
	end
end
assert(blueMid ~= nil and blueMid.x == -148 and blueMid.z == 0, "blue mid mouth is the fountain gate")
assert(redBot ~= nil and redBot.x == 148 and redBot.z == 80)

-- Quiet until the lead into the first top kitten.
assert(#WaveJuice.cues(0, sched) == 0)
assert(#WaveJuice.cues(WaveJuice.FirstWaveDelay - WaveJuice.LeadSeconds - 0.05, sched) == 0)
local open = WaveJuice.cues(WaveJuice.FirstWaveDelay - WaveJuice.LeadSeconds, sched)
assert(#open == 2, "both top mouths light together")
assert(findCue(open, "Blue-Top") ~= nil and findCue(open, "Blue-Top").kind == "telegraph")
assert(findCue(open, "Red-Top") ~= nil and findCue(open, "Red-Top").kind == "telegraph")
assert(findCue(open, "Blue-Mid") == nil, "mid waits for its own kitten")
assert(findCue(open, "Blue-Top").depart == findCue(open, "Red-Top").depart)

local early = findCue(WaveJuice.cues(3.5, sched), "Blue-Top")
local late = findCue(WaveJuice.cues(5.9, sched), "Blue-Top")
assert(early ~= nil and late ~= nil)
assert(late.alpha > early.alpha, "the glow builds toward the step-off")

-- At 5.9s every lane is inside its own lead. Still one cue per mouth.
local crowded = WaveJuice.cues(5.9, sched)
assert(#crowded == 6)
local once = {}
for _, row in crowded do
	assert(once[row.id] == nil, "later kittens in the lane do not add a second telegraph")
	once[row.id] = true
	assert(row.kind == "telegraph")
end

local topDepart = WaveJuice.departElapsed(0, 0, sched)
assert(math.abs(topDepart - 6) < 1e-6, "top's first kitten is still FirstWaveDelay")
local atTop = findCue(WaveJuice.cues(topDepart, sched), "Blue-Top")
assert(atTop ~= nil and atTop.kind == "arrival", "the hush starts as the kitten steps out")
assert(atTop.alpha < 0.02)
local justBefore = findCue(WaveJuice.cues(topDepart - 0.04, sched), "Blue-Top")
assert(justBefore ~= nil and justBefore.kind == "telegraph")
assert(findCue(WaveJuice.cues(topDepart + WaveJuice.ArrivalSeconds, sched), "Blue-Top") == nil)

local midDepart = WaveJuice.departElapsed(0, 1, sched)
assert(math.abs(midDepart - (6 + 3 * 0.35)) < 1e-6, "mid leaves after top's three kittens")
local botDepart = WaveJuice.departElapsed(0, 2, sched)
assert(math.abs(botDepart - (6 + 6 * 0.35)) < 1e-6)

-- A raw 22s step ignores the in-loop waits and would glow early. Do not.
local cycle = WaveJuice.laneCount() * 3 * 0.35 + 22
assert(math.abs(WaveJuice.cycle(sched) - cycle) < 1e-6)
local naive = 6 + 22 - WaveJuice.LeadSeconds
assert(#WaveJuice.cues(naive, sched) == 0, "the stagger is part of the cadence")

local secondTop = WaveJuice.departElapsed(1, 0, sched)
assert(math.abs(secondTop - (6 + cycle)) < 1e-6)
local nextLead = findCue(WaveJuice.cues(secondTop - WaveJuice.LeadSeconds, sched), "Red-Top")
assert(nextLead ~= nil and nextLead.kind == "telegraph")
local nextArrival = findCue(WaveJuice.cues(secondTop, sched), "Blue-Top")
assert(nextArrival ~= nil and nextArrival.kind == "arrival")

-- Fog: only a mouth that is lit or already explored. Camps are not in this list.
local function maskAt(x: number, z: number): { number }
	local flags = table.create(VisionLogic.CellCount, false)
	flags[VisionLogic.indexOf(x, z)] = true
	return VisionLogic.pack(flags)
end

local all = WaveJuice.cues(5.9, sched)
local onlyRedBot = WaveJuice.visible(all, maskAt(redBot.x, redBot.z), nil)
assert(#onlyRedBot == 1 and onlyRedBot[1].id == "Red-Bot")
local remembered = WaveJuice.visible(all, nil, maskAt(blueMid.x, blueMid.z))
assert(#remembered == 1 and remembered[1].id == "Blue-Mid", "explored memory is enough")
assert(#WaveJuice.visible(all, VisionLogic.emptyMask(), VisionLogic.emptyMask()) == 0)
assert(#WaveJuice.visible(all, nil, nil) == 0, "no mask means the mouth stays dark")

local blinkOn = WaveJuice.blinkTransparency("telegraph", 0.2)
local blinkOff = WaveJuice.blinkTransparency("arrival", 0)
local blinkGone = WaveJuice.blinkTransparency("arrival", 0.95)
assert(blinkOn >= 0 and blinkOn <= 1)
assert(blinkGone > blinkOff, "the arrival blink fades")

print("wave-juice-smoke ok")
