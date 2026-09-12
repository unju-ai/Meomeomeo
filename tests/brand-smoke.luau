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

local lobby = LobbyPanel.create(parent)
assert(lobby.root:FindFirstChild("Title").Text == BrandCatalog.Name)
assert(lobby.root:FindFirstChild("Sub").Text == BrandCatalog.GameLine)
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
lobby.updateQueue({
	phase = "Teleporting", mode = "Reserved", inQueue = true, count = 6,
	needed = 6, estimatedSeconds = 0, party = { "Cat", "Friend" }, detail = "Joining match",
})
assert(lobby.root:FindFirstChild("Queue").Visible == false)
assert(lobby.root:FindFirstChild("Leave").Visible == false)
assert(lobby.root:FindFirstChild("Blurb").Text == "Joining match", "Live queue status must keep priority")
print("PASS: host dialogue, original roster/NPCs, safe substitutions, theme buttons, lobby copy and queue state")
