--!strict

-- Client-only keybind overlay. Toggle with ? or hold H. No remotes.
-- Tip cards / Show tips stay separate — this sheet is the reference card only.

local ChampionKits = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionKits"))
local ItemKits = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ItemKits"))
local Theme = require(script.Parent.Parent.Theme)

local HelpPanel = {}

export type HelpContext = "hub" | "moba" | "runner" | "koi" | "party" | "arcade"

export type HelpApi = {
	root: Frame,
	button: TextButton,
	setHeld: (held: boolean) -> (),
	toggle: () -> (),
	setVisible: (visible: boolean) -> (),
	setContext: (ctx: HelpContext) -> (),
	isOpen: () -> boolean,
}

-- Section sentinel: first field "#", second field is the section title.
local SEC = "#"

-- Cat Rift: Movement · Combat · Vision · Shop · Social · Objectives
local LINES_MOBA: { { string } } = {
	{ SEC, "Movement" },
	{ "X + click", "Attack-move (walk and auto-acquire)" },
	{ "S", "Stop attack · cancel recall orders" },
	{ "F", "Recall 7s. Move, ground click, AA, or cast cancels" },
	{ "V", "Toggle follow camera" },

	{ SEC, "Combat" },
	{ "LMB", "Lock auto-attack on enemy / minion / tower" },
	{ "Q W E R", "Hold line/dash, release bolt · ground: click or 2nd press · CD sweep / mint ready / coral mana" },
	{ "Esc / RMB", "Cancel armed ground or held aim" },
	{ "Death", "Recap of recent scratches · hides before fountain · Recap reopens" },

	{ SEC, "Vision" },
	{ "Fog", "Unseen dark · explored dim · walls block · brush hides · ghost fades at last seen · bolts vanish in fog" },
	{ "4", "Trinket ward (team tint, stealthed)" },
	{ "5", "Whisker Lens (buy at Pawmart first)" },
	{ "6", "Control Yarn / pink (buy, 2 charges). Visible · slow · true sight" },
	{ "G", "Ping wheel · names a visible cat, post, stall, ward, or camp" },
	{ "G fog", "Attention refuses a hidden cat" },
	{ "Minimap", "Fog click = Attention · post square, stall lantern" },

	{ SEC, "Shop" },
	{ "B", "Pawmart at fountain — not recall · Stats / Vision / Actives" },
	{ "Purse", "Gold, CS, level, and Yarn Cleave cost above the ability bar" },
	{ "Tape", "Meme prices under the kill feed. Play yarn, not gold or Closet" },

	{ SEC, "Social" },
	{ "T", "Hold emote wheel · release to cast · Esc cancel" },
	{ "Tab", "Hold scoreboard. Same gold and CS as the purse chip" },
	{ "F7", "Remake under 3:00. Majority of living humans. Practice, or a missing teammate. Bots never vote" },
	{ "F8", "Surrender after 8:00. Living humans, majority. Bots never vote" },
	{ "Mute", "Voice pill · Mute me (mic only) · teammates, not bots" },
	{ "Caster", "Kitty Caster: first blood, streaks, posts, stalls, core, Levi, win/lose" },
	{ "Invite", "Same-server Accept · leader queues" },
	{ "Party", "Leader + members, or solo · 20s" },
	{ "Talk", "Fountain / jungle cats · clerks / Old Tom / hosts" },
	{ "Tips", "Hub Live is the checklist, not a card · Show tips replays" },

	{ SEC, "Objectives" },
	{ "Posts", "Outer post → lantern stall → yarn core. Stalls gate per lane" },
	{ "Levi", "Clock: countdown → UP → return → taken. Last hit +8% damage" },
	{ "Clock", "Top-left match time + Canal Levi line" },
	{ "HP bars", "Posts, stalls, core, Levi, damaged/aimed kits & camps · fog hides enemy bars" },
	{ "Practice", "Solo + 2 Blue bots vs 3 Red · party caps Blue at 3" },
	{ "Closet", "Lantern Cap (post/stall) · Stall Spark (win) · Scratch Tally (5 kills)" },
	{ "Audio", "SFX + Music sliders · mute (top-right)" },
	{ "H / ?", "This help (hold H or click ?)" },
}

local function withKitRows(lines: { { string } }): { { string } }
	local out: { { string } } = {}
	for _, row in lines do
		table.insert(out, row)
		if row[1] == "Q W E R" then
			for _, kit in ChampionKits.helpRows() do
				table.insert(out, kit)
			end
		elseif row[1] == "6" then
			for _, item in ItemKits.helpRows() do
				table.insert(out, item)
			end
		end
	end
	return out
end

