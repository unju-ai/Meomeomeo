--!strict

-- How many Blue ally bots Practice should add.
-- Solo keeps PracticeAllies. Extra Blue humans take those seats so the
-- side stays at QueueFillTo (a party of two is not 4v3). The result is
-- never negative. Red is not this count: Practice still fields PracticeEnemies.

local PracticeRoster = {}

function PracticeRoster.allyCount(humans: number, alliesCap: number, fillTo: number): number
	local seats = math.max(0, humans)
	local room = math.max(0, fillTo - seats)
	local cap = math.max(0, alliesCap)
	return math.min(cap, room)
end

-- Same round-robin BotService uses for bots only.
-- Index 1 is the first lane. With Top / Mid / Bot, one ally is Top
-- and a second ally is Mid. Bot stays open for a human.
function PracticeRoster.botLane(index: number, lanes: { string }): string
	local count = #lanes
	if count <= 0 then
		return "Mid"
	end
	local i = index
	if i < 1 then
		i = 1
	end
	return lanes[((i - 1) % count) + 1] or "Mid"
end

return PracticeRoster
