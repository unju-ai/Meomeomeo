--!strict

-- Non-modal first-match tips. Play continues underneath. Help (H/?) is separate.

local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local TutorialTips = {}

export type TipsApi = {
	root: Frame,
	isOpen: () -> boolean,
	isSkipped: () -> boolean,
	replay: () -> (),
	sync: (snapshot: Types.MatchSnapshot, localUserId: number, alreadyDone: boolean) -> (),
	notifyTower: () -> (),
	tickContextual: (atFountain: boolean, gold: number, shopOpen: boolean) -> (),
	onDismissed: ((permanent: boolean) -> ()) -> (),
}

type Tip = {
	title: string,
	body: string,
	id: string,
}

local SEQUENCE: { Tip } = {
	{
		id = "move",
		title = "Move & look",
		body = "WASD to walk. V locks a simple overhead camera. You can play with the default camera too.",
	},
	{
		id = "aa",
		title = "Scratch (LMB)",
		body = "Left-click an enemy cat, kitten, or tower to lock an auto-attack. X then click is attack-move. S stops.",
	},
	{
		id = "qwer",
		title = "Abilities",
		body = "Q W E R. Hold a line skillshot or dash to see the path, then release to fire. Instant kits fire on press.",
	},
	{
		id = "shop",
		title = "Pawmart (B)",
		body = "B opens the shop — only at your fountain. Spend match gold on claws and yarn. B is not recall.",
	},
	{
		id = "recall",
		title = "Recall (F)",
		body = "F channels 7s back to fountain. Damage, moving too far, attacks, or S / F again cancel it.",
	},
	{
		id = "ward",
		title = "Ward (4)",
		body = "4 drops a free trinket ward (one live, 70s cooldown). Team-only vision. 5 is Whisker Lens after you buy it.",
	},
	{
		id = "tab",
		title = "Scoreboard (Tab)",
		body = "Hold Tab for KDA, CS, gold, and items. Bots are tagged (Bot).",
	},
	{
		id = "nexus",
		title = "Towers, then nexus",
		body = "Scratch all 3 enemy towers until the nexus billboard says (OPEN). A gated nexus will not take damage.",
	},
}

local SHOP_TIP: Tip = {
	id = "shopNow",
	title = "Gold burning a hole",
	body = "You're at fountain with gold. Press B for Pawmart — Longclaw and Mana Treat are cheap first buys.",
}

local GATE_TIP: Tip = {
	id = "gateNow",
	title = "Nexus still gated",
	body = "A tower is down. The nexus stays invulnerable until all 3 towers on that side fall. Keep pushing the other lanes.",
}