local LINES_HUB: { { string } } = {
	{ SEC, "Stalls" },
	{ "Click tile", "Cat Rift · Yarn Run · Koi Pond · Yarn Party · Meme Arcade" },
	{ "Live", "Publish checklist · not a gate · PLAYTEST §7" },
	{ "Board", "Yarn daily/weekly · Koi/Arcade dailies (UTC)" },
	{ "Mint 404", "Hub chrome — same Meo404 panel" },

	{ SEC, "Closet" },
	{ "Closet", "Hats + trails · yarn points, not Robux" },
	{ "Unlocks", "Run / Koi / Party / Arcade / Rift drip · Gold Bell 25 yarn" },

	{ SEC, "Social" },
	{ "T", "Hold emote wheel on the hub pad · Esc cancel" },
	{ "Voice", "Quiet until a match · Mute me is the mic" },
	{ "Audio", "SFX + Music · Hide my name → Anonymous Cat" },
	{ "H / ?", "This help (hold H or click ?)" },
}

local LINES_RUNNER: { { string } } = {
	{ SEC, "Movement" },
	{ "A / D", "Switch lane (also arrows)" },
	{ "Space", "Jump a dog / Roomba gap" },
	{ "C / Ctrl", "Slide under laundry / tunnel" },

	{ SEC, "Run" },
	{ "Pickups", "SPD burst · MAG yarn · SHD hit · 2X score" },
	{ "Ghost", "Translucent PB cat + gold PB gate (persists)" },
	{ "Death", "Slow-mo · PB compare · daily / weekly rank · podium · Retry same seed" },

	{ SEC, "Closet" },
	{ "Closet", "Coral Beanie 200m · Mint Aura 400m (best distance)" },

	{ SEC, "Social" },
	{ "T", "Emote mid-dash (stream juice)" },
	{ "Voice", "Hub rules · not a team channel" },
	{ "Audio", "SFX + Music sliders · mute" },
	{ "H / ?", "This help" },
}

local LINES_KOI: { { string } } = {
	{ SEC, "Cast" },
	{ "Space / Click", "Cast the yarn bobber (Idle)" },
	{ "Space / Click", "Reel when the loaf hits the cream window" },
	{ "Wait", "Don't yank early — patience, loaf" },
	{ "Nibble", "Bobber NIBBLE! + cream rail flash when it bites" },

	{ SEC, "Catch" },
	{ "Rarities", "Cream · Peach · Mint · Cobalt · Amber · Coral Crown" },
	{ "Stall log", "Session collection + best catch / PB / daily board" },
	{ "Hub", "Back to hub · Daily board for today's catches" },

	{ SEC, "Closet" },
	{ "Closet", "Canal Crown + emote flair from a legendary koi" },

	{ SEC, "Social" },
	{ "T", "Emote on the dock" },
	{ "Voice", "Hub rules · not a team channel" },
	{ "Audio", "SFX + Music sliders · mute" },
	{ "H / ?", "This help" },
}

local LINES_PARTY: { { string } } = {
	{ SEC, "Movement" },
	{ "WASD", "Run around the night-market courtyard" },
	{ "Space", "Hop the coral yarn (Yarn Dodge)" },
	{ "Pillows", "When lanterns blink, stand on a lit stall pillow" },

	{ SEC, "Lobby" },
	{ "Rounds", "3 micro-rounds: Dodge · Stall Freeze · Dodge" },
	{ "Lobby", "Seats 1–4 count down, then the rounds" },
	{ "Join", "A friend takes a bot seat before GO" },
	{ "Late", "Mid-round Play waits for the next party" },
	{ "Bots", "LoafBot, NibBot, PurrBot hold empty seats" },
	{ "Leave", "Back to hub frees your seat in lobby" },
	{ "Hub", "Back to hub (clean exit)" },

	{ SEC, "Closet" },
	{ "Closet", "Party Tiara + Moon Dust on a human win (not a bot)" },

	{ SEC, "Social" },
	{ "T", "Emote mid-party" },
	{ "Voice", "Hub rules · not a team channel" },
	{ "Audio", "SFX + Music sliders · mute" },
	{ "H / ?", "This help" },
}

local LINES_ARCADE: { { string } } = {
	{ SEC, "Tape" },
	{ "1–5", "Buy 1 bag of that ticker (LOAF NYAN CHNK BRAIN RUG)" },
	{ "Shift+1–5", "Sell 1 bag at the listed yarn price" },
	{ "Tap", "Buy / Sell on the stall cards" },
	{ "Round", "28s tape · auto-sell at the bell · daily profit board" },
	{ "Events", "TO THE MOON · RUG PULL · WHALE SNEEZE" },
	{ "Yarn only", "Play yarn / points — not real money" },
	{ "Hub", "Back to hub · Board for today's yarn profit" },

	{ SEC, "Closet" },
	{ "Closet", "Tape Shades +15 · Braincell Orbs +25 daily profit" },

	{ SEC, "Social" },
	{ "T", "Emote at the counter" },
	{ "Voice", "Hub rules · not a team channel" },
	{ "Audio", "SFX + Music sliders · mute" },
	{ "H / ?", "This help" },
}

