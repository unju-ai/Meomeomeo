--!strict

-- Night-market mode grid. Rounded yarn/coral tiles — not a Discover clone.

local Theme = require(script.Parent.Parent.Theme)
local PublishPanel = require(script.Parent.PublishPanel)
local BrandCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrandCatalog"))
local ModeCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ModeCatalog"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local YarnRunCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("YarnRunCatalog"))

local HubPanel = {}

local BOB_PERIOD = 2.6
local BOB_SCALE = 1.018

local TweenService: any = nil
pcall(function()
	TweenService = game:GetService("TweenService")
end)

export type HubApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (status: Types.HubStatus) -> (),
	onPlayRift: (() -> ()) -> (),
	onPlayRun: ((championId: string) -> ()) -> (),
	onPlayPond: (() -> ()) -> (),
	onPlayParty: (() -> ()) -> (),
	onPlayArcade: (() -> ()) -> (),
	onTalk: ((hostId: string, hostName: string) -> ()) -> (),
	onMint: (() -> ()) -> (),
	onCloset: (() -> ()) -> (),
	onLive: (() -> ()) -> (),
	applyPublish: (report: any) -> (),
	showPublishError: (message: string) -> (),
	dismissPublish: () -> (),
	onBoard: (() -> ()) -> (),
	onKoiBoard: (() -> ()) -> (),
	onArcadeBoard: (() -> ()) -> (),
	updateBoard: (board: Types.YarnBoard) -> (),
	updateKoiBoard: (board: Types.StallBoard) -> (),
	updateArcadeBoard: (board: Types.StallBoard) -> (),
}

local function swatchArt(parent: Frame, art: ModeCatalog.ModeArt, color: Color3)
	local canvas = Instance.new("Frame")
	canvas.Name = "Art"
	canvas.BackgroundColor3 = color
	canvas.Size = UDim2.new(1, 0, 0, 78)
	canvas.Parent = parent
	Theme.corner(canvas, 14)

	local function blob(name: string, pos: UDim2, size: UDim2, tint: Color3)
		local p = Instance.new("Frame")
		p.Name = name
		p.BackgroundColor3 = tint
		p.Position = pos
		p.Size = size
		p.BorderSizePixel = 0
		p.Parent = canvas
		Theme.corner(p, 10)
	end

	if art == "rift" then
		blob("Lane", UDim2.fromOffset(16, 36), UDim2.new(1, -32, 0, 8), Theme.amber)
		blob("Tower", UDim2.fromOffset(22, 18), UDim2.fromOffset(16, 36), Theme.cream)
		blob("Nexus", UDim2.new(1, -46, 0, 22), UDim2.fromOffset(22, 22), Theme.coral)
	elseif art == "run" then
		blob("Yarn", UDim2.fromOffset(28, 18), UDim2.fromOffset(28, 28), Theme.coral)
		blob("Dog", UDim2.fromOffset(88, 32), UDim2.fromOffset(36, 22), Theme.ink)
		blob("Rail", UDim2.fromOffset(16, 58), UDim2.new(1, -32, 0, 8), Theme.peach)
	elseif art == "fish" then
		blob("Pond", UDim2.fromOffset(18, 28), UDim2.new(1, -36, 0, 28), Theme.blue)
		blob("Lily", UDim2.fromOffset(88, 22), UDim2.fromOffset(18, 10), Theme.mint)
		blob("Koi", UDim2.fromOffset(40, 34), UDim2.fromOffset(34, 14), Theme.coral)
		blob("Lantern", UDim2.fromOffset(110, 12), UDim2.fromOffset(10, 16), Theme.amber)
	elseif art == "party" then
		blob("Ball", UDim2.fromOffset(48, 16), UDim2.fromOffset(36, 36), Theme.coral)
		blob("Cat", UDim2.fromOffset(20, 40), UDim2.fromOffset(22, 22), Theme.cream)
		blob("Pillow", UDim2.fromOffset(88, 44), UDim2.fromOffset(28, 14), Theme.peach)
	else
		blob("Chart", UDim2.fromOffset(20, 20), UDim2.fromOffset(18, 40), Theme.mint)
		blob("Chart2", UDim2.fromOffset(48, 32), UDim2.fromOffset(18, 28), Theme.amber)
		blob("Chart3", UDim2.fromOffset(76, 24), UDim2.fromOffset(18, 36), Theme.coral)
	end