function TutorialTips.create(parent: Instance): TipsApi
	local root = Instance.new("Frame")
	root.Name = "TutorialTips"
	root.AnchorPoint = Vector2.new(0, 0)
	root.Position = UDim2.new(0, 16, 0, 72)
	root.Size = UDim2.fromOffset(348, 148)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.ZIndex = 26
	root.Active = true
	root.Parent = parent
	Theme.corner(root, 16)
	Theme.stroke(root, Theme.coral, 2, 0.2)
	Theme.pad(root, 12)

	local kicker = Theme.text(root, "Kicker", "Practice tip  1 / 8", 11, Theme.coral, Theme.fontMono)
	kicker.Size = UDim2.new(1, -8, 0, 16)

	local title = Theme.text(root, "Title", "", 18, Theme.cream, Theme.fontTitle)
	title.Position = UDim2.fromOffset(0, 18)
	title.Size = UDim2.new(1, 0, 0, 22)

	local body = Theme.text(root, "Body", "", 13, Theme.peach)
	body.Position = UDim2.fromOffset(0, 42)
	body.Size = UDim2.new(1, 0, 0, 52)

	local nextBtn = Theme.button(root, "Next", "Next", Theme.cream)
	nextBtn.Position = UDim2.new(0, 0, 1, -36)
	nextBtn.Size = UDim2.new(0.56, -4, 0, 34)
	nextBtn.TextSize = 15
	nextBtn.ZIndex = 27

	local skipBtn = Theme.button(root, "Skip", "Skip all", Theme.coral)
	skipBtn.Position = UDim2.new(0.56, 4, 1, -36)
	skipBtn.Size = UDim2.new(0.44, -4, 0, 34)
	skipBtn.TextSize = 15
	skipBtn.ZIndex = 27

	local index = 1
	local queue: { Tip } = {}
	local open = false
	local skipped = false
	local persistDone = false
	local dismissedHow: "none" | "skip" | "complete" = "none"
	local startedMatchId: string? = nil
	local shownIds: { [string]: boolean } = {}
	local shopHinted = false
	local gateHinted = false
	local dismissHandler: ((boolean) -> ())? = nil

	local function paint()
		local tip = queue[index]
		if not tip then
			root.Visible = false
			open = false
			return
		end
		open = true
		root.Visible = true
		local total = #queue
		kicker.Text = `Practice tip  {index} / {total}`
		title.Text = tip.title
		body.Text = tip.body
		nextBtn.Text = if index >= total then "Got it" else "Next"
	end

	local function finish(permanent: boolean, how: "skip" | "complete")
		root.Visible = false
		open = false
		queue = {}
		if permanent then
			skipped = true
			dismissedHow = how
		end
		if dismissHandler then
			dismissHandler(permanent)
		end
	end

	local function enqueue(tip: Tip)
		if shownIds[tip.id] then
			return
		end
		shownIds[tip.id] = true
		table.insert(queue, tip)
		if not open then
			index = #queue
		end
		paint()
	end

	local function startSequence()
		skipped = false
		dismissedHow = "none"
		shopHinted = false
		gateHinted = false
		shownIds = {}
		queue = table.clone(SEQUENCE)
		for _, tip in queue do
			shownIds[tip.id] = true
		end
		index = 1
		paint()
	end

	nextBtn.MouseButton1Click:Connect(function()
		if index < #queue then
			index += 1
			paint()
			return
		end
		finish(true, "complete")
	end)
	skipBtn.MouseButton1Click:Connect(function()
		finish(true, "skip")
	end)

	return {
		root = root,
		isOpen = function()
			return open
		end,
		isSkipped = function()
			return skipped
		end,
		replay = function()
			dismissedHow = "none"
			skipped = false
			startSequence()
		end,
		sync = function(snapshot: Types.MatchSnapshot, _localUserId: number, alreadyDone: boolean)
			persistDone = alreadyDone
			if snapshot.phase == "Lobby" then
				if not open then
					startedMatchId = nil
				end
				return
			end
			if snapshot.phase ~= "InProgress" then
				if snapshot.phase == "Ended" or snapshot.phase == "ChampionSelect" then
					if open and snapshot.phase == "Ended" then
						root.Visible = false
						open = false
					end
				end
				return
			end
			if not snapshot.practice then
				return
			end
			if alreadyDone or skipped then
				startedMatchId = snapshot.id
				return
			end
			if startedMatchId == snapshot.id then
				return
			end
			startedMatchId = snapshot.id
			startSequence()
		end,
		notifyTower = function()
			if persistDone and dismissedHow ~= "skip" then
				return
			end
			if gateHinted then
				return
			end
			gateHinted = true
			enqueue(GATE_TIP)
		end,
		tickContextual = function(atFountain: boolean, gold: number, shopOpen: boolean)
			if persistDone and dismissedHow ~= "skip" then
				return
			end
			if shopHinted or shopOpen or not atFountain or gold < 200 then
				return
			end
			if open then
				return
			end
			shopHinted = true
			enqueue(SHOP_TIP)
		end,
		onDismissed = function(fn)
			dismissHandler = fn
		end,
	}
end

return TutorialTips