function HelpPanel.create(parent: Instance): HelpApi
	local pinned = false
	local held = false

	local button = Theme.button(parent, "HelpButton", "?", Theme.mint)
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -80, 0, 96)
	button.Size = UDim2.fromOffset(40, 40)
	button.TextSize = 20
	button.ZIndex = 30

	local root = Instance.new("Frame")
	root.Name = "HelpPanel"
	root.AnchorPoint = Vector2.new(0, 0.5)
	root.Position = UDim2.new(0, 16, 0.48, 0)
	root.Size = UDim2.fromOffset(340, 530)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.ZIndex = 28
	root.Parent = parent
	Theme.corner(root, 18)
	Theme.stroke(root, Theme.mint, 2, 0.18)
	Theme.pad(root, 12)

	local title = Theme.text(root, "Title", "Controls", 20, Theme.mint, Theme.fontTitle)
	title.Size = UDim2.new(1, -28, 0, 24)

	local close = Theme.button(root, "Close", "✕", Theme.coral)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(28, 28)
	close.TextSize = 14

	local sub = Theme.text(root, "Sub", "Hold H or click ?  ·  PLAYTEST.md", 11, Theme.peach)
	sub.Position = UDim2.fromOffset(0, 26)
	sub.Size = UDim2.new(1, 0, 0, 16)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Binds"
	list.BackgroundColor3 = Theme.panelAlt
	list.Position = UDim2.fromOffset(0, 48)
	list.Size = UDim2.new(1, 0, 1, -48)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = root
	Theme.corner(list, 10)
	Theme.pad(list, 8)
	Theme.list(list, 4)

	local function paintLines(lines: { { string } })
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for i, pair in lines do
			if pair[1] == SEC then
				local header = Instance.new("Frame")
				header.Name = `Section{i}`
				header.BackgroundColor3 = Theme.ink
				header.BackgroundTransparency = 0.35
				header.Size = UDim2.new(1, -4, 0, 20)
				header.LayoutOrder = i
				header.Parent = list
				Theme.corner(header, 6)
				Theme.stroke(header, Theme.mint, 1, 0.5)

				local label = Theme.text(header, "K", string.upper(pair[2]), 11, Theme.mint, Theme.fontMono)
				label.Position = UDim2.fromOffset(8, 0)
				label.Size = UDim2.new(1, -12, 1, 0)
				label.TextWrapped = false
			else
				local tall = pair[1] == "F8" or pair[1] == "F7"
				local rowH = if tall then 36 else 22
				local row = Instance.new("Frame")
				row.Name = `Bind{i}`
				row.BackgroundTransparency = 1
				row.Size = UDim2.new(1, -4, 0, rowH)
				row.LayoutOrder = i
				row.Parent = list

				local key = Theme.text(row, "K", pair[1], 12, Theme.amber, Theme.fontMono)
				key.Size = UDim2.fromOffset(88, rowH)
				key.TextWrapped = false

				local desc = Theme.text(row, "D", pair[2], 12, Theme.cream)
				desc.Position = UDim2.fromOffset(92, 0)
				desc.Size = UDim2.new(1, -92, 0, rowH)
				desc.TextWrapped = tall
				desc.TextTruncate = Enum.TextTruncate.AtEnd
			end
		end
	end
	paintLines(LINES_HUB)

	local function paint()
		root.Visible = pinned or held
		button.BackgroundColor3 = if root.Visible then Theme.good else Theme.mint
	end

	local function setPinned(on: boolean)
		pinned = on
		paint()
	end

	button.MouseButton1Click:Connect(function()
		setPinned(not pinned)
	end)
	close.MouseButton1Click:Connect(function()
		setPinned(false)
	end)

	paint()

	return {
		root = root,
		button = button,
		setHeld = function(on: boolean)
			held = on
			paint()
		end,
		toggle = function()
			setPinned(not pinned)
		end,
		setVisible = function(visible: boolean)
			setPinned(visible)
		end,
		setContext = function(ctx: HelpContext)
			if ctx == "runner" then
				title.Text = "Yarn Run"
				sub.Text = "Daily seed dash · chase your ghost"
				paintLines(LINES_RUNNER)
			elseif ctx == "koi" then
				title.Text = "Koi Pond"
				sub.Text = "Cast · cream window · cat-koi"
				paintLines(LINES_KOI)
			elseif ctx == "party" then
				title.Text = "Yarn Party"
				sub.Text = "Seats 1–4 · countdown · then three rounds"
				paintLines(LINES_PARTY)
			elseif ctx == "arcade" then
				title.Text = "Meme Arcade"
				sub.Text = "Play yarn only · tap the tape"
				paintLines(LINES_ARCADE)
			elseif ctx == "moba" then
				title.Text = "Cat Rift"
				sub.Text = "Hold H or click ?  ·  PLAYTEST.md"
				paintLines(withKitRows(LINES_MOBA))
			else
				title.Text = "Hub"
				sub.Text = "Pick a stall  ·  PLAYTEST.md"
				paintLines(LINES_HUB)
			end
		end,
		isOpen = function()
			return pinned or held
		end,
	}
end

return HelpPanel