end

function HubPanel.create(parent: Instance): HubApi
	local root = Instance.new("Frame")
	root.Name = "Hub"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.new(1, -24, 1, -96)
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(780, 560)
	bounds.Parent = root
	root.BackgroundColor3 = Theme.panel
	root.Parent = parent
	Theme.corner(root, 24)
	Theme.stroke(root, Theme.peach, 3, 0.18)
	Theme.pad(root, 18)

	local title = Theme.text(root, "Title", BrandCatalog.Name, 34, Theme.amber, Theme.fontTitle)
	title.Size = UDim2.new(1, -270, 0, 36)

	local closetBtn = Theme.button(root, "Closet", "Closet", Theme.peach)
	closetBtn.AnchorPoint = Vector2.new(1, 0)
	closetBtn.Position = UDim2.new(1, -136, 0, 2)
	closetBtn.Size = UDim2.fromOffset(128, 34)
	closetBtn.TextSize = 15

	local mintBtn = Theme.button(root, "Mint", "Mint 404", Theme.coral)
	mintBtn.AnchorPoint = Vector2.new(1, 0)
	mintBtn.Position = UDim2.new(1, 0, 0, 2)
	mintBtn.Size = UDim2.fromOffset(128, 34)
	mintBtn.TextSize = 15

	local sub = Theme.text(root, "Sub", `{BrandCatalog.Tagline} Night-market stalls.`, 15, Theme.cream)
	sub.Position = UDim2.fromOffset(0, 36)
	sub.Size = UDim2.new(1, 0, 0, 20)

	local hint = Theme.text(root, "Hint", "Hover a stall · Live checklist · Closet · Audio · T emote · ? help", 12, Theme.muted)
	hint.Position = UDim2.fromOffset(0, 56)
	hint.Size = UDim2.new(1, -80, 0, 16)

	local liveBtn = Theme.button(root, "Live", "Live", Theme.mint)
	liveBtn.AnchorPoint = Vector2.new(1, 0)
	liveBtn.Position = UDim2.new(1, 0, 0, 56)
	liveBtn.Size = UDim2.fromOffset(72, 22)
	liveBtn.TextSize = 13
	liveBtn.ZIndex = 4

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 4
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.fromOffset(0, 0)
	grid.Position = UDim2.fromOffset(0, 80)
	grid.Size = UDim2.new(1, 0, 1, -88)
	grid.Parent = root

	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.Parent = grid

	local function resize()
		local width = root.AbsoluteSize.X - 36
		local compact = width < 640
		local columns = if width >= 700 then 3 elseif width >= 460 then 2 else 1
		-- Leave room for the scrollbar; preserve readable cards instead of shrinking text.
		layout.CellSize = UDim2.new(1 / columns, -(12 * (columns - 1) + 8) / columns, 0, 208)
		title.Size = UDim2.new(1, if compact then 0 else -270, 0, 36)
		title.TextSize = if compact then 28 else 34
		closetBtn.Position = UDim2.new(1, -136, 0, if compact then 76 else 2)
		mintBtn.Position = UDim2.new(1, 0, 0, if compact then 76 else 2)
		sub.Size = UDim2.new(1, 0, 0, if compact then 36 else 20)
		hint.Visible = not compact
		hint.Size = UDim2.new(1, if compact then 0 else -80, 0, 16)
		sub.Position = UDim2.fromOffset(0, 36)
		if compact then
			-- Closet's right edge sits 136px in from the right, and the button is 128 wide.
			local closetLeft = root.AbsoluteSize.X - 264
			if closetLeft >= 80 then
				liveBtn.AnchorPoint = Vector2.new(0, 0)
				liveBtn.Position = UDim2.fromOffset(0, 76)
				liveBtn.Size = UDim2.fromOffset(math.min(72, closetLeft - 8), 34)
			else
				liveBtn.AnchorPoint = Vector2.new(0, 0)
				liveBtn.Position = UDim2.fromOffset(0, 40)
				liveBtn.Size = UDim2.fromOffset(64, 28)
				sub.Position = UDim2.fromOffset(70, 40)
				sub.Size = UDim2.new(1, -70, 0, 28)
			end
		else
			liveBtn.AnchorPoint = Vector2.new(1, 0)
			liveBtn.Position = UDim2.new(1, 0, 0, 56)
			liveBtn.Size = UDim2.fromOffset(72, 22)
		end
		local top = if compact then 120 else 80
		grid.Position = UDim2.fromOffset(0, top)
		grid.Size = UDim2.new(1, 0, 1, -top)
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()

	local playRift: (() -> ())? = nil
	local playRun: ((string) -> ())? = nil
	local playPond: (() -> ())? = nil
	local playParty: (() -> ())? = nil
	local playArcade: (() -> ())? = nil
	local talkHandler: ((string, string) -> ())? = nil
	local mintHandler: (() -> ())? = nil
	local closetHandler: (() -> ())? = nil
	local liveHandler: (() -> ())? = nil
	local boardHandler: (() -> ())? = nil
	local publish = PublishPanel.create(root)
	local koiBoardHandler: (() -> ())? = nil
	local arcadeBoardHandler: (() -> ())? = nil
	local counts: { [string]: number } = {}
	local picked = "NyanRocket"
	local runnerButtons: { TextButton } = {}
	local yarnBest = 0
	local koiBest = 0
	local arcadeBest = 0
	local yarnLead = ""
	local koiLead = ""
	local arcadeLead = ""

	local function countText(id: string): string
		if id == "YarnRun" then
			local n = counts[id] or 0
			if yarnLead ~= "" then
				if n > 0 then
					return `{n} playing · {yarnLead}`
				end
				return yarnLead
			end
			if yarnBest > 0 then
				if n <= 0 then
					return `PB {yarnBest}`
				end
				return `{n} playing · PB {yarnBest}`
			end
		end
		if id == "KoiPond" then
			local n = counts[id] or 0
			if koiLead ~= "" then
				if n > 0 then
					return `{n} playing · {koiLead}`
				end
				return koiLead
			end
			if koiBest > 0 then
				if n <= 0 then
					return `PB catch {koiBest}`
				end
				return `{n} playing · PB {koiBest}`
			end
		end
		if id == "MemeArcade" then
			local n = counts[id] or 0
			if arcadeLead ~= "" then
				if n > 0 then
					return `{n} playing · {arcadeLead}`
				end
				return arcadeLead
			end
			if arcadeBest > 0 then
				if n <= 0 then
					return `Daily +{arcadeBest} yarn`
				end
				return `{n} playing · daily +{arcadeBest}`
			end
		end
		local n = counts[id] or 0
		if n <= 0 then
			return "Quiet stall"
		end
		return `{n} playing`
	end

	local tiles = ModeCatalog.all()
	local stallCards: { Frame } = {}
	local selectedId: string? = nil
	local hoveredId: string? = nil

	local function paintStall(card: Frame, def: ModeCatalog.ModeTile, stroke: UIStroke, scale: UIScale)
		local hot = hoveredId == def.id or selectedId == def.id
		card.BackgroundColor3 = def.wash
		card.BackgroundTransparency = if hot then 0 else 0.08
		stroke.Color = if hot then ModeCatalog.glowAccent(def) else def.accent
		stroke.Thickness = if hot then 3 else 2
		stroke.Transparency = if not def.playable then 0.55 elseif hot then 0.02 else 0.12
		if not hot then
			scale.Scale = 1
		end
	end

	for i, def in tiles do
		local card = Instance.new("Frame")
		card.Name = def.id
		card.BackgroundColor3 = def.wash
		card.BackgroundTransparency = 0.08
		card.LayoutOrder = i
		card.Size = UDim2.new(0.32, 0, 0, 208)
		card.Parent = grid
		Theme.corner(card, 18)
		local stroke = Theme.stroke(card, def.accent, 2, if def.playable then 0.12 else 0.55)
		Theme.pad(card, 10)
		table.insert(stallCards, card)

		local scale = Instance.new("UIScale")
		scale.Name = "Bob"
		scale.Scale = 1
		scale.Parent = card

		swatchArt(card, def.art, def.swatch)

		local tagChip = Instance.new("TextLabel")
		tagChip.Name = "Tag"
		tagChip.BackgroundColor3 = def.accent
		tagChip.BackgroundTransparency = 0.12
		tagChip.Text = ModeCatalog.stallTag(def)
		tagChip.TextColor3 = Theme.ink
		tagChip.TextSize = 11
		tagChip.Font = Theme.fontMono
		tagChip.TextXAlignment = Enum.TextXAlignment.Center
		tagChip.Position = UDim2.fromOffset(0, 82)
		tagChip.Size = UDim2.fromOffset(64, 18)
		tagChip.Parent = card
		Theme.corner(tagChip, 6)

		local name = Theme.text(card, "Name", def.title, 22, Theme.cream, Theme.fontTitle)
		name.Position = UDim2.fromOffset(0, 102)
		name.Size = UDim2.new(1, 0, 0, 24)

		local blurb = Theme.text(card, "Blurb", ModeCatalog.oneLine(def), 12, Theme.peach)
		blurb.Position = UDim2.fromOffset(0, 126)
		blurb.Size = UDim2.new(1, 0, 0, 28)

		local pop = Theme.text(card, "Pop", countText(def.id), 11, Theme.muted)
		pop.Position = UDim2.fromOffset(0, 154)
		pop.Size = UDim2.new(1, 0, 0, 14)

		if def.id == "YarnRun" then
			local rowBtns = Instance.new("Frame")
			rowBtns.Name = "Cats"
			rowBtns.BackgroundTransparency = 1
			rowBtns.Position = UDim2.fromOffset(0, 166)
			rowBtns.Size = UDim2.new(1, 0, 0, 16)
			rowBtns.Parent = card
			for r, id in YarnRunCatalog.Runners do
				local btn = Theme.button(rowBtns, id, string.sub(id, 1, 4), Theme.peach)
				btn.Position = UDim2.new((r - 1) * 0.34, 0, 0, 0)
				btn.Size = UDim2.new(0.32, 0, 1, 0)
				btn.TextSize = 11
				table.insert(runnerButtons, btn)
				btn.MouseButton1Click:Connect(function()
					picked = id
					for _, other in runnerButtons do
						other.BackgroundColor3 = if other.Name == picked then Theme.mint else Theme.peach
					end
				end)
			end
			if runnerButtons[1] then
				runnerButtons[1].BackgroundColor3 = Theme.mint
			end
		end

		local play = Theme.button(card, "Play", ModeCatalog.playLabel(def), if def.playable then def.accent else Theme.muted)
		play.Position = UDim2.new(0, 0, 1, -28)
		play.Size = UDim2.new(1, 0, 0, 26)
		play.TextSize = 15
		play.Active = def.playable
		play.AutoButtonColor = def.playable
		if def.playable then
			play.MouseButton1Click:Connect(function()
				selectedId = def.id
				for _, other in stallCards do
					local otherDef = ModeCatalog.get(other.Name)
					local otherStroke = other:FindFirstChildWhichIsA("UIStroke")
					local otherScale = other:FindFirstChild("Bob")
					if otherDef and otherStroke and otherScale and otherScale:IsA("UIScale") then
						paintStall(other, otherDef, otherStroke, otherScale)
					end
				end
				if def.id == "CatRift" then
					if playRift then
						playRift()
					end
				elseif def.id == "YarnRun" then
					if playRun then
						playRun(picked)
					end
				elseif def.id == "KoiPond" then
					if playPond then
						playPond()
					end
				elseif def.id == "YarnParty" then
					if playParty then
						playParty()
					end
				elseif def.id == "MemeArcade" then
					if playArcade then
						playArcade()
					end
				end
			end)
		end
		if def.id == "YarnRun" then
			play.Size = UDim2.new(0.58, 0, 0, 26)
			local boardBtn = Theme.button(card, "Board", "Board", Theme.peach)
			boardBtn.Position = UDim2.new(0.62, 0, 1, -28)
			boardBtn.Size = UDim2.new(0.38, 0, 0, 26)
			boardBtn.TextSize = 14
			boardBtn.MouseButton1Click:Connect(function()
				if boardHandler then
					boardHandler()
				end
			end)
		elseif def.id == "KoiPond" then
			play.Size = UDim2.new(0.58, 0, 0, 26)
			local boardBtn = Theme.button(card, "Board", "Board", Theme.peach)
			boardBtn.Position = UDim2.new(0.62, 0, 1, -28)
			boardBtn.Size = UDim2.new(0.38, 0, 0, 26)
			boardBtn.TextSize = 14
			boardBtn.MouseButton1Click:Connect(function()
				if koiBoardHandler then
					koiBoardHandler()
				end
			end)
		elseif def.id == "MemeArcade" then
			play.Size = UDim2.new(0.58, 0, 0, 26)
			local boardBtn = Theme.button(card, "Board", "Board", Theme.peach)
			boardBtn.Position = UDim2.new(0.62, 0, 1, -28)
			boardBtn.Size = UDim2.new(0.38, 0, 0, 26)
			boardBtn.TextSize = 14
			boardBtn.MouseButton1Click:Connect(function()
				if arcadeBoardHandler then
					arcadeBoardHandler()
				end
			end)
		end

		local function setHover(active: boolean)
			hoveredId = if active then def.id else if hoveredId == def.id then nil else hoveredId
			paintStall(card, def, stroke, scale)
			if active and def.playable then
				scale.Scale = 1.03
				if TweenService then
					pcall(function()
						TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Scale = 1.03,
						}):Play()
					end)
				end
			end
		end
		local enter = card.MouseEnter
		local leave = card.MouseLeave
		if enter then
			enter:Connect(function()
				setHover(true)
			end)
		end
		if leave then
			leave:Connect(function()
				setHover(false)
			end)
		end

		-- Soft idle bob: staggered, rate-limited, stops while hovered/selected.
		if def.playable then
			pcall(function()
				task.defer(function()
					local phase = (i - 1) * 0.38
					task.wait(phase)
					while card.Parent do
						if root.Visible and hoveredId ~= def.id and selectedId ~= def.id then
							scale.Scale = BOB_SCALE
							if TweenService then
								pcall(function()
									TweenService:Create(scale, TweenInfo.new(BOB_PERIOD * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
										Scale = BOB_SCALE,
									}):Play()
								end)
							end
							task.wait(BOB_PERIOD * 0.5)
							if hoveredId == def.id or selectedId == def.id or not card.Parent then
								break
							end
							scale.Scale = 1
							if TweenService then
								pcall(function()
									TweenService:Create(scale, TweenInfo.new(BOB_PERIOD * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
										Scale = 1,
									}):Play()
								end)
							end
							task.wait(BOB_PERIOD * 0.5)
						else
							task.wait(0.35)
						end
					end
				end)
			end)
		end
	end

	local cast = Instance.new("Frame")
	cast.Name = "MeetTheCats"
	cast.BackgroundColor3 = BrandCatalog.InkColor
	cast.LayoutOrder = #tiles + 1
	cast.Size = UDim2.new(0.32, 0, 0, 208)
	cast.Parent = grid
	Theme.corner(cast, 16)
	Theme.stroke(cast, BrandCatalog.BraincellColor, 2, 0.15)
	Theme.pad(cast, 10)
	local castTitle = Theme.text(cast, "Title", "Meet the cats", 20, BrandCatalog.PaperColor, Theme.fontTitle)
	castTitle.Size = UDim2.new(1, 0, 0, 24)
	local castSub = Theme.text(cast, "Sub", "Three cats. One shared braincell.", 12, BrandCatalog.PaperColor)
	castSub.Position = UDim2.fromOffset(0, 26)
	castSub.Size = UDim2.new(1, 0, 0, 32)
	for index, host in BrandCatalog.hosts() do
		local portrait = Theme.button(cast, host.id, host.name, host.color)
		portrait.Position = UDim2.new((index - 1) * 0.34, 0, 0, 68)
		portrait.Size = UDim2.new(0.32, 0, 0, 88)
		portrait.TextYAlignment = Enum.TextYAlignment.Bottom
		portrait.TextSize = 14
		portrait.TextColor3 = if host.id == "HostMo" then BrandCatalog.PaperColor else BrandCatalog.InkColor
		local cell = Instance.new("Frame")
		cell.Name = "Braincell"
		cell.BackgroundColor3 = BrandCatalog.BraincellColor
		cell.BorderSizePixel = 0
		cell.Position = UDim2.new(0.5, -3, 0, 13)
		cell.Size = UDim2.fromOffset(6, 6)
		cell.Parent = portrait
		local face = Theme.text(portrait, "Face", if host.id == "HostMo" then "·  °" else "·  ·", 26, portrait.TextColor3, Theme.fontMono)
		face.Position = UDim2.fromOffset(0, 22)
		face.Size = UDim2.new(1, 0, 0, 30)
		face.TextXAlignment = Enum.TextXAlignment.Center
		portrait.MouseButton1Click:Connect(function()
			if talkHandler then talkHandler(host.id, host.name) end
		end)
	end
	local castHint = Theme.text(cast, "Hint", "Tap a cat to talk.", 12, BrandCatalog.PaperColor)
	castHint.Position = UDim2.fromOffset(0, 166)
	castHint.Size = UDim2.new(1, 0, 0, 20)

	mintBtn.MouseButton1Click:Connect(function()
		if mintHandler then
			mintHandler()
		end
	end)
	closetBtn.MouseButton1Click:Connect(function()
		if closetHandler then
			closetHandler()
		end
	end)
	liveBtn.MouseButton1Click:Connect(function()
		local open = not publish.isOpen()
		publish.setVisible(open)
		if open and liveHandler then
			liveHandler()
		end
	end)

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if not visible then
				publish.setVisible(false)
				hoveredId = nil
			end
		end,
		update = function(status: Types.HubStatus)
			yarnBest = status.yarnBest
			koiBest = status.koiBest or 0
			arcadeBest = status.arcadeBest or 0
			for _, tile in status.tiles do
				counts[tile.id] = tile.playing
			end
			for _, child in grid:GetChildren() do
				if child:IsA("Frame") then
					local pop = child:FindFirstChild("Pop")
					if pop and pop:IsA("TextLabel") then
						pop.Text = countText(child.Name)
					end
				end
			end
		end,
		onPlayRift = function(fn)
			playRift = fn
		end,
		onPlayRun = function(fn)
			playRun = fn
		end,
		onPlayPond = function(fn)
			playPond = fn
		end,
		onPlayParty = function(fn)
			playParty = fn
		end,
		onPlayArcade = function(fn)
			playArcade = fn
		end,
		onTalk = function(fn)
			talkHandler = fn
		end,
		onMint = function(fn)
			mintHandler = fn
		end,
		onCloset = function(fn)
			closetHandler = fn
		end,
		onLive = function(fn)
			liveHandler = fn
		end,
		applyPublish = function(report: any)
			publish.apply(report)
		end,
		showPublishError = function(message: string)
			publish.showError(message)
		end,
		dismissPublish = function()
			publish.setVisible(false)
		end,
		onBoard = function(fn)
			boardHandler = fn
		end,
		onKoiBoard = function(fn)
			koiBoardHandler = fn
		end,
		onArcadeBoard = function(fn)
			arcadeBoardHandler = fn
		end,
		updateBoard = function(board: Types.YarnBoard)
			local first = board.entries[1]
			if first then
				yarnLead = `#{1} {first.name}`
			else
				yarnLead = ""
			end
			for _, child in grid:GetChildren() do
				if child:IsA("Frame") and child.Name == "YarnRun" then
					local pop = child:FindFirstChild("Pop")
					if pop and pop:IsA("TextLabel") then
						pop.Text = countText("YarnRun")
					end
				end
			end
		end,
		updateKoiBoard = function(board: Types.StallBoard)
			local first = board.entries[1]
			if first then
				koiLead = `#{1} {first.name}`
			else
				koiLead = ""
			end
			for _, child in grid:GetChildren() do
				if child:IsA("Frame") and child.Name == "KoiPond" then
					local pop = child:FindFirstChild("Pop")
					if pop and pop:IsA("TextLabel") then
						pop.Text = countText("KoiPond")
					end
				end
			end
		end,
		updateArcadeBoard = function(board: Types.StallBoard)
			local first = board.entries[1]
			if first then
				arcadeLead = `#{1} {first.name}`
			else
				arcadeLead = ""
			end
			for _, child in grid:GetChildren() do
				if child:IsA("Frame") and child.Name == "MemeArcade" then
					local pop = child:FindFirstChild("Pop")
					if pop and pop:IsA("TextLabel") then
						pop.Text = countText("MemeArcade")
					end
				end
			end
		end,
	}
end

return HubPanel
