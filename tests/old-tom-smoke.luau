-- Run through tools/test-old-tom.py. Old Tom's coaching stays authored and local.
local function contains(reply: string, phrase: string): boolean
	return string.find(reply, phrase, 1, true) ~= nil
end

local function ask(message: string): string
	local reply = OldTomGuide.reply("OldTom", message)
	assert(reply, message .. " should coach")
	return reply
end

assert(OldTomGuide.reply("HostMeo", "camps") == nil)
assert(OldTomGuide.reply("KittyCaster", "wards") == nil)
assert(OldTomGuide.reply("PawmartBlue", "fog") == nil)
assert(OldTomGuide.reply("OldTom", "hello") == nil)
assert(OldTomGuide.reply("OldTom", "closet") == nil)
assert(OldTomGuide.reply("OldTom", "yarn run") == nil)
assert(HostGuide.reply("OldTom", "help") == nil)
assert(HostGuide.reply("OldTom", "camps") == nil)

local help = ask("help")
assert(contains(help, "kitten"))
assert(contains(help, "Camps") and contains(help, "Wards") and contains(help, "Fog") and contains(help, "Route"))
assert(not contains(help, "22 gold"), "Help stays a menu")
assert(not contains(help, "75 gold") and not contains(help, "1.8") and not contains(help, "pigeon pack SE"))
assert(ask("HELP") == help)
assert(ask("coach") == help)
assert(ask("camps and wards") == help)
assert(ask("route or fog") == help)

local camps = ask("camps")
assert(contains(camps, "kitten"))
assert(contains(camps, "32-second appointment"))
assert(string.find(camps, "32-second appointment", 1, true) < string.find(camps, "22 gold", 1, true))
assert(contains(camps, "22 gold") and contains(camps, "about 32 seconds"))
assert(contains(camps, "48 gold") and contains(camps, "about 45 seconds"))
assert(contains(camps, "36 gold") and contains(camps, "about 50 seconds"))
assert(contains(camps, "1 CS"))
assert(contains(camps, "past the river"))
assert(contains(camps, "40% HP") and contains(camps, "55% HP"))
assert(contains(camps, "32 studs") and contains(camps, "22 on Normal"))
assert(contains(camps, "38 studs"))
assert(contains(camps, "pushed lane") and contains(camps, "Do not pace the river"))
assert(not contains(camps, "pigeon pack SE"))
assert(not contains(camps, "75 gold"))
assert(ask("CAMPS") == camps)
assert(ask("YARN-GOLEM") == ask("golem"))
assert(contains(ask("pigeon"), "22 gold"))
assert(contains(ask("river crab"), "36 gold") and not contains(ask("river crab"), "1.8"))
assert(ask("past the river") == camps)
assert(ask("rotate") == camps)

local wards = ask("wards")
assert(contains(wards, "everyone could see it"))
assert(string.find(wards, "everyone could see it", 1, true) < string.find(wards, "75 gold", 1, true))
assert(contains(wards, "stealthed") and contains(wards, "about 70 seconds") and contains(wards, "about 60 seconds"))
assert(contains(wards, "75 gold") and contains(wards, "two charges") and contains(wards, "then 6"))
assert(contains(wards, "magenta") and contains(wards, "about 90 seconds") and contains(wards, "about 22 studs"))
assert(contains(wards, "180 gold") and contains(wards, "then 5") and contains(wards, "about 32 studs"))
assert(contains(wards, "80 damage") and contains(wards, "trinket at 60") and contains(wards, "pink at 90"))
assert(contains(wards, "about 75 seconds"))
assert(contains(wards, "not you"))
assert(contains(wards, "2.4 seconds") and contains(wards, "about 20"))
assert(contains(wards, "do not buy Control Yarn"))
assert(not contains(wards, "22 gold") and not contains(wards, "1.8"))
assert(ask("CONTROL-YARN") == ask("control yarn"))
assert(ask("whisker lens") == ask("lens"))
assert(ask("paper charm") == wards)
assert(ask("pinks") == wards)
assert(contains(ask("trinket"), "4 plants"))

