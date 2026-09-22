--!strict

-- Authored jungle coaching for Old Tom. Mock and HTTP both ask here before a
-- generic line or a network call, same gate as HostGuide. He is pull-to-talk:
-- these replies are not match callouts.
-- Joke first, then one useful fact. The fact has to match the live controls.
local OldTomGuide = {}

OldTomGuide.NpcId = "OldTom"
OldTomGuide.Greeting = "Mrrp. Sit a moment, kitten. The jungle can wait one question."
-- Longer than a host mutter, and a miss still spends it. He is not an announcer.
OldTomGuide.AmbientGap = 75

export type Chip = {
	id: string,
	label: string,
	question: string,
}

local CHIPS: { Chip } = {
	{ id = "Camps", label = "Camps", question = "camps" },
	{ id = "Wards", label = "Wards", question = "wards" },
	{ id = "Fog", label = "Fog", question = "fog" },
	{ id = "Route", label = "Route", question = "route" },
	{ id = "Help", label = "Help", question = "help" },
}

type GuideTopic = {
	id: string,
	title: string,
	aliases: { string },
	joke: string,
	fact: string,
}

local GUIDE: { GuideTopic } = {
	{
		id = "Camps",
		title = "Camps",
		aliases = {
			"camps",
			"camp",
			"pigeon pack",
			"pigeons",
			"pigeon",
			"yarn golem",
			"golem",
			"river crab",
			"crabs",
			"crab",
			"clear",
			"rotate",
			"past the river",
			"jungle",
			"canal levi",
			"levi",
		},
		joke = "What do you call a pigeon with a watch, kitten? A 32-second appointment.",
		fact = "Pigeon Pack pays 22 gold and returns in about 32 seconds. Yarn Golem pays 48 gold and returns in about 45 seconds. A river crab pays 36 gold and returns in about 50 seconds. The last hit adds 1 CS. Clear your own side once the wave is past the river, and finish a camp you already hurt — Hard stays on one under about 40% HP, Normal under about 55% HP. A healthy camp can wait if a cat is in your face (about 32 studs on Hard, about 22 on Normal). Drag one past about 38 studs and it resets. When they are down, rotate to the pushed lane. Do not pace the river. Canal Levi wakes in the canal about 3 minutes in, pays 140 gold, and comes back once about 90 seconds later. The last hit's team keeps +8% damage for the rest of the match.",
	},
	{
		id = "Wards",
		title = "Wards",
		aliases = {
			"wards",
			"ward",
			"pinks",
			"pink",
			"control yarn",
			"whisker lens",
			"paper charm",
			"lens",
			"trinket",
		},
		joke = "Why did the pink ward blush, kitten? Because everyone could see it.",
		fact = "4 plants a free stealthed trinket, one live, about 70 seconds before the next, and it lasts about 60 seconds. Control Yarn is 75 gold at the fountain with B, two charges, then 6: a magenta pink everyone can see. It lasts about 90 seconds, slows enemies inside about 22 studs, and reveals nearby enemy trinkets. Whisker Lens is 180 gold, then 5: 80 damage to enemy wards inside about 32 studs (a trinket at 60 pops, a full pink at 90 does not), then it waits about 75 seconds. Your own pink slows enemies, not you. Paper Charm shrugs an enemy pink for about 2.4 seconds, then waits about 20. Hard bots drop one free pink and do not buy Control Yarn.",
	},
	{
		id = "Fog",
		title = "Fog",
		aliases = { "fog", "crab brush", "brush", "ghosts", "ghost", "last seen", "explored", "river" },
		joke = "I told the fog a secret, kitten. It kept the last place it saw me, then let go.",
		fact = "Unseen ground stays dark, and ground you already lit stays a dim explored tint for this match only. Walls and the thick market drums block sight. Brush hides you until someone steps into that same pocket, and you cannot scratch a cat you cannot see. A last-seen ghost freezes where they left vision and fades in about 1.8 seconds. It is not vision, and it is not the Yarn Run personal-best cat. Treat the river as a caution: ward it before you face-check the crab brush.",
	},
	{
		id = "Route",
		title = "Route",
		aliases = { "jungle route", "hard bot", "hard mid", "jungler", "route" },
		joke = "Why did Hard mid bring a list, kitten? The pigeons would not form a line.",
		fact = "Only mid jungles on Hard. Top and bot stay in lane. Blue walks pigeon pack NW, yarn golem NW, the north river crab, then the south river crab. Red — the Practice bots — walks pigeon pack SE, yarn golem SE, the south river crab, then the north river crab. They hold that camp until it dies and they do not flip between the crabs. Show yourself on a healthy camp and they turn, inside about 32 studs. Under about 40% HP they finish the camp first. Camps pop about 8 seconds in. After the four are down they rotate to the lane where the allied wave is furthest up. A sighting from about the last 8 seconds can pull that rotate. They will not path into brush just because a ghost stood there. Easy never clears. Normal mid takes the nearest own-side camp only after the wave is past the river. If Canal Levi is up and Hard mid is not already on a camp, they may walk the canal before the next one. Normal and Easy ignore it. The Hard jungler plants one free pink and does not buy Control Yarn.",
	},
}

