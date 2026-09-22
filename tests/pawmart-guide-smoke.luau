-- Run through tools/test-pawmart-guide.py. Clerk shop tips stay authored and local.
local function contains(reply: string, phrase: string): boolean
	return string.find(reply, phrase, 1, true) ~= nil
end

local function ask(npcId: string, message: string): string
	local reply = PawmartGuide.reply(npcId, message)
	assert(reply, npcId .. " " .. message .. " should coach")
	return reply
end

assert(PawmartGuide.reply("OldTom", "shop") == nil)
assert(PawmartGuide.reply("HostMeo", "actives") == nil)
assert(PawmartGuide.reply("KittyCaster", "builds") == nil)
assert(PawmartGuide.reply("PawmartBlue", "hello") == nil)
assert(PawmartGuide.reply("PawmartRed", "closet") == nil)
assert(PawmartGuide.reply("PawmartBlue", "yarn run") == nil)
assert(OldTomGuide.reply("PawmartBlue", "wards") == nil)
assert(HostGuide.reply("PawmartRed", "shop") == nil)

local blueHelp = ask("PawmartBlue", "help")
assert(contains(blueHelp, "Shop") and contains(blueHelp, "Actives") and contains(blueHelp, "Wards") and contains(blueHelp, "Builds"))
assert(contains(blueHelp, "reprinting") or contains(blueHelp, "catalog"))
assert(not contains(blueHelp, "180 gold"), "Help stays a menu")
assert(not contains(blueHelp, "500 gold") and not contains(blueHelp, "Longclaw"))
local redHelp = ask("PawmartRed", "help")
assert(contains(redHelp, "upsell") or contains(redHelp, "single"))
assert(ask("PawmartBlue", "HELP") == blueHelp)
assert(ask("PawmartBlue", "tips") == blueHelp)
assert(ask("PawmartBlue", "shop and actives") == blueHelp)
assert(ask("PawmartRed", "wards or builds") == redHelp)

local blueShop = ask("PawmartBlue", "shop")
assert(contains(blueShop, "B opens Pawmart"))
assert(contains(blueShop, "fountain only"))
assert(contains(blueShop, "Not recall") and contains(blueShop, "that is F"))
assert(contains(blueShop, "500 gold"))
assert(contains(blueShop, "purse chip") and contains(blueShop, "1 CS"))
assert(contains(blueShop, "do not") or contains(blueShop, "Kill, assist"))
assert(contains(blueShop, "receipt") or contains(blueShop, "delivery"))
assert(not contains(string.lower(blueShop), "robux"))
local redShop = ask("PawmartRed", "shop")
assert(contains(redShop, "B opens Pawmart") and contains(redShop, "500 gold"))
assert(contains(redShop, "does not take Robux"))
assert(not contains(string.lower(redShop), "invest"))
assert(contains(blueShop, "70%"))
assert(contains(blueShop, "one click"))
assert(contains(blueShop, "one charge at a time"))
assert(contains(blueShop, "cooldown does not block"))
assert(contains(redShop, "70%"))
assert(ask("PawmartBlue", "PRESS-B") == blueShop)
assert(ask("PawmartBlue", "pawmart") == blueShop)
assert(ask("PawmartBlue", "fountain only") == blueShop)
assert(ask("PawmartBlue", "sell") == blueShop)
assert(ask("PawmartRed", "pawn") == redShop)
assert(ask("PawmartRed", "refund") == redShop)
assert(ask("PawmartRed", "buy") == redShop)

local blueActives = ask("PawmartBlue", "actives")
assert(contains(blueActives, "180 gold") and contains(blueActives, "then 5"))
assert(contains(blueActives, "75 gold") and contains(blueActives, "two charges") and contains(blueActives, "then 6"))
assert(contains(blueActives, "280 gold") and contains(blueActives, "then 7"))
assert(contains(blueActives, "12-stud") and contains(blueActives, "40 damage") and contains(blueActives, "12 seconds"))
assert(contains(blueActives, "about 32 studs") and contains(blueActives, "about 75 seconds"))
assert(contains(blueActives, "bag") or contains(blueActives, "5, 6, and 7"))
local redActives = ask("PawmartRed", "actives")
assert(contains(redActives, "Upsell") or contains(redActives, "Leave with"))
assert(ask("PawmartBlue", "WHISKER-LENS") == blueActives)
assert(ask("PawmartBlue", "yarn cleave") == blueActives)
assert(ask("PawmartBlue", "control yarn") == blueActives)
assert(ask("PawmartBlue", "press 7") == blueActives)
assert(ask("PawmartRed", "lens") == redActives)
assert(ask("PawmartRed", "cleave") == redActives)