local fog = ask("fog")
assert(contains(fog, "then let go"))
assert(string.find(fog, "then let go", 1, true) < string.find(fog, "1.8", 1, true))
assert(contains(fog, "stays dark") and contains(fog, "explored tint") and contains(fog, "this match only"))
assert(contains(fog, "market drums") and contains(fog, "same pocket"))
assert(contains(fog, "cannot scratch"))
assert(contains(fog, "1.8 seconds") and contains(fog, "not vision"))
assert(contains(fog, "Yarn Run personal-best"))
assert(contains(fog, "crab brush"))
assert(not contains(fog, "22 gold") and not contains(fog, "75 gold") and not contains(fog, "pigeon pack SE"))
assert(ask("last-seen") == ask("last seen"))
assert(ask("ghosts") == fog)
assert(ask("brush") == fog)
assert(ask("river") == fog)
assert(ask("crab brush") == fog)
assert(contains(ask("explored"), "this match only"))

local route = ask("route")
assert(contains(route, "would not form a line"))
assert(string.find(route, "would not form a line", 1, true) < string.find(route, "pigeon pack SE", 1, true))
assert(contains(route, "Only mid") and contains(route, "Top and bot stay in lane"))
assert(contains(route, "pigeon pack NW") and contains(route, "north river crab, then the south"))
assert(contains(route, "pigeon pack SE") and contains(route, "south river crab, then the north"))
assert(contains(route, "do not flip"))
assert(contains(route, "32 studs") and contains(route, "40% HP"))
assert(contains(route, "about 8 seconds in") and contains(route, "last 8 seconds"))
assert(contains(route, "furthest up"))
assert(contains(route, "just because a ghost stood there"))
assert(contains(route, "Easy never clears"))
assert(contains(route, "past the river"))
assert(contains(route, "does not buy Control Yarn"))
assert(not contains(route, "22 gold") and not contains(route, "75 gold"))
assert(ask("hard bot") == route)
assert(ask("hard mid") == route)
assert(ask("jungler") == route)
assert(ask("jungle route") == route)
assert(contains(ask("jungle"), "22 gold") and not contains(ask("jungle"), "pigeon pack SE"))