local AMBIENT = {
	"Finish the camp you already hurt, kitten, then look at the pushed lane.",
	"The river is a suggestion, kitten. Ward it before the crab brush.",
	"Hard mid already walks pigeon, then golem, then the crabs, kitten. Count them.",
	"A pink is a love letter everyone can read, kitten. Buy Control Yarn, then press 6.",
}

local function contains(text: string, phrase: string): boolean
	return string.find(text, "%f[%w]" .. phrase .. "%f[%W]") ~= nil
end

local function guideById(id: string): GuideTopic?
	for _, topic in GUIDE do
		if topic.id == id then
			return topic
		end
	end
	return nil
end

type Hit = {
	id: string,
	alias: string,
}

local function hitsFor(text: string): { Hit }
	local found: { [string]: Hit } = {}
	for _, topic in GUIDE do
		for _, alias in topic.aliases do
			if contains(text, alias) then
				local prev = found[topic.id]
				if not prev or #alias > #prev.alias then
					found[topic.id] = { id = topic.id, alias = alias }
				end
			end
		end
	end
	local kept: { Hit } = {}
	for id, row in found do
		local covered = false
		for otherId, other in found do
			if otherId ~= id and #other.alias > #row.alias and contains(other.alias, row.alias) then
				covered = true
				break
			end
		end
		if not covered then
			table.insert(kept, row)
		end
	end
	return kept
end

local function menu(): string
	return "Ask one thing, kitten: Camps, Wards, Fog, or Route. I will not recite the whole jungle at once."
end

function OldTomGuide.chips(): { Chip }
	return CHIPS
end

function OldTomGuide.reply(npcId: string, message: string): string?
	if npcId ~= OldTomGuide.NpcId then
		return nil
	end
	local text = string.lower(message):gsub("[%s%-_]+", " ")
	local hits = hitsFor(text)
	if #hits > 1 or (#hits == 0 and (contains(text, "help") or contains(text, "coach"))) then
		return menu()
	end
	local hit = hits[1]
	if not hit then
		return nil
	end
	local topic = guideById(hit.id)
	if not topic then
		return nil
	end
	return `{topic.title}: {topic.joke} {topic.fact}`
end

-- One approach, one roll. A failed roll still spends the gap so standing on
-- the prompt cannot reroll every flicker. Callers limit this to Cat Rift.
function OldTomGuide.ambient(npcId: string, now: number, lastAt: number, roll: number): (string?, number)
	if npcId ~= OldTomGuide.NpcId then
		return nil, lastAt
	end
	if now - lastAt < OldTomGuide.AmbientGap then
		return nil, lastAt
	end
	if roll % 4 ~= 0 then
		return nil, now
	end
	local index = (math.floor(roll / 4) % #AMBIENT) + 1
	return AMBIENT[index], now
end

return OldTomGuide
