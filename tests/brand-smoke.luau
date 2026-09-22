-- Run through tools/test-brand.py; modules are loaded from their real source files.
local hosts = BrandCatalog.hosts()
assert(#hosts == 3, "Expected the three channel hosts")
assert(#ChampionCatalog.all() == 14, "The existing champion roster must stay intact")
assert(#NpcCatalog.all() == 7, "Four original NPCs plus three hosts")
for _, id in { "PawmartBlue", "PawmartRed", "OldTom", "KittyCaster" } do
	assert(NpcCatalog.get(id) ~= nil, "Original NPC missing")
end
for _, host in hosts do
	assert(BrandCatalog.host(host.id) == host)
	assert(ChampionCatalog.get(host.id) == nil, "A host must not become a champion")
	local npc = NpcCatalog.get(host.id)
	assert(npc and npc.name == host.name and npc.team == nil)
	local seen = {}
	for length = 1, 9 do
		local result = MockAiProvider.complete(string.rep("x", length), {
			npc = npc,
			playerName = "100% Cat",
			championName = "Professor Whiskers",
			phase = "Lobby",
			scoreline = "Blue 0 - 0 Red",
		})
		assert(not string.find(result, "{", 1, true), "Unexpanded dialogue placeholder")
		assert(not string.find(result, "(re:", 1, true), "Hosts must not echo input")
		seen[result] = true
	end
	local count = 0
	for _ in seen do count += 1 end
	assert(count == #host.lines, "All authored host lines should be reachable")
end
assert(BrandCatalog.host("missing") == nil)
local ordinary = MockAiProvider.complete("hello", {
	npc = NpcCatalog.get("OldTom"), playerName = "Cat", championName = nil,
	phase = "Lobby", scoreline = "Blue 0 - 0 Red",
})
assert(string.find(ordinary, '(re: "hello")', 1, true), "Existing NPC behavior changed")

-- Color and helper used to share the key `stroke`, making every button fail.
assert(type(Theme.stroke) == "function")
assert(Theme.strokeColor._kind == "Color3")
local parent = Instance.new("Frame")
local button = Theme.button(parent, "Smoke", "Play", Theme.amber)
local stroke = button:FindFirstChildWhichIsA("UIStroke")
assert(stroke and stroke.Color == Theme.strokeColor, "Button border must receive a color")

local hub = HubPanel.create(parent)
assert(hub.root:FindFirstChild("Title").Text == BrandCatalog.Name)
assert(string.find(hub.root:FindFirstChild("Sub").Text, BrandCatalog.Tagline, 1, true), "Hub must keep channel tagline")
local yarnCard = hub.root:FindFirstChild("Grid") and hub.root:FindFirstChild("Grid"):FindFirstChild("YarnRun")
assert(yarnCard and yarnCard:FindFirstChild("Board") ~= nil, "Yarn Run tile must expose the daily board")
assert(hub.onBoard ~= nil and hub.updateBoard ~= nil)
local koiCard = hub.root:FindFirstChild("Grid") and hub.root:FindFirstChild("Grid"):FindFirstChild("KoiPond")
assert(koiCard, "Koi Pond tile must exist")
assert(koiCard:FindFirstChild("Play") and koiCard:FindFirstChild("Play").Text == "Play", "Koi Pond must be playable")
assert(koiCard:FindFirstChild("Board") ~= nil, "Koi Pond tile must expose the daily board")
assert(koiCard:FindFirstChild("Tag") and koiCard:FindFirstChild("Tag").Text == "POND")
assert(hub.onPlayPond ~= nil, "Hub must start Koi Pond")
assert(hub.onKoiBoard ~= nil and hub.updateKoiBoard ~= nil, "Hub must open the Koi daily board")
local pond = ModeCatalog.get("KoiPond")
assert(pond and pond.playable == true and pond.tag == "POND")
assert(ModeCatalog.stallTag(pond) == "POND" and ModeCatalog.playLabel(pond) == "Play")
assert(ModeCatalog.oneLine(pond) == pond.blurb and string.find(pond.blurb, "Canal mint", 1, true))
assert(pond.wash and pond.glow and ModeCatalog.glowAccent(pond) == pond.glow)
local partyCard = hub.root:FindFirstChild("Grid") and hub.root:FindFirstChild("Grid"):FindFirstChild("YarnParty")
assert(partyCard, "Yarn Party tile must exist")
assert(partyCard:FindFirstChild("Play") and partyCard:FindFirstChild("Play").Text == "Play", "Yarn Party must be playable")
assert(partyCard:FindFirstChild("Tag") and partyCard:FindFirstChild("Tag").Text == "PARTY")
assert(partyCard:FindFirstChild("Blurb") and string.find(partyCard:FindFirstChild("Blurb").Text, "Four seats", 1, true))
assert(partyCard:FindFirstChild("Bob") ~= nil, "Stall tiles keep a soft bob scale")
assert(hub.onPlayParty ~= nil, "Hub must start Yarn Party")
local bash = ModeCatalog.get("YarnParty")
assert(bash and bash.playable == true and bash.tag == "PARTY")
assert(ModeCatalog.stallTag(bash) == "PARTY" and ModeCatalog.playLabel(bash) == "Play")
local arcadeCard = hub.root:FindFirstChild("Grid") and hub.root:FindFirstChild("Grid"):FindFirstChild("MemeArcade")
assert(arcadeCard, "Meme Arcade tile must exist")
assert(arcadeCard:FindFirstChild("Play") and arcadeCard:FindFirstChild("Play").Text == "Play", "Meme Arcade must be playable")
assert(arcadeCard:FindFirstChild("Board") ~= nil, "Meme Arcade tile must expose the daily board")
assert(arcadeCard:FindFirstChild("Tag") and arcadeCard:FindFirstChild("Tag").Text == "TAPE")
assert(arcadeCard:FindFirstChild("Blurb") and string.find(arcadeCard:FindFirstChild("Blurb").Text, "Neon tape", 1, true))
assert(hub.onPlayArcade ~= nil, "Hub must start Meme Arcade")
assert(hub.onArcadeBoard ~= nil and hub.updateArcadeBoard ~= nil, "Hub must open the Arcade daily board")
assert(hub.root:FindFirstChild("Closet") ~= nil, "Hub chrome must expose Closet")
assert(hub.onCloset ~= nil, "Hub must open the closet")
assert(hub.root:FindFirstChild("Live") ~= nil and hub.root:FindFirstChild("Live").Text == "Live", "Hub must expose the publish checklist")
assert(hub.onLive ~= nil and hub.applyPublish ~= nil and hub.dismissPublish ~= nil)
local tape = ModeCatalog.get("MemeArcade")
assert(tape and tape.playable == true and tape.tag == "TAPE")
assert(ModeCatalog.stallTag(tape) == "TAPE" and string.find(ModeCatalog.oneLine(tape), "Neon", 1, true))
local rift = ModeCatalog.get("CatRift")
local run = ModeCatalog.get("YarnRun")
assert(rift and run and rift.playable and run.playable)
assert(string.find(ModeCatalog.oneLine(rift), "Three lanes", 1, true))
assert(string.find(ModeCatalog.oneLine(run), "Coral yarn", 1, true))
assert(ModeCatalog.playLabel({ playable = false, tag = "X", title = "X", blurb = "X", id = "CatRift", swatch = rift.swatch, accent = rift.accent, wash = rift.wash, glow = rift.glow, art = "rift" }) == "Soon")
assert(#ModeCatalog.all() == 5, "All five hub tiles must be live")
local yarnTile = hub.root:FindFirstChild("Grid"):FindFirstChild("YarnRun")
assert(yarnTile:FindFirstChild("Tag").Text == ModeCatalog.stallTag(run))
assert(string.find(yarnTile:FindFirstChild("Blurb").Text, "Coral yarn", 1, true))
assert(yarnTile.BackgroundColor3 == run.wash, "Stall wash is night-market tinted")

local lobby = LobbyPanel.create(parent)
assert(lobby.root:FindFirstChild("Title").Text == "CAT RIFT")
assert(lobby.root:FindFirstChild("Sub").Text == BrandCatalog.GameLine)
assert(lobby.root:FindFirstChild("BackHub") ~= nil, "Cat Rift stall must return to the hub")
assert(lobby.onBack ~= nil, "Latest hub back-navigation must survive the merge")
assert(lobby.root:FindFirstChild("Closet") ~= nil, "Cat Rift stall must expose Closet")
assert(lobby.onCloset ~= nil, "Cat Rift stall must open the closet")
lobby.setQueued(true)
assert(lobby.root:FindFirstChild("Leave").Visible == true)
assert(lobby.root:FindFirstChild("Queue").Visible == false)
lobby.setQueued(false)
assert(lobby.root:FindFirstChild("Queue").Visible == true)
assert(lobby.difficulty() == "Normal")
lobby.setDifficulty("Hard")
assert(lobby.difficulty() == "Hard", "Latest Hard difficulty must survive the merge")
assert(lobby.root:FindFirstChild("Practice").Text == "Practice vs 3 bots (Hard)")
assert(lobby.root:FindFirstChild("ShowTips") ~= nil, "Latest tutorial entry must survive")
assert(lobby.root:FindFirstChild("Invite") ~= nil, "Latest party entry must survive")
assert(lobby.root:FindFirstChild("Party").Text == "Party · solo")
assert(lobby.root:FindFirstChild("LeaveParty").Visible == false)
local card = lobby.root:FindFirstChild("InviteCard")
assert(card and card.Visible == false, "Invite prompt stays hidden until someone invites you")
assert(card:FindFirstChild("AcceptInvite") and card:FindFirstChild("DeclineInvite"))
lobby.updateQueue({
	phase = "Teleporting", mode = "Reserved", inQueue = true, count = 6,
	needed = 6, estimatedSeconds = 0, party = { "Cat", "Friend" }, detail = "Joining match",
})
assert(lobby.root:FindFirstChild("Queue").Visible == false)
assert(lobby.root:FindFirstChild("Leave").Visible == false)
assert(lobby.root:FindFirstChild("Blurb").Text == "Joining match", "Live queue status must keep priority")
lobby.setPeers({ { userId = 4, name = "Sam" }, { userId = 5, name = "Mo" } })
assert(lobby.root:FindFirstChild("Invite").Text == "Invite Sam")
assert(lobby.root:FindFirstChild("NextCat").Visible == true)
lobby.root:FindFirstChild("NextCat").MouseButton1Click:Fire()
assert(lobby.root:FindFirstChild("Invite").Text == "Invite Mo")
lobby.updateQueue({
	phase = "Idle", mode = "InPlace", inQueue = false, count = 0,
	needed = 2, estimatedSeconds = 0, party = { "You (leader)", "Sam" },
	partyRole = "leader", partyMemberIds = { 1, 4 }, detail = "Need 2",
	incomingInvite = { fromUserId = 9, fromName = "Mo", expiresIn = 12 },
})
assert(lobby.root:FindFirstChild("Party").Text == "Party · You (leader) · Sam")
assert(card.Visible == true)
assert(card:FindFirstChild("InviteStatus").Text == "Mo invited you · 12s")
assert(lobby.root:FindFirstChild("Queue").Visible == true)
assert(lobby.root:FindFirstChild("Queue").Text == "Queue party")
assert(lobby.root:FindFirstChild("Practice").Text == "Practice with party (Hard)")
assert(lobby.root:FindFirstChild("LeaveParty").Visible == true)
assert(lobby.root:FindFirstChild("Invite").Text == "Invite Mo")
lobby.updateQueue({
	phase = "Idle", mode = "InPlace", inQueue = false, count = 0,
	needed = 2, estimatedSeconds = 0, party = {}, partyRole = "solo", detail = "solo again",
})
assert(lobby.root:FindFirstChild("Party").Text == "Party · solo")
assert(card.Visible == false)
assert(lobby.root:FindFirstChild("LeaveParty").Visible == false)
assert(lobby.root:FindFirstChild("Practice").Text == "Practice vs 3 bots (Hard)")
lobby.updateQueue({
	phase = "Found", mode = "InPlace", inQueue = true, count = 2,
	needed = 2, estimatedSeconds = 0, party = { "Cat" },
	detail = "Match found — starting draft in-place.",
})
assert(lobby.root:FindFirstChild("Eta").Text == "MATCH FOUND  ·  in-place", "Match found stays in-place when MatchPlaceId is unset")
assert(string.find(lobby.root:FindFirstChild("Blurb").Text, "in-place", 1, true), "Match found blurb must say in-place")
print("PASS: host dialogue, original roster/NPCs, safe substitutions, theme buttons, lobby copy and queue state")

-- A yielded NPC request must never leak into a newly opened conversation.
local chat = NpcChatPanel.create(parent)
local log = chat.root:FindFirstChild("Log")
local function chatLines()
	local rows = {}
	for _, child in log.children do
		if child.Name == "Line" then table.insert(rows, child.Text) end
	end
	return rows
end
local pending
chat.onSend(function(_, _, reply) pending = reply end)
chat.open("HostMeo", "MEO")
assert(chatLines()[1] == "MEO: " .. BrandCatalog.host("HostMeo").greeting)
chat.root:FindFirstChild("Input").Text = "hello"
chat.root:FindFirstChild("Send").MouseButton1Click:Fire()
assert(#chatLines() == 2)
local oldReply = pending
chat.open("HostMo", "MO")
oldReply("MEO", "late reply")
assert(#chatLines() == 1, "Previous host reply leaked into new chat")
assert(chatLines()[1] == "MO: " .. BrandCatalog.host("HostMo").greeting)
chat.root:FindFirstChild("Input").Text = "mrrp"
chat.root:FindFirstChild("Input").FocusLost:Fire(true)
pending("MO", "received")
assert(chatLines()[3] == "MO: received")
chat.close()
pending("MO", "after close")
assert(#chatLines() == 3)
chat.open("HostMo", "MO")
pending("MO", "after reopen")
assert(#chatLines() == 1, "Same-host reopen must invalidate old requests")
chat.open("OldTom", "Old Tom")
assert(chatLines()[1] == "Old Tom: " .. OldTomGuide.Greeting)
for i = 1, 100 do chat.append("Cat", tostring(i)) end
assert(#chatLines() == 60, "Transcript must remain bounded")
assert(chatLines()[60] == "Cat: 100")
print("PASS: authored greetings, separate conversations, late replies, close/reopen and transcript cap")

local castHub = HubPanel.create(parent)
local cast = castHub.root:FindFirstChild("Grid"):FindFirstChild("MeetTheCats")
assert(cast ~= nil, "Trio must be reachable from the hub")
local selectedId, selectedName
castHub.onTalk(function(id, name) selectedId, selectedName = id, name end)
for _, host in BrandCatalog.hosts() do
	local portrait = cast:FindFirstChild(host.id)
	assert(portrait.BackgroundColor3 == host.color)
	assert(portrait:FindFirstChild("Braincell").BackgroundColor3 == BrandCatalog.BraincellColor)
	portrait.MouseButton1Click:Fire()
	assert(selectedId == host.id and selectedName == host.name)
end
assert(#ModeCatalog.all() == 5, "Hosts are not an extra game mode")
print("PASS: hub host entry points and shared portrait identity")

local responsiveGrid = castHub.root:FindFirstChild("Grid")
local gridLayout = responsiveGrid:FindFirstChildWhichIsA("UIGridLayout")
assert(responsiveGrid.ClassName == "ScrollingFrame")
assert(responsiveGrid.AutomaticCanvasSize == Enum.AutomaticSize.Y)
for _, example in {{780, 3}, {600, 2}, {351, 1}} do
	castHub.root.AbsoluteSize = {X = example[1], Y = 560}
	castHub.root.Changed:Fire()
	assert(gridLayout.CellSize[1] == 1 / example[2], "Wrong responsive column count")
	local cellWidth = (example[1] - 36) * gridLayout.CellSize[1] + gridLayout.CellSize[2]
	assert(cellWidth >= 200, "Cards became too narrow to read")
end
assert(castHub.root:FindFirstChild("Closet").Position[4] == 76)
assert(castHub.root:FindFirstChild("Live").Position[2] == 76, "Narrow hub keeps Live beside Closet")
assert(castHub.root:FindFirstChild("Title").Size[2] == 0)
castHub.root.AbsoluteSize = {X = 300, Y = 560}
castHub.root.Changed:Fire()
assert(castHub.root:FindFirstChild("Closet").Position[4] == 76, "Very narrow hub must not move Closet")
assert(castHub.root:FindFirstChild("Live").Position[2] == 40, "Very narrow hub parks Live on the tagline row")
assert(cast.LayoutOrder == 6, "Trio must stay after the game tiles")
local riftCard = responsiveGrid:FindFirstChild("CatRift")
assert(riftCard and riftCard:FindFirstChild("Bob"))
local riftStroke = riftCard:FindFirstChildWhichIsA("UIStroke")
assert(riftStroke and riftStroke.Thickness == 2)
riftCard.MouseEnter:Fire()
assert(riftStroke.Thickness == 3, "Hover thickens the stall stroke")
assert(riftCard:FindFirstChild("Bob").Scale == 1.03, "Hover lifts the stall")
riftCard.MouseLeave:Fire()
assert(riftStroke.Thickness == 2, "Leave restores the stall stroke")
print("PASS: hub columns, narrow header and scrollable cast access")

chat.open("HostMe", "ME")
local sends = 0
chat.onSend(function(_, text, reply)
	sends += 1
	assert(text == "hello", "Input should be trimmed")
	pending = reply
end)
local input = chat.root:FindFirstChild("Input")
local send = chat.root:FindFirstChild("Send")
input.Text = "   "
send.MouseButton1Click:Fire()
assert(sends == 0 and input.Text == "   ")
input.Text = "  hello  "
send.MouseButton1Click:Fire()
assert(sends == 1 and send.Text == "…" and not send.Active)
input.Text = "hello"
send.MouseButton1Click:Fire()
assert(sends == 1 and input.Text == "hello", "Keep draft while request is pending")
pending("ME", "received")
assert(send.Active and send.Text == "Send")
local layout = log:FindFirstChildWhichIsA("UIListLayout")
log.AbsoluteCanvasSize = {Y = 600}
log.AbsoluteWindowSize = {Y = 150}
layout.AbsoluteContentSize = {Y = 584}
layout.Changed:Fire()
assert(log.CanvasPosition.Y == 450, "Follow new messages at bottom")
log.CanvasPosition = Vector2.new(0, 30)
log.Changed:Fire()
layout.AbsoluteContentSize = {Y = 684}
layout.Changed:Fire()
assert(log.CanvasPosition.Y == 30, "Do not interrupt reading older messages")
local previous = 0
for _, row in log.children do
	if row.Name == "Line" then
		assert(row.LayoutOrder > previous)
		previous = row.LayoutOrder
	end
end
assert(chat.root.Size[1] == 1 and chat.root.Size[2] == -32)
assert(chat.root:FindFirstChildWhichIsA("UISizeConstraint").MaxSize.X == 340)
print("PASS: chat sizing, pending requests, whitespace, transcript order and scroll follow")

for _, host in BrandCatalog.hosts() do
	for _, mode in ModeCatalog.all() do
		local reply = HostGuide.reply(host.id, "Tell me about " .. string.upper(mode.title) .. "?")
		assert(reply and string.find(reply, mode.title, 1, true))
		assert(string.find(reply, "Play button", 1, true))
		local context = {npc = NpcCatalog.get(host.id), playerName = "Cat", phase = "Lobby", scoreline = ""}
		assert(MockAiProvider.complete(mode.title, context) == reply)
	end
	local help = HostGuide.reply(host.id, "help")
	for _, mode in ModeCatalog.all() do assert(string.find(help, mode.title, 1, true)) end
	assert(HostGuide.reply(host.id, "rift or koi?") == help)
	assert(HostGuide.reply(host.id, "party") ~= HostGuide.reply(host.id, "koi"))
	assert(HostGuide.reply(host.id, "YARN-RUN") == HostGuide.reply(host.id, "yarn run"))
	assert(HostGuide.reply(host.id, "drifting apart yearly") == nil)
	assert(string.find(HostGuide.reply(host.id, "arcade"), "play yarn, not real money", 1, true))
end
assert(HostGuide.reply("OldTom", "help") == nil)
assert(HostGuide.reply("HostMo", "hello") == nil)
local phrases = {
	{ "closet", "Lantern Cap" },
	{ "lantern cap", "outer post" },
	{ "stall spark", "win a Cat Rift" },
	{ "drip", "not Robux" },
	{ "fog", "last-seen ghost" },
	{ "last seen", "not vision" },
	{ "ghosts", "Yarn Run personal-best" },
	{ "invite", "Accept" },
	{ "party queue", "Queue party" },
	{ "queue party", "same server" },
	{ "pawmart", "280 gold" },
	{ "yarn cleave", "press 7" },
	{ "stall fang", "20% HP" },
	{ "paper charm", "2.4 seconds" },
	{ "kitty caster", "first blood" },
	{ "first blood", "no API key" },
	{ "smart ping", "Hold G" },
	{ "ping", "refuses a hidden cat" },
	{ "death recap", "2.5 seconds" },
	{ "killing blow", "Recap brings it back" },
	{ "purse", "does not add CS" },
	{ "cs", "purse chip" },
	{ "mute me", "not SFX" },
	{ "voice", "Bots are silent" },
	{ "meme tape", "not the Meme Arcade" },
	{ "fight tape", "spends Robux" },
}
local meoCloset = HostGuide.reply("HostMeo", "closet")
local meCloset = HostGuide.reply("HostMe", "closet")
local moCloset = HostGuide.reply("HostMo", "closet")
assert(meoCloset ~= meCloset and meCloset ~= moCloset and moCloset ~= meoCloset, "Host asides should stay distinct")
for _, host in BrandCatalog.hosts() do
	local help = HostGuide.reply(host.id, "help")
	for _, phrase in phrases do
		local reply = HostGuide.reply(host.id, phrase[1])
		assert(reply and string.find(reply, phrase[2], 1, true), phrase[1] .. " missing " .. phrase[2])
		assert(not string.find(reply, "nil", 1, true), "Missing aside")
		assert(not string.find(reply, "PlaceId", 1, true), "Hosts must not invent a PlaceId")
		assert(not string.find(string.lower(reply), "invest", 1, true), "Hosts must not give investment advice")
		local context = { npc = NpcCatalog.get(host.id), playerName = "Cat", phase = "Lobby", scoreline = "" }
		assert(MockAiProvider.complete(phrase[1], context) == reply)
	end
	assert(string.find(HostGuide.reply(host.id, "party"), "Play button", 1, true))
	assert(not string.find(HostGuide.reply(host.id, "party queue"), "Play button", 1, true), "Party queue is not the Yarn Party stall")
	assert(HostGuide.reply(host.id, "yarn run ghost") == help, "Name one ghost at a time")
	assert(HostGuide.reply(host.id, "closet and fog") == help)
	assert(not string.find(HostGuide.reply(host.id, "arcade"), "kill feed", 1, true))
	assert(not string.find(HostGuide.reply(host.id, "meme tape"), "Play button", 1, true))
	for _, chip in HostGuide.chips() do
		assert(HostGuide.reply(host.id, chip.question) == HostGuide.reply(host.id, chip.label))
	end
end
local spoken, spokenAt = HostGuide.ambient("HostMeo", 100, 0, 0)
assert(spoken and spokenAt == 100, "A rare approach can mutter")
assert(not string.find(spoken, "PlaceId", 1, true))
local blocked, blockedAt = HostGuide.ambient("HostMe", 120, spokenAt, 0)
assert(blocked == nil and blockedAt == spokenAt, "Nearby hosts share one gap")
local missed, missedAt = HostGuide.ambient("HostMo", 200, 100, 1)
assert(missed == nil and missedAt == 200, "A failed roll still spends the gap")
local heard, heardAt = HostGuide.ambient("HostMo", 300, 200, 3)
assert(heard and heardAt == 300 and heard ~= spoken)
local quiet, quietAt = HostGuide.ambient("OldTom", 300, 0, 0)
assert(quiet == nil and quietAt == 0, "Ordinary NPCs do not mutter")
local meoLine = HostGuide.ambient("HostMeo", 0, -100, 0)
local meLine = HostGuide.ambient("HostMe", 0, -100, 0)
local moLine = HostGuide.ambient("HostMo", 0, -100, 0)
assert(meoLine ~= meLine and meLine ~= moLine)
local meoOther = HostGuide.ambient("HostMeo", 0, -100, 3)
assert(meoOther ~= meoLine, "The same host has more than one idle line")
print("PASS: all host/game answers, menu, aliases, word boundaries and ordinary NPC fallback")
print("PASS: closet, fog, invite, shop, caster, ping, recap, purse, voice, tape, and idle lines")

chat.open("HostMeo", "MEO")
local topics = chat.root:FindFirstChild("Topics")
local coachTopics = chat.root:FindFirstChild("CoachTopics")
assert(topics.Visible and topics.AutomaticCanvasSize == Enum.AutomaticSize.X)
assert(coachTopics and not coachTopics.Visible, "Host talk does not show jungle chips")
local questions = {}
chat.onSend(function(id, question, reply)
	assert(id == "HostMeo")
	table.insert(questions, question)
	pending = reply
end)
input.Text = "my unfinished thought"
local chips = HostGuide.chips()
assert(#chips == 6, "Host talk keeps a short chip row")
topics:FindFirstChild("Help").Activated:Fire()
assert(questions[1] == "help" and input.Text == "my unfinished thought")
topics:FindFirstChild("CatRift").Activated:Fire()
assert(#questions == 1, "Quick topics must respect pending requests")
pending("MEO", "Ready")
for _, chip in chips do
	local button = topics:FindFirstChild(chip.id)
	assert(button and button.Text == chip.label)
	if chip.id ~= "Help" then
		button.Activated:Fire()
		assert(questions[#questions] == chip.question)
		assert(HostGuide.reply("HostMeo", chip.question) ~= nil)
		pending("MEO", "Ready")
	end
end
assert(#questions == 6 and input.Text == "my unfinished thought")
chat.open("OldTom", "Old Tom")
assert(not topics.Visible)
assert(coachTopics.Visible, "Old Tom keeps his own chips")
topics:FindFirstChild("Help").Activated:Fire()
assert(#questions == 6, "Host chips stay quiet on Old Tom")
assert(chat.root:FindFirstChildWhichIsA("UISizeConstraint").MaxSize.Y == 332)
chat.onSend(function(id, question, reply)
	assert(id == "OldTom")
	table.insert(questions, question)
	pending = reply
end)
input.Text = "my unfinished thought"
coachTopics:FindFirstChild("Camps").Activated:Fire()
assert(questions[7] == "camps" and input.Text == "my unfinished thought")
pending("Old Tom", "Ready")
chat.open("PawmartBlue", "Pawmart Clerk")
local shopTopics = chat.root:FindFirstChild("ShopTopics")
assert(not topics.Visible and not coachTopics.Visible)
assert(shopTopics and shopTopics.Visible, "Clerks keep shop chips")
assert(chat.root:FindFirstChildWhichIsA("UISizeConstraint").MaxSize.Y == 332)
assert(chatLines()[1] == "Pawmart Clerk: " .. (PawmartGuide.greeting("PawmartBlue") :: string))
print("PASS: tappable host topics, Old Tom chips, clerk chips, draft preservation and pending guard")

local function checklistRow(report, id)
	for _, row in report.rows do
		if row.id == id then
			return row
		end
	end
	return nil
end
local function assertNoPlaceId(text, where)
	assert(not string.find(text, "%d%d%d%d"), where .. " must not invent a numeric id")
end

local solo = PublishChecklist.report(PublishChecklist.studioSoloFacts())
assert(solo.informational == true, "Readiness is not a hard gate")
assert(#solo.rows == 6, "Checklist stays the six publish rows")
assert(solo.summary == "Ready 2 · Still Studio stub 4 · Blocked 0")
local soloMatch = checklistRow(solo, "MatchPlace")
local soloLobby = checklistRow(solo, "LobbyPlace")
local soloProduct = checklistRow(solo, "DeveloperProduct")
local soloVoice = checklistRow(solo, "VoiceService")
local soloStore = checklistRow(solo, "DataStore")
local soloEconomy = checklistRow(solo, "Economy")
assert(soloMatch.status == "Stub" and soloMatch.statusLabel == "Still Studio stub")
assert(string.find(soloMatch.fix, "Reserved teleport needs a published PlaceId", 1, true))
assert(string.find(soloMatch.fix, "Config.Match.MatchPlaceId", 1, true))
assert(string.find(soloMatch.fix, "PLAYTEST", 1, true))
assert(soloLobby.status == "Stub" and string.find(soloLobby.fix, "Config.Match.LobbyPlaceId", 1, true))
assert(soloProduct.status == "Stub" and string.find(soloProduct.fix, "Config.Nft404.DeveloperProductId", 1, true))
assert(soloVoice.status == "Ready" and soloVoice.statusLabel == "Ready")
assert(soloStore.status == "Stub" and soloStore.statusLabel == "Still Studio stub")
assert(soloEconomy.status == "Ready" and string.find(soloEconomy.fix, "Config.Economy.Enabled", 1, true))
for _, row in solo.rows do
	assertNoPlaceId(row.fix, row.id)
	assertNoPlaceId(row.label, row.id)
	assert(string.find(row.fix, "PLAYTEST", 1, true), row.id .. " fix must point at PLAYTEST")
end

local liveFacts = {
	matchPlaceSet = true,
	lobbyPlaceSet = true,
	developerProductSet = true,
	voiceServicePresent = true,
	dataStoreReachable = true,
	economyEnabled = true,
}
local live = PublishChecklist.report(liveFacts)
assert(live.summary == "Ready 6 · Still Studio stub 0 · Blocked 0")
assert(live.informational == true)
for _, row in live.rows do
	assert(row.status == "Ready" and row.statusLabel == "Ready")
	assertNoPlaceId(row.fix, "live " .. row.id)
end

local blockedFacts = {
	matchPlaceSet = false,
	lobbyPlaceSet = false,
	developerProductSet = false,
	voiceServicePresent = false,
	dataStoreReachable = false,
	economyEnabled = false,
}
local blocked = PublishChecklist.report(blockedFacts)
assert(checklistRow(blocked, "MatchPlace").status == "Stub", "A zero PlaceId is a stub, not a gate")
assert(checklistRow(blocked, "VoiceService").status == "Blocked")
assert(checklistRow(blocked, "VoiceService").statusLabel == "Blocked")
assert(string.find(checklistRow(blocked, "VoiceService").fix, "VoiceChatService", 1, true))
assert(checklistRow(blocked, "DataStore").status == "Stub")
assert(checklistRow(blocked, "Economy").status == "Blocked")
assert(string.find(checklistRow(blocked, "Economy").fix, "Config.Economy.Enabled", 1, true))
assert(blocked.summary == "Ready 0 · Still Studio stub 4 · Blocked 2")
print("PASS: publish checklist stubs, ready rows, and blocked voice or economy")

local panel = hub.root:FindFirstChild("PublishPanel")
assert(panel and panel.Visible == false, "Live panel starts closed")
local opened = false
hub.onLive(function()
	opened = true
end)
hub.root:FindFirstChild("Live").MouseButton1Click:Fire()
assert(panel.Visible == true and opened, "Live opens the checklist and asks the server")
assert(panel:FindFirstChild("Summary").Text == "Reading the server checklist…")
hub.applyPublish(solo)
local rows = panel:FindFirstChild("Rows")
local matchRow = rows:FindFirstChild("MatchPlace")
assert(matchRow:FindFirstChild("Status").Text == "Still Studio stub")
assert(string.find(matchRow:FindFirstChild("Fix").Text, "Reserved teleport needs a published PlaceId", 1, true))
assertNoPlaceId(matchRow:FindFirstChild("Fix").Text, "panel match fix")
assert(rows:FindFirstChild("VoiceService"):FindFirstChild("Status").Text == "Ready")
assert(rows:FindFirstChild("DataStore"):FindFirstChild("Status").Text == "Still Studio stub")
assert(rows:FindFirstChild("Economy"):FindFirstChild("Status").Text == "Ready")
assert(string.find(panel:FindFirstChild("Summary").Text, "Still Studio stub 4", 1, true))
hub.applyPublish({
	summary = "Place 12345678",
	rows = {
		{
			id = "MatchPlace",
			label = "Match place",
			status = "Stub",
			statusLabel = "Still Studio stub",
			fix = "Do not show 87654321. Set Config.Match.MatchPlaceId. See PLAYTEST §7.",
		},
	},
})
assert(not string.find(panel:FindFirstChild("Summary").Text, "12345678", 1, true), "Summary must scrub a numeric id")
assert(string.find(panel:FindFirstChild("Summary").Text, "…", 1, true))
local scrubbed = rows:FindFirstChild("MatchPlace"):FindFirstChild("Fix").Text
assert(not string.find(scrubbed, "87654321", 1, true), "Fix line must scrub a numeric id")
assert(string.find(scrubbed, "Config.Match.MatchPlaceId", 1, true))
panel:FindFirstChild("Close").MouseButton1Click:Fire()
assert(panel.Visible == false)
hub.showPublishError("Could not read the server checklist. Play is not blocked. See PLAYTEST §7.")
assert(rows:FindFirstChild("Error"):FindFirstChild("Status").Text == "Blocked")
hub.dismissPublish()
assert(panel.Visible == false)
hub.root:FindFirstChild("Live").MouseButton1Click:Fire()
assert(panel.Visible == true)
hub.setVisible(false)
assert(panel.Visible == false, "Leaving the hub closes the checklist")
print("PASS: hub Live panel, studio stub rows, and id scrub")
