-- Run through tools/test-tutorial.py. Steps the Practice tip deck and the Show tips replay.
local parent = Instance.new("Frame")

local EXPECTED = {
	"Move & look",
	"Scratch (LMB)",
	"Abilities",
	"Three flagship kits",
	"Three more original kits",
	"Three expansion kits",
	"Three more expansion kits",
	"Last two expansion kits",
	"Purse & Pawmart",
	"Recall (F)",
	"Ward (4 / 6)",
	"Fog of war",
	"Posts, stalls, yarn core",
	"Death recap",
	"Caster & pings",
	"Party queue",
	"Closet & voice",
}

local function practice(id: string, done: boolean)
	return { id = id, phase = "InProgress", practice = true }, done
end

local function step(tips): ({ string }, { string })
	local titles = {}
	local bodies = {}
	local guard = 0
	while tips.isOpen() do
		guard += 1
		assert(guard < 30, "Tip deck has no end")
		local title = tips.root:FindFirstChild("Title")
		local body = tips.root:FindFirstChild("Body")
		local nextBtn = tips.root:FindFirstChild("Next")
		local kicker = tips.root:FindFirstChild("Kicker")
		assert(title and body and nextBtn and kicker)
		assert(string.find(kicker.Text, "Practice tip", 1, true), "Kicker should count the open deck")
		table.insert(titles, title.Text)
		table.insert(bodies, body.Text)
		local finishing = nextBtn.Text == "Got it"
		nextBtn.MouseButton1Click:Fire()
		if finishing then
			assert(not tips.isOpen(), "Got it closes the card")
			break
		else
			assert(tips.isOpen(), "Next stays on the card")
		end
	end
	return titles, bodies
end

local function assertDeck(titles: { string }, bodies: { string })
	assert(#titles == #EXPECTED, "Deck length changed")
	for index, title in EXPECTED do
		assert(titles[index] == title, "Unexpected tip: " .. tostring(titles[index]))
	end
	local joined = table.concat(bodies, "\n")
	assert(string.find(joined, "purse chip", 1, true))
	assert(string.find(joined, "Yarn Cleave", 1, true))
	assert(string.find(joined, "Stall Fang", 1, true))
	assert(string.find(joined, "Paper Charm", 1, true))
	assert(string.find(joined, "outer scratching post", 1, true))
	assert(string.find(joined, "lantern stall", 1, true))
	assert(string.find(joined, "yarn core", 1, true))
	assert(string.find(joined, "killing blow", 1, true))
	assert(string.find(joined, "Kitty Caster", 1, true))
	assert(string.find(joined, "Hold G", 1, true))
	assert(string.find(joined, "Invite", 1, true))
	assert(string.find(joined, "Queue party", 1, true))
	assert(string.find(joined, "Lantern Cap", 1, true))
	assert(string.find(joined, "Stall Spark", 1, true))
	assert(string.find(joined, "Mute me", 1, true))
	assert(not string.find(joined, "publish checklist", 1, true), "Live stays off the tip cards")
	assert(not string.find(string.lower(joined), "live panel", 1, true), "Live stays off the tip cards")
end

-- First Practice opens the deck. Next walks every card. Got it dismisses for good.
local first = TutorialTips.create(parent)
assert(first.root.Name == "TutorialTips")
assert(first.root.Active == true, "The card still takes its own clicks")
assert(first.root:FindFirstChild("Skip").Text == "Skip all")
assert(not first.isOpen())
local dismissed = nil
first.onDismissed(function(permanent: boolean)
	dismissed = permanent
end)
local snapshot, done = practice("practice-1", false)
first.sync(snapshot, 1, done)
assert(first.isOpen(), "First Practice should open tips")
assert(first.root.ZIndex == 26)
local titles, bodies = step(first)
assertDeck(titles, bodies)
assert(dismissed == true)
assert(first.isSkipped())
snapshot, done = practice("practice-2", true)
first.sync(snapshot, 1, done)
assert(not first.isOpen(), "Finished players are not force-reset")

-- Skip all also sticks until Show tips.
local skipped = TutorialTips.create(parent)
snapshot, done = practice("practice-3", false)
skipped.sync(snapshot, 1, done)
assert(skipped.isOpen())
local skipFlag = nil
skipped.onDismissed(function(permanent: boolean)
	skipFlag = permanent
end)
skipped.root:FindFirstChild("Skip").MouseButton1Click:Fire()
assert(skipFlag == true)
assert(skipped.isSkipped())
assert(not skipped.isOpen())
snapshot, done = practice("practice-4", false)
skipped.sync(snapshot, 1, done)
assert(not skipped.isOpen(), "Skip all stays dismissed inside this session")

-- Already done, including a live match and the other stalls, stays quiet.
local quiet = TutorialTips.create(parent)
snapshot, done = practice("practice-5", true)
quiet.sync(snapshot, 1, done)
assert(not quiet.isOpen())
quiet.sync({ id = "live", phase = "InProgress", practice = false }, 1, true)
assert(not quiet.isOpen(), "A live match does not start Practice tips")
quiet.sync({ id = "hub", phase = "Lobby", practice = false }, 1, true)
assert(not quiet.isOpen(), "Hub and other modes do not start the deck")
quiet.notifyTower()
quiet.tickContextual(true, 500, false)
assert(not quiet.isOpen(), "Finished players do not get the extra cards")

local live = TutorialTips.create(parent)
live.sync({ id = "ranked", phase = "InProgress", practice = false }, 1, false)
assert(not live.isOpen(), "A live match does not auto-start the Practice deck")

-- Lobby Show tips replays the current deck, including the new tail.
local lobby = LobbyPanel.create(parent)
local replay = TutorialTips.create(parent)
snapshot, done = practice("practice-6", true)
replay.sync(snapshot, 1, done)
assert(not replay.isOpen())
lobby.onShowTips(function()
	replay.replay()
end)
local show = lobby.root:FindFirstChild("ShowTips")
assert(show and show.Text == "Show tips")
show.MouseButton1Click:Fire()
assert(replay.isOpen(), "Show tips replays after a dismiss")
assert(replay.root:FindFirstChild("Title").Text == "Move & look")
local replayTitles, replayBodies = step(replay)
assertDeck(replayTitles, replayBodies)

-- Contextual reminders still exist for someone who has not finished.
local contextual = TutorialTips.create(parent)
contextual.notifyTower()
assert(contextual.isOpen())
assert(contextual.root:FindFirstChild("Title").Text == "Yarn core still gated")
local fountain = TutorialTips.create(parent)
fountain.tickContextual(true, 500, false)
assert(fountain.root:FindFirstChild("Title").Text == "Gold burning a hole")

-- Help mentions Live. The tip cards do not.
local help = HelpPanel.create(parent)
help.setContext("moba")
local tipHelp = nil
for _, row in help.root:FindFirstChild("Binds"):GetChildren() do
	if row.ClassName == "Frame" then
		local key = row:FindFirstChild("K")
		if key and key.Text == "Tips" then
			tipHelp = row:FindFirstChild("D").Text
		end
	end
end
assert(tipHelp, "Cat Rift help should keep a Tips row")
assert(string.find(tipHelp, "Live", 1, true))
assert(string.find(tipHelp, "Show tips", 1, true))
assert(string.find(tipHelp, "not a card", 1, true))

print("PASS: practice tip deck, dismiss persistence, and Show tips replay")