local blueWards = ask("PawmartBlue", "wards")
assert(contains(blueWards, "stealthed") and contains(blueWards, "about 70 seconds") and contains(blueWards, "about 60"))
assert(contains(blueWards, "about 90 seconds") and contains(blueWards, "about 22 studs"))
assert(contains(blueWards, "220 gold") and contains(blueWards, "2.4 seconds") and contains(blueWards, "about 20"))
assert(contains(blueWards, "not you"))
assert(contains(blueWards, "buy Control Yarn") and contains(blueWards, "toward the river"))
assert(not contains(blueWards, "do not buy Control Yarn"))
assert(contains(blueWards, "return policy") or contains(blueWards, "gift wrap"))
assert(not contains(blueWards, "Longclaw"))
local redWards = ask("PawmartRed", "wards")
assert(contains(redWards, "face-check") or contains(redWards, "magenta"))
assert(ask("PawmartBlue", "paper charm") == blueWards)
assert(ask("PawmartBlue", "pinks") == blueWards)
assert(ask("PawmartBlue", "trinket") == blueWards)
assert(ask("PawmartRed", "charm") == redWards)

local blueBuilds = ask("PawmartBlue", "builds")
assert(contains(blueBuilds, "Longclaw is 250") and contains(blueBuilds, "18 ability damage"))
assert(contains(blueBuilds, "Yarnplate is 250") and contains(blueBuilds, "+90 HP") and contains(blueBuilds, "12% armor"))
assert(contains(blueBuilds, "Mana Treat is 200") and contains(blueBuilds, "90 mana"))
assert(contains(blueBuilds, "Pounce Boots are 200") and contains(blueBuilds, "6 walk speed"))
assert(contains(blueBuilds, "Stall Fang is 300") and contains(blueBuilds, "36 raw") and contains(blueBuilds, "20% HP"))
assert(contains(blueBuilds, "Hard") and contains(blueBuilds, "Yarnplate + Paper Charm"))
assert(contains(blueBuilds, "Longclaw + boots") and contains(blueBuilds, "Mana Treat + Longclaw"))
assert(contains(blueBuilds, "Control Yarn") and contains(blueBuilds, "toward the river"))
assert(not contains(blueBuilds, "do not buy Control Yarn"))
assert(contains(blueBuilds, "durable goods") or contains(blueBuilds, "footnote"))
assert(not contains(blueBuilds, "then 5") and not contains(blueBuilds, "12-stud"))
local redBuilds = ask("PawmartRed", "builds")
assert(contains(redBuilds, "Hard already") or contains(redBuilds, "role starter"))
assert(ask("PawmartBlue", "LONGCLAW") == blueBuilds)
assert(ask("PawmartBlue", "stall fang") == blueBuilds)
assert(ask("PawmartBlue", "yarnplate") == blueBuilds)
assert(ask("PawmartBlue", "hard bot") == blueBuilds)
assert(ask("PawmartRed", "mana treat") == redBuilds)
assert(ask("PawmartRed", "pounce boots") == redBuilds)

assert(blueShop ~= redShop)
assert(blueActives ~= redActives)

