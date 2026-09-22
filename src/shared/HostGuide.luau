--!strict

local BrandCatalog = require(script.Parent.BrandCatalog)
local ModeCatalog = require(script.Parent.ModeCatalog)

-- Authored hub answers stay consistent whether the AI provider is mock or HTTP.
-- Controls and objectives stay accurate. Personality lives in the aside.
local HostGuide = {}

HostGuide.AmbientGap = 45

export type Chip = {
	id: string,
	label: string,
	question: string,
}

local CHIPS: { Chip } = {
	{ id = "CatRift", label = "Cat Rift", question = "Cat Rift" },
	{ id = "Closet", label = "Closet", question = "Closet" },
	{ id = "Fog", label = "Fog", question = "Fog" },
	{ id = "Shop", label = "Shop", question = "Shop" },
	{ id = "Voice", label = "Voice", question = "Voice" },
	{ id = "Help", label = "Help", question = "help" },
}

local ALIASES: { [string]: { string } } = {
	CatRift = { "cat rift", "catrift", "rift", "moba" },
	YarnRun = { "yarn run", "yarnrun", "runner" },
	KoiPond = { "koi pond", "koipond", "koi", "fishing" },
	YarnParty = { "yarn party", "yarnparty", "party" },
	MemeArcade = { "meme arcade", "memearcade", "arcade" },
}

local MODE_ASIDES: { [string]: { [string]: string } } = {
	HostMeo = {
		CatRift = "My strategy is flawless until the other team arrives.",
		YarnRun = "I am not fleeing. I am leading in the opposite direction.",
		KoiPond = "I have scheduled a meeting with a fish.",
		YarnParty = "Four cats. I have already lost the vote.",
		MemeArcade = "My forecast is that I will stare at the chart.",
	},
	HostMe = {
		CatRift = "Scratching posts, then lantern stalls, then the nexus. We wrote it down.",
		YarnRun = "The dog is not a shortcut.",
		KoiPond = "Patience. A concept MEO is still testing.",
		YarnParty = "Read the round instruction before the chaos.",
		MemeArcade = "The yarn is pretend. MEO's confusion is real.",
	},
	HostMo = {
		CatRift = "Three lanes. I brought one thought.",
		YarnRun = "The floor keeps leaving. I respect its decision.",
		KoiPond = "The fish has seen my thoughts. It declined to comment.",
		YarnParty = "I attended the party emotionally. My paws are catching up.",
		MemeArcade = "The candle moved. I remained.",
	},
}

type GuideTopic = {
	id: string,
	title: string,
	aliases: { string },
	fact: string,
}

