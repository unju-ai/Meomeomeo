--!strict

-- Client-only keybind overlay. Toggle with ? or hold H. No remotes.

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

local LINES_MOBA: { { string } } = {
	{ "LMB", "Lock auto-attack on an enemy / minion / tower" },
	{ "Towers", "Outer post, then lantern stall, then yarn core. Stalls gate per lane" },
	{ "X + click", "Attack-move (walk and auto-acquire)" },
	{ "S", "Stop attack · cancel recall orders" },
	{ "Q W E R", "Hold line/dash, release traveling bolt · ground: click or 2nd press" },
	{ "Esc / RMB", "Cancel armed line or ground aim" },
	{ "4", "Trinket ward (team tint, stealthed)" },
	{ "5", "Whisker Lens (buy at Pawmart first)" },
	{ "6", "Control Yarn / pink (buy, 2 charges). Visible · slow · true sight" },
	{ "Fog", "Unseen ground is dark. Explored stays dim. Walls and thick cover block sight; thin props do not. Brush hides until entered. A ghost fades at the last spot you saw an enemy. Bolts vanish in fog" },
	{ "B", "Pawmart at fountain — not recall" },
	{ "F", "Recall 7s. A new move, ground click, attack, or cast cancels" },
	{ "T", "Hold emote wheel · release or click" },
	{ "G", "Ping wheel · names a visible cat, post, stall, ward, or camp" },
	{ "G fog", "Attention refuses a hidden cat" },
	{ "Purse", "Gold, CS, level, and Yarn Cleave cost sit above the ability bar" },
	{ "Tape", "Meme prices under the kill feed. Play yarn, not gold or Closet" },
	{ "Tab", "Hold scoreboard. Same gold and CS as the purse chip" },
	{ "Death", "Recap of recent scratches · hides before fountain · Recap reopens" },
	{ "V", "Toggle follow camera" },
	{ "Voice", "Pill · Mute me (mic only) · teammates, not bots" },
	{ "Audio", "SFX + Music sliders · mute (top-right)" },
	{ "H / ?", "This help (hold H or click ?)" },
	{ "Minimap", "Fog click = Attention · post square, stall lantern" },
	{ "Talk", "Fountain / jungle cats" },
	{ "Practice", "Solo vs 3 bots · party shares Blue" },
	{ "Invite", "Same-server Accept · leader queues" },
	{ "Party", "Leader + members, or solo · 20s" },
	{ "Tips", "Hub Live is the checklist, not a card · Show tips replays" },
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
	{ "Click tile", "Cat Rift · Yarn Run · Koi Pond · Yarn Party · Meme Arcade" },
	{ "Live", "Publish checklist · not a gate · PLAYTEST §7" },
	{ "Board", "Yarn daily/weekly · Koi/Arcade dailies (UTC)" },
	{ "Mint 404", "Hub chrome — same Meo404 panel" },
	{ "Closet", "Hats + trails · Rift unlocks · yarn points, not Robux" },
	{ "T", "Hold emote wheel on the hub pad" },
	{ "Voice", "Quiet until a match · Mute me is the mic" },
	{ "Audio", "SFX + Music · Hide my name → Anonymous Cat" },
	{ "H / ?", "This help (hold H or click ?)" },
}

local LINES_RUNNER: { { string } } = {
	{ "A / D", "Switch lane (also arrows)" },
	{ "Space", "Jump a dog / Roomba gap" },
	{ "C / Ctrl", "Slide under laundry / tunnel" },
	{ "Pickups", "SPD burst · MAG yarn · SHD hit · 2X score" },
	{ "Ghost", "Translucent PB cat + gold PB gate (persists)" },
	{ "T", "Emote mid-dash (stream juice)" },
	{ "Voice", "Hub rules · not a team channel" },
	{ "Audio", "SFX + Music sliders · mute" },
	{ "H / ?", "This help" },
	{ "Death", "Slow-mo cam · daily / weekly rank · podium · Retry same seed" },
}

local LINES_KOI: { { string } } = {
	{ "Space / Click", "Cast the yarn bobber (Idle)" },
	{ "Space / Click", "Reel when the loaf hits the cream window" },
	{ "Wait", "Don't yank early — patience, loaf" },
	{ "Rarities", "Cream · Peach · Mint · Cobalt · Amber · Coral Crown" },
	{ "Stall log", "Session collection + best catch / PB / daily board" },
	{ "T", "Emote on the dock" },
	{ "Voice", "Hub rules · not a team channel" },
	{ "Audio", "SFX + Music sliders · mute" },
	{ "H / ?", "This help" },
	{ "Hub", "Back to hub · Board for today's catches" },
}

local LINES_PARTY: { { string } } = {
	{ "WASD", "Run around the night-market courtyard" },
	{ "Space", "Hop the coral yarn (Yarn Dodge)" },
	{ "Pillows", "When lanterns blink, stand on a lit stall pillow" },
	{ "Rounds", "3 micro-rounds: Dodge · Stall Freeze · Dodge" },
	{ "Lobby", "Seats 1–4 count down, then the rounds" },
	{ "Join", "A friend takes a bot seat before GO" },
	{ "Late", "Mid-round Play waits for the next party" },
	{ "Bots", "LoafBot, NibBot, PurrBot hold empty seats" },
	{ "Leave", "Back to hub frees your seat in lobby" },
	{ "T", "Emote mid-party" },
	{ "Voice", "Hub rules · not a team channel" },
	{ "Audio", "SFX + Music sliders · mute" },
	{ "H / ?", "This help" },
	{ "Hub", "Back to hub (clean exit)" },
}

local LINES_ARCADE: { { string } } = {
	{ "1–5", "Buy 1 bag of that ticker (LOAF NYAN CHNK BRAIN RUG)" },
	{ "Shift+1–5", "Sell 1 bag at the listed yarn price" },
	{ "Tap", "Buy / Sell on the stall cards" },
	{ "Round", "28s tape · auto-sell at the bell · daily profit board" },
	{ "Events", "TO THE MOON · RUG PULL · WHALE SNEEZE" },
	{ "Yarn only", "Play yarn / points — not real money" },
	{ "T", "Emote at the counter" },
	{ "Voice", "Hub rules · not a team channel" },
	{ "Audio", "SFX + Music sliders · mute" },
	{ "H / ?", "This help" },
	{ "Hub", "Back to hub · Board for today's yarn profit" },
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
	root.Size = UDim2.fromOffset(320, 510)
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
			local row = Instance.new("Frame")
			row.Name = `Bind{i}`
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, -4, 0, 22)
			row.LayoutOrder = i
			row.Parent = list

			local key = Theme.text(row, "K", pair[1], 12, Theme.amber, Theme.fontMono)
			key.Size = UDim2.fromOffset(88, 22)
			key.TextWrapped = false

			local desc = Theme.text(row, "D", pair[2], 12, Theme.cream)
			desc.Position = UDim2.fromOffset(92, 0)
			desc.Size = UDim2.new(1, -92, 0, 22)
			desc.TextWrapped = false
			desc.TextTruncate = Enum.TextTruncate.AtEnd
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