local chips = OldTomGuide.chips()
assert(#chips == 5)
for _, chip in chips do
	local reply = ask(chip.question)
	assert(reply == ask(chip.label))
	assert(contains(reply, "kitten"))
	assert(not contains(reply, "(re:"))
	assert(not contains(reply, "PlaceId"))
	assert(not contains(string.lower(reply), "robux"))
	assert(not contains(string.lower(reply), "invest"))
end

local context = {
	npc = NpcCatalog.get("OldTom"),
	playerName = "Cat",
	championName = "Bytekit",
	phase = "InProgress",
	scoreline = "Blue 1 – 1 Red",
}
for _, chip in chips do
	assert(MockAiProvider.complete(chip.question, context) == OldTomGuide.reply("OldTom", chip.question))
end
local chatter = MockAiProvider.complete("hello", context)
assert(contains(chatter, '(re: "hello")'), "Off-topic Old Tom still uses the mock chatter")
assert(not contains(chatter, "22 gold"))

local clerk = MockAiProvider.complete("camps", {
	npc = NpcCatalog.get("PawmartBlue"),
	playerName = "Cat",
	championName = nil,
	phase = "InProgress",
	scoreline = "",
})
assert(contains(clerk, "(re:"))
assert(not contains(clerk, "32-second appointment"))
local caster = MockAiProvider.complete("camps", {
	npc = NpcCatalog.get("KittyCaster"),
	playerName = "Cat",
	championName = "Bytekit",
	phase = "InProgress",
	scoreline = "Blue 0 – 0 Red",
})
assert(contains(caster, "(re:"))
assert(not contains(caster, "32-second appointment"))
local hostCloset = HostGuide.reply("HostMe", "closet")
assert(hostCloset and contains(hostCloset, "Lantern Cap"))
assert(not contains(hostCloset, "Pigeon Pack"))

assert(OldTomGuide.AmbientGap >= 60)
local spoken, spokenAt = OldTomGuide.ambient("OldTom", 100, 0, 0)
assert(spoken and contains(spoken, "kitten") and spokenAt == 100)
local blocked, blockedAt = OldTomGuide.ambient("OldTom", 120, spokenAt, 0)
assert(blocked == nil and blockedAt == spokenAt)
local missed, missedAt = OldTomGuide.ambient("OldTom", 200, 100, 1)
assert(missed == nil and missedAt == 200, "A failed roll still spends the gap")
local heard, heardAt = OldTomGuide.ambient("OldTom", 300, 200, 4)
assert(heard and heard ~= spoken and heardAt == 300)
local quiet, quietAt = OldTomGuide.ambient("KittyCaster", 300, 0, 0)
assert(quiet == nil and quietAt == 0)
local hostQuiet, hostAt = OldTomGuide.ambient("HostMeo", 300, 0, 0)
assert(hostQuiet == nil and hostAt == 0)
local seen = {}
for step = 0, 3 do
	local line = OldTomGuide.ambient("OldTom", 0, -100, step * 4)
	assert(line and contains(line, "kitten"))
	assert(not seen[line], "Ambient tips should not repeat in one cycle")
	seen[line] = true
end

local parent = Instance.new("Frame")
local chat = NpcChatPanel.create(parent)
local topics = chat.root:FindFirstChild("Topics")
local coachTopics = chat.root:FindFirstChild("CoachTopics")
local function lines()
	local rows = {}
	local log = chat.root:FindFirstChild("Log")
	for _, child in log.children do
		if child.Name == "Line" then table.insert(rows, child.Text) end
	end
	return rows
end
chat.open("OldTom", "Old Tom")
assert(lines()[1] == "Old Tom: " .. OldTomGuide.Greeting)
assert(coachTopics.Visible and not topics.Visible)
assert(chat.root:FindFirstChild("Input").PlaceholderText == "Camps, wards, fog, or route")
assert(chat.root:FindFirstChildWhichIsA("UISizeConstraint").MaxSize.Y == 332)
local sent = {}
local pending
chat.onSend(function(id, question, reply)
	assert(id == "OldTom")
	table.insert(sent, question)
	pending = reply
end)
chat.root:FindFirstChild("Input").Text = "keep this draft"
coachTopics:FindFirstChild("Wards").Activated:Fire()
assert(sent[1] == "wards" and chat.root:FindFirstChild("Input").Text == "keep this draft")
coachTopics:FindFirstChild("Route").Activated:Fire()
assert(#sent == 1, "A pending coach reply blocks the next chip")
pending("Old Tom", "Ready")
for _, chip in chips do
	local button = coachTopics:FindFirstChild(chip.id)
	assert(button and button.Text == chip.label and button.Size[2] == 44)
	if chip.id ~= "Wards" then
		button.Activated:Fire()
		assert(sent[#sent] == chip.question)
		pending("Old Tom", "Ready")
	end
end
topics:FindFirstChild("Help").Activated:Fire()
assert(#sent == 5, "Host chips do not send while Old Tom is open")

chat.open("HostMe", "ME")
assert(topics.Visible and not coachTopics.Visible)
assert(chat.root:FindFirstChildWhichIsA("UISizeConstraint").MaxSize.Y == 332)
local hostSent = 0
chat.onSend(function()
	hostSent += 1
end)
coachTopics:FindFirstChild("Help").Activated:Fire()
assert(hostSent == 0, "Jungle chips stay quiet on a host")

chat.open("KittyCaster", "Kitty Caster")
assert(not topics.Visible and not coachTopics.Visible)
assert(lines()[1] == "Kitty Caster: Mrrp. What is on your mind?")
assert(chat.root:FindFirstChildWhichIsA("UISizeConstraint").MaxSize.Y == 280)
chat.open("PawmartRed", "Pawmart Clerk")
assert(not topics.Visible and not coachTopics.Visible)
assert(lines()[1] == "Pawmart Clerk: Mrrp. What is on your mind?")

print("PASS: Old Tom camps, wards, fog, route, chips, ambient gap, and unchanged hosts")