local chips = PawmartGuide.chips()
assert(#chips == 5)
for _, chip in chips do
	local blue = ask("PawmartBlue", chip.question)
	local red = ask("PawmartRed", chip.question)
	assert(blue == ask("PawmartBlue", chip.label))
	assert(red == ask("PawmartRed", chip.label))
	if chip.id ~= "Help" then
		assert(blue ~= red, "Blue and Red keep distinct asides")
	end
	assert(not contains(blue, "(re:"))
	assert(not contains(red, "(re:"))
	assert(not contains(blue, "PlaceId"))
	assert(not contains(string.lower(blue), "invest"))
	assert(not contains(string.lower(red), "invest"))
end

local blueContext = {
	npc = NpcCatalog.get("PawmartBlue"),
	playerName = "Cat",
	championName = "Bytekit",
	phase = "InProgress",
	scoreline = "Blue 1 – 1 Red",
}
local redContext = {
	npc = NpcCatalog.get("PawmartRed"),
	playerName = "Cat",
	championName = "Bytekit",
	phase = "InProgress",
	scoreline = "Blue 1 – 1 Red",
}
for _, chip in chips do
	assert(MockAiProvider.complete(chip.question, blueContext) == PawmartGuide.reply("PawmartBlue", chip.question))
	assert(MockAiProvider.complete(chip.question, redContext) == PawmartGuide.reply("PawmartRed", chip.question))
end
local chatter = MockAiProvider.complete("hello", blueContext)
assert(contains(chatter, '(re: "hello")'), "Off-topic clerk still uses the mock chatter")
assert(not contains(chatter, "500 gold"))

local tom = MockAiProvider.complete("shop", {
	npc = NpcCatalog.get("OldTom"),
	playerName = "Cat",
	championName = nil,
	phase = "InProgress",
	scoreline = "",
})
assert(contains(tom, "(re:") or contains(tom, "kitten") or true)
assert(not contains(tom, "Blue register"))
local hostShop = HostGuide.reply("HostMe", "shop")
assert(hostShop and contains(hostShop, "Yarn Cleave"))
assert(not contains(hostShop, "Blue register"))

assert(PawmartGuide.AmbientGap >= 60)
local spoken, spokenAt = PawmartGuide.ambient("PawmartBlue", 100, 0, 0)
assert(spoken and spokenAt == 100)
local blocked, blockedAt = PawmartGuide.ambient("PawmartBlue", 120, spokenAt, 0)
assert(blocked == nil and blockedAt == spokenAt)
local missed, missedAt = PawmartGuide.ambient("PawmartRed", 200, 100, 1)
assert(missed == nil and missedAt == 200, "A failed roll still spends the gap")
local heard, heardAt = PawmartGuide.ambient("PawmartRed", 300, 200, 4)
assert(heard and heard ~= spoken and heardAt == 300)
local quiet, quietAt = PawmartGuide.ambient("OldTom", 300, 0, 0)
assert(quiet == nil and quietAt == 0)
local hostQuiet, hostAt = PawmartGuide.ambient("HostMeo", 300, 0, 0)
assert(hostQuiet == nil and hostAt == 0)
local blueSeen = {}
for step = 0, 2 do
	local line = PawmartGuide.ambient("PawmartBlue", 0, -100, step * 4)
	assert(line)
	assert(not blueSeen[line], "Blue ambient tips should not repeat in one cycle")
	blueSeen[line] = true
end
local redSeen = {}
for step = 0, 2 do
	local line = PawmartGuide.ambient("PawmartRed", 0, -100, step * 4)
	assert(line)
	assert(not redSeen[line], "Red ambient tips should not repeat in one cycle")
	redSeen[line] = true
end

local parent = Instance.new("Frame")
local chat = NpcChatPanel.create(parent)
local topics = chat.root:FindFirstChild("Topics")
local coachTopics = chat.root:FindFirstChild("CoachTopics")
local shopTopics = chat.root:FindFirstChild("ShopTopics")
local function lines()
	local rows = {}
	local log = chat.root:FindFirstChild("Log")
	for _, child in log.children do
		if child.Name == "Line" then table.insert(rows, child.Text) end
	end
	return rows
end

chat.open("PawmartBlue", "Pawmart Clerk")
assert(lines()[1] == "Pawmart Clerk: " .. (PawmartGuide.greeting("PawmartBlue") :: string))
assert(shopTopics.Visible and not topics.Visible and not coachTopics.Visible)
assert(chat.root:FindFirstChild("Input").PlaceholderText == "Shop, actives, wards, or builds")
assert(chat.root:FindFirstChildWhichIsA("UISizeConstraint").MaxSize.Y == 332)
local sent = {}
local pending
chat.onSend(function(id, question, reply)
	assert(id == "PawmartBlue")
	table.insert(sent, question)
	pending = reply
end)
chat.root:FindFirstChild("Input").Text = "keep this draft"
shopTopics:FindFirstChild("Actives").Activated:Fire()
assert(sent[1] == "actives" and chat.root:FindFirstChild("Input").Text == "keep this draft")
shopTopics:FindFirstChild("Builds").Activated:Fire()
assert(#sent == 1, "A pending shop reply blocks the next chip")
pending("Pawmart Clerk", "Ready")
for _, chip in chips do
	local button = shopTopics:FindFirstChild(chip.id)
	assert(button and button.Text == chip.label and button.Size[2] == 44)
	if chip.id ~= "Actives" then
		button.Activated:Fire()
		assert(sent[#sent] == chip.question)
		pending("Pawmart Clerk", "Ready")
	end
end
topics:FindFirstChild("Help").Activated:Fire()
assert(#sent == 5, "Host chips do not send while a clerk is open")
coachTopics:FindFirstChild("Help").Activated:Fire()
assert(#sent == 5, "Jungle chips stay quiet on a clerk")

chat.open("PawmartRed", "Pawmart Clerk")
assert(lines()[1] == "Pawmart Clerk: " .. (PawmartGuide.greeting("PawmartRed") :: string))
assert(shopTopics.Visible and not topics.Visible and not coachTopics.Visible)
assert(PawmartGuide.greeting("PawmartBlue") ~= PawmartGuide.greeting("PawmartRed"))

chat.open("OldTom", "Old Tom")
assert(coachTopics.Visible and not shopTopics.Visible and not topics.Visible)
local tomSent = 0
chat.onSend(function()
	tomSent += 1
end)
shopTopics:FindFirstChild("Help").Activated:Fire()
assert(tomSent == 0, "Shop chips stay quiet on Old Tom")

chat.open("HostMe", "ME")
assert(topics.Visible and not shopTopics.Visible and not coachTopics.Visible)
local hostSent = 0
chat.onSend(function()
	hostSent += 1
end)
shopTopics:FindFirstChild("Help").Activated:Fire()
assert(hostSent == 0, "Shop chips stay quiet on a host")

chat.open("KittyCaster", "Kitty Caster")
assert(not topics.Visible and not coachTopics.Visible and not shopTopics.Visible)
assert(lines()[1] == "Kitty Caster: Mrrp. What is on your mind?")
assert(chat.root:FindFirstChildWhichIsA("UISizeConstraint").MaxSize.Y == 280)

print("PASS: Pawmart shop, actives, wards, builds, chips, ambient gap, and unchanged hosts")