local GUIDE: { GuideTopic } = {
	{
		id = "Closet",
		title = "Closet",
		aliases = { "closet", "lantern cap", "stall spark", "drip" },
		fact = "Open Closet on the hub. Hats and trails spend yarn points, not Robux. Lantern Cap unlocks after you take an outer post or a lantern stall. Stall Spark unlocks when you win a Cat Rift. A win pays 6 closet yarn and a loss pays 2.",
	},
	{
		id = "Fog",
		title = "Fog",
		aliases = { "fog", "last seen", "ghost", "ghosts" },
		fact = "Unseen ground stays dark and explored ground stays dim. Walls and thick cover block sight. Brush hides you until someone walks in. A last-seen ghost freezes where an enemy left vision, then fades. It is not vision, so you cannot attack a cat you cannot see. That fade is not the Yarn Run personal-best cat.",
	},
	{
		id = "Invite",
		title = "Party queue",
		aliases = { "invite", "party queue", "queue party", "same server" },
		fact = "On the Cat Rift stall, Invite reaches a friend in this same server. Accept or Decline on the card. It lasts about 20 seconds. The leader presses Queue party, or Practice with party, and you share Blue. Practice stays in this server.",
	},
	{
		id = "Pawmart",
		title = "Pawmart",
		aliases = { "pawmart", "shop", "yarn cleave", "cleave", "stall fang", "paper charm" },
		fact = "B opens Pawmart at your fountain. Yarn Cleave is 280 gold: after you buy it, press 7 for a nearby slash, then about 12 seconds. Stall Fang is 300 gold and bites champions at or below 20% HP. Paper Charm is 220 gold: an enemy pink opens about 2.4 seconds of slow immunity, then the charm waits about 20 seconds. 5 is still Whisker Lens. 6 is still Control Yarn.",
	},
	{
		id = "Caster",
		title = "Kitty Caster",
		aliases = { "kitty caster", "caster", "announcer", "first blood" },
		fact = "Kitty Caster calls Cat Rift only: first blood, double through penta, an ace, outer posts, lantern stalls, the yarn core, and victory or defeat. Ordinary kills leave a gap. Lane kittens stay quiet unless that death is first blood or an ace. She stands in the river. Talk there is still the mock lines, with no API key.",
	},
	{
		id = "Ping",
		title = "Pings",
		aliases = { "smart ping", "ping", "pings" },
		fact = "Hold G for the ping wheel. It can name a visible cat, post, stall, ward, or camp. Attention refuses a hidden cat. A fogged ground click or a minimap click can still be Attention or Missing, without a name. Pings wait about 2 seconds.",
	},
	{
		id = "Recap",
		title = "Death recap",
		aliases = { "death recap", "recap", "killing blow" },
		fact = "Death recap lists scratches from about the last 12 seconds: a cat, post, kitten, camp, or item. The killing blow is marked. X closes the card, or it hides about 2.5 seconds before the fountain. Recap brings it back while you are down. Hub, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade do not show it.",
	},
	{
		id = "Purse",
		title = "Purse",
		aliases = { "purse chip", "purse", "creep score", "cs" },
		fact = "The purse chip sits above the ability bar: gold, CS, and level, plus the Yarn Cleave line. Tab shows the same gold and CS. A lane-kitten or camp last hit adds 1 CS. A kill, an assist, or tower gold does not add CS.",
	},
	{
		id = "Voice",
		title = "Voice",
		aliases = { "mute me", "team voice", "voice", "mute" },
		fact = "The voice pill is teammates only. Bots are silent, and enemy cats cannot hear you. Mute me mutes your mic, not SFX or Music. The hub and the other stalls stay quiet until a match assigns your side. Studio blocks voice until you publish and use two eligible clients.",
	},
	{
		id = "Tape",
		title = "Meme tape",
		aliases = { "meme tape", "fight tape", "meme price", "meme prices" },
		fact = "The meme tape sits under the kill feed during Cat Rift only. Prices are play yarn, not gold, not closet yarn, and not the Meme Arcade board. A kill steps that cat up. A death steps it down by less. A post, a stall, or the yarn core steps the taker more. Lane kittens and camps do not move it. Nothing here spends Robux.",
	},
}

local GUIDE_ASIDES: { [string]: { [string]: string } } = {
	HostMeo = {
		Closet = "I will look excellent in Lantern Cap. The unlock is still the post or the stall.",
		Fog = "I can see the whole map. The fog has not received my memo, and the ghost is only the last spot.",
		Invite = "I have already accepted in spirit. You still press Accept. The leader queues the party.",
		Pawmart = "I spent the gold in my head. You still pay at the fountain, then press 7.",
		Caster = "She is narrating my plan. The plan is still posts, then stalls, then the yarn core.",
		Ping = "My thoughts should broadcast themselves. They do not. Hold G.",
		Recap = "The card is a review of my tactics. It still lists the scratches, and the killing blow is marked.",
		Purse = "The chip is my scoreboard. Gold and CS live there. A kill still does not add CS.",
		Voice = "Mute me lowers my mic. I remain correct more quietly. Bots stay silent.",
		Tape = "The tape agrees with me. It is play yarn under the kill feed, not a market, and not the arcade.",
	},
	HostMe = {
		Closet = "Hub button, then the hat. Yarn points only.",
		Fog = "If you cannot see them, you cannot scratch them. Wait for the ghost to fade and move on.",
		Invite = "Same server. One leader. Do not queue twice.",
		Pawmart = "Fountain, B, then the card. 7 does nothing until Yarn Cleave is yours.",
		Caster = "Listen for the structure calls. Last-hitting kittens will not summon her.",
		Ping = "Name what your team can already see. Fog gets a place, not a hidden cat.",
		Recap = "Read it once, then respawn. Recap is there if you missed a row.",
		Purse = "Trust the chip. Tab should match it. Farm kittens if you want CS.",
		Voice = "Mic only. The sliders in Audio are a different mute.",
		Tape = "Glance at it. Do not spend anything on it. Arcade is the other stall.",
	},
	HostMo = {
		Closet = "The lantern sat down on a head. I will arrive after the win, softly.",
		Fog = "The dark kept a photocopy of a cat, then let it go. I understand the dark.",
		Invite = "Someone held the door. The door lasts about 20 seconds. I am still in the hallway.",
		Pawmart = "Seven is a lot of claw. I will hold the paper and think about the fish.",
		Caster = "A voice in the river knows when the lights go out. I brought no microphone.",
		Ping = "I pointed at a feeling. The wheel prefers a cat you can see.",
		Recap = "The receipt arrived after I sat down. The last scratch had signed it.",
		Purse = "The little purse counts coins and scratches. A dramatic death does not add a scratch to CS.",
		Voice = "I muted the mic and left the music. The bots were already quiet.",
		Tape = "Numbers walked past under the scratches. I did not follow them into a shop.",
	},
}

