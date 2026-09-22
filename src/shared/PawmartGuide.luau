--!strict

-- Authored shop coaching for both fountain clerks. Mock and HTTP ask here
-- before a generic line or a network call, same gate as HostGuide / OldTomGuide.
-- Facts stay identical. Personality lives in the aside and the greeting.
local PawmartGuide = {}

PawmartGuide.NpcIds = {
	PawmartBlue = true,
	PawmartRed = true,
}
-- Longer than a host mutter. A miss still spends it.
PawmartGuide.AmbientGap = 70

export type Chip = {
	id: string,
	label: string,
	question: string,
}

local CHIPS: { Chip } = {
	{ id = "Shop", label = "Shop", question = "shop" },
	{ id = "Actives", label = "Actives", question = "actives" },
	{ id = "Wards", label = "Wards", question = "wards" },
	{ id = "Builds", label = "Builds", question = "builds" },
	{ id = "Help", label = "Help", question = "help" },
}

local GREETING: { [string]: string } = {
	PawmartBlue = "Mrrp. Blue register is open. Ask about the book before you waste gold on my floor.",
	PawmartRed = "Mrrp. Red Pawmart. Ask, buy, or leave empty-pawed. I do not do window shopping.",
}

type GuideTopic = {
	id: string,
	title: string,
	aliases: { string },
	fact: string,
}

-- Prices and keys match ItemCatalog / ItemKits / Config.Match.StartingGold.
local GUIDE: { GuideTopic } = {
	{
		id = "Shop",
		title = "Shop",
		aliases = {
			"fountain only",
			"open shop",
			"press b",
			"pawmart",
			"shop",
			"buy",
			"register",
			"fountain",
		},
		fact = "B opens Pawmart at your fountain only. Not recall — that is F. You start with 500 gold. The purse chip above the ability bar shows gold, CS, and level. Tab matches gold and CS. A lane-kitten or camp last hit adds 1 CS. Kill, assist, and tower gold do not. Spending here spends gold and leaves CS alone.",
	},
	{
		id = "Actives",
		title = "Actives",
		aliases = {
			"yarn cleave",
			"whisker lens",
			"control yarn",
			"actives",
			"active",
			"cleave",
			"lens",
			"press 5",
			"press 6",
			"press 7",
			"key 5",
			"key 6",
			"key 7",
		},
		fact = "Whisker Lens is 180 gold, then 5: 80 damage to enemy wards inside about 32 studs, then about 75 seconds. Control Yarn is 75 gold, two charges, then 6: a magenta pink everyone can see. Yarn Cleave is 280 gold, then 7: a 12-stud slash for 40 damage on visible enemies, then 12 seconds. Misses still start the cooldown. None of those three add flat damage, HP, mana, armor, or speed.",
	},
	{
		id = "Wards",
		title = "Wards",
		aliases = {
			"paper charm",
			"wards",
			"ward",
			"pinks",
			"pink",
			"trinket",
			"charm",
		},
		fact = "4 plants a free stealthed trinket, one live, about 70 seconds before the next, lasting about 60. Control Yarn pinks last about 90 seconds, slow enemies inside about 22 studs, and reveal nearby enemy trinkets. Your own pink slows enemies, not you. Paper Charm is 220 gold: an enemy pink opens about 2.4 seconds of slow immunity, then the charm waits about 20. Hard bots drop one free pink, then buy Control Yarn and plant it toward the river.",
	},
	{
		id = "Builds",
		title = "Builds",
		aliases = {
			"pounce boots",
			"mana treat",
			"stall fang",
			"yarnplate",
			"longclaw",
			"hard bot",
			"starting gold",
			"builds",
			"build",
			"boots",
			"fang",
			"purse",
			"cs",
		},
		fact = "Longclaw is 250 gold and adds 18 ability damage. Yarnplate is 250 gold: +90 HP and 12% armor. Mana Treat is 200 gold and adds 90 mana. Pounce Boots are 200 gold and add 6 walk speed. Stall Fang is 300 gold and adds 36 raw damage to champion hits at or below 20% HP. On Hard, bots buy a short role plan at the opening fountain (bruiser Yarnplate + Paper Charm, assassin Longclaw + boots, mage Mana Treat + Longclaw), then finish Fang or Cleave, then Control Yarn, then Lens on later visits. They plant that yarn toward the river.",
	},
}

local ASIDES: { [string]: { [string]: string } } = {
	PawmartBlue = {
		Shop = "I stamped the receipt. Fountain pad. No delivery.",
		Actives = "I wrote 5, 6, and 7 on the bag. Do not ask me to press them for you.",
		Wards = "Pink is not a gift wrap. Charm is the return policy for their slow.",
		Builds = "I do not do outfits. I do durable goods and one Hard-bot footnote.",
	},
	PawmartRed = {
		Shop = "Buy here or bleed gold mid. The register does not take Robux.",
		Actives = "Upsell complete: lens, pink, cleave. Leave with at least one.",
		Wards = "Plant the magenta. Charm the enemy pink. I will not refund a face-check.",
		Builds = "Hard already rang up a role starter. Match the ticket or get scratched.",
	},
}

local AMBIENT: { [string]: { string } } = {
	PawmartBlue = {
		"Fountain only. B opens the book. I am not walking it out to mid.",
		"500 gold on open. CS is last hits. I already printed that once.",
		"Lens is 5. Pink is 6. Cleave is 7. The bag says so.",
	},
	PawmartRed = {
		"Hard bots already spent. Catch up or get scratched.",
		"Ask about cleave before you leave empty-pawed.",
		"Fountain buys only. Mid is not my aisle.",
	},
}

local function isClerk(npcId: string): boolean
	return PawmartGuide.NpcIds[npcId] == true
end

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

local function menu(npcId: string): string
	local ending = if npcId == "PawmartBlue"
		then "One question. I am not reprinting the whole catalog."
		else "One question. I upsell in single servings."
	return `Ask Shop, Actives, Wards, or Builds. {ending}`
end

function PawmartGuide.chips(): { Chip }
	return CHIPS
end

function PawmartGuide.greeting(npcId: string): string?
	return GREETING[npcId]
end

function PawmartGuide.reply(npcId: string, message: string): string?
	if not isClerk(npcId) then
		return nil
	end
	local text = string.lower(message):gsub("[%s%-_]+", " ")
	local hits = hitsFor(text)
	if #hits > 1 or (#hits == 0 and (contains(text, "help") or contains(text, "coach") or contains(text, "tips"))) then
		return menu(npcId)
	end
	local hit = hits[1]
	if not hit then
		return nil
	end
	local topic = guideById(hit.id)
	if not topic then
		return nil
	end
	local aside = ASIDES[npcId][topic.id]
	return `{topic.title}: {topic.fact} {aside}`
end

-- One approach, one roll. A failed roll still spends the gap so standing on
-- the prompt cannot reroll every flicker. Callers limit this to Cat Rift.
function PawmartGuide.ambient(npcId: string, now: number, lastAt: number, roll: number): (string?, number)
	if not isClerk(npcId) then
		return nil, lastAt
	end
	if now - lastAt < PawmartGuide.AmbientGap then
		return nil, lastAt
	end
	if roll % 4 ~= 0 then
		return nil, now
	end
	local lines = AMBIENT[npcId]
	local index = (math.floor(roll / 4) % #lines) + 1
	return lines[index], now
end

return PawmartGuide
