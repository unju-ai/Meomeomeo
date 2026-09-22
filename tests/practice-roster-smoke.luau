-- Practice Blue ally cap. Solo keeps two allies. A party eats those seats
-- down to QueueFillTo. Red is not this helper.

local LANES = { "Top", "Mid", "Bot" }

assert(PracticeRoster.allyCount(1, 2, 3) == 2, "solo is 1 human + 2 allies")
assert(PracticeRoster.allyCount(2, 2, 3) == 1, "two humans keep one ally")
assert(PracticeRoster.allyCount(3, 2, 3) == 0, "three Blue humans keep no allies")
assert(PracticeRoster.allyCount(4, 2, 3) == 0, "a larger party still adds no allies")
assert(PracticeRoster.allyCount(5, 2, 3) == 0, "TeamSize party still adds no allies")
assert(PracticeRoster.allyCount(0, 2, 3) == 2, "no humans still respects the ally cap")
assert(PracticeRoster.allyCount(1, 5, 3) == 2, "room under fillTo wins over a higher cap")
assert(PracticeRoster.allyCount(1, 0, 3) == 0, "a zero ally cap adds none")
assert(PracticeRoster.allyCount(1, -3, 3) == 0, "a negative cap is not a negative roster")
assert(PracticeRoster.allyCount(-2, 2, 3) == 2, "negative humans count as none")
assert(PracticeRoster.allyCount(2, 2, 0) == 0, "a zero fill adds none")

assert(PracticeRoster.botLane(1, LANES) == "Top", "one ally takes Top")
assert(PracticeRoster.botLane(2, LANES) == "Mid", "the second ally takes Mid")
assert(PracticeRoster.botLane(3, LANES) == "Bot")
assert(PracticeRoster.botLane(4, LANES) == "Top", "a fourth bot wraps")

print("PASS: practice ally count caps Blue at fillTo; one ally is Top, two are Top then Mid")