local AMBIENT: { [string]: { string } } = {
	HostMeo = {
		"I am holding office hours. The office is wherever I am standing.",
		"Come closer for a strategy. Stay there if you want the practical one from ME.",
	},
	HostMe = {
		"The stalls are on the hub. I can wait.",
		"Talk if you are lost. I will not chase you.",
	},
	HostMo = {
		"You are a warm shape. I have assigned you a welcome.",
		"The braincell looked up. It went back to sleep.",
	},
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
	kind: string,
	alias: string,
}

local function hitsFor(text: string): { Hit }
	local found: { [string]: Hit } = {}
	local function add(id: string, kind: string, alias: string)
		if not contains(text, alias) then
			return
		end
		local prev = found[id]
		if not prev or #alias > #prev.alias then
			found[id] = { id = id, kind = kind, alias = alias }
		end
	end
	for _, mode in ModeCatalog.all() do
		for _, alias in ALIASES[mode.id] or {} do
			add(mode.id, "mode", alias)
		end
	end
	for _, topic in GUIDE do
		for _, alias in topic.aliases do
			add(topic.id, "guide", alias)
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

local function menu(hostId: string): string
	local names = {}
	for _, mode in ModeCatalog.all() do
		if mode.playable then
			table.insert(names, mode.title)
		end
	end
	local ending = if hostId == "HostMeo" then "Ask me about one. I have prepared at least one thought."
		elseif hostId == "HostMe" then "Ask about a game by name. One question at a time."
		else "Ask about one. The braincell cannot split screen."
	return `Open stalls: {table.concat(names, ", ")}. {ending}`
end

function HostGuide.chips(): { Chip }
	return CHIPS
end

function HostGuide.reply(hostId: string, message: string): string?
	if not BrandCatalog.host(hostId) then
		return nil
	end
	local text = string.lower(message):gsub("[%s%-_]+", " ")
	local hits = hitsFor(text)
	if #hits > 1 or (#hits == 0 and (contains(text, "help") or contains(text, "games") or contains(text, "stalls") or contains(text, "what can i play"))) then
		return menu(hostId)
	end
	local hit = hits[1]
	if not hit then
		return nil
	end
	if hit.kind == "mode" then
		local chosen = ModeCatalog.get(hit.id)
		if not chosen then
			return nil
		end
		local description = if chosen.id == "MemeArcade"
			then "Trade a simulated tape with play yarn, not real money."
			else chosen.blurb
		local entry = if chosen.playable then "Choose its Play button in the hub." else "This stall is not open yet."
		local aside = MODE_ASIDES[hostId][chosen.id]
		return `{chosen.title}: {description} {entry} {aside}`
	end
	local topic = guideById(hit.id)
	if not topic then
		return nil
	end
	return `{topic.title}: {topic.fact} {GUIDE_ASIDES[hostId][topic.id]}`
end

-- One approach, one roll. A failed roll still spends the gap so three nearby
-- hosts cannot each take a turn. A line is rare (one in three) and never opens Talk.
function HostGuide.ambient(hostId: string, now: number, lastAt: number, roll: number): (string?, number)
	if not BrandCatalog.host(hostId) then
		return nil, lastAt
	end
	if now - lastAt < HostGuide.AmbientGap then
		return nil, lastAt
	end
	if roll % 3 ~= 0 then
		return nil, now
	end
	local lines = AMBIENT[hostId]
	local index = (math.floor(roll / 3) % #lines) + 1
	return lines[index], now
end

return HostGuide
