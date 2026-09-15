--!strict

-- Night-market mode grid. Rounded yarn/coral tiles — not a Discover clone.

local Theme = require(script.Parent.Parent.Theme)
local BrandCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrandCatalog"))
local ModeCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ModeCatalog"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local YarnRunCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("YarnRunCatalog"))

local HubPanel = {}

export type HubApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (status: Types.HubStatus) -> (),
	onPlayRift: (() -> ()) -> (),
	onPlayRun: ((championId: string) -> ()) -> (),
	onPlayPond: (() -> ()) -> (),
	onPlayParty: (() -> ()) -> (),
	onPlayArcade: (() -> ()) -> (),
	onMint: (() -> ()) -> (),
	onBoard: (() -> ()) -> (),
	updateBoard: (board: Types.YarnBoard) -> (),
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
	root.Size = UDim2.fromOffset(780, 560)
	root.BackgroundColor3 = Theme.panel
	root.Parent = parent
	Theme.corner(root, 24)
	Theme.stroke(root, Theme.peach, 3, 0.18)
	Theme.pad(root, 18)

	local title = Theme.text(root, "Title", BrandCatalog.Name, 34, Theme.amber, Theme.fontTitle)
	title.Size = UDim2.new(1, -150, 0, 36)

	local mintBtn = Theme.button(root, "Mint", "Mint 404", Theme.coral)
	mintBtn.AnchorPoint = Vector2.new(1, 0)
	mintBtn.Position = UDim2.new(1, 0, 0, 2)
	mintBtn.Size = UDim2.fromOffset(128, 34)
	mintBtn.TextSize = 15

	local sub = Theme.text(root, "Sub", `{BrandCatalog.Tagline} Pick a stall.`, 15, Theme.cream)
	sub.Position = UDim2.fromOffset(0, 36)
	sub.Size = UDim2.new(1, 0, 0, 20)

	local hint = Theme.text(root, "Hint", "T emote · Audio · ? help · yarn/coral stalls, not a battle-pass grid.", 12, Theme.muted)
	hint.Position = UDim2.fromOffset(0, 56)
	hint.Size = UDim2.new(1, 0, 0, 16)

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, 80)
	grid.Size = UDim2.new(1, 0, 1, -88)
	grid.Parent = root

	local playRift: (() -> ())? = nil
	local playRun: ((string) -> ())? = nil
	local playPond: (() -> ())? = nil
	local playParty: (() -> ())? = nil
	local playArcade: (() -> ())? = nil
	local mintHandler: (() -> ())? = nil
	local boardHandler: (() -> ())? = nil
	local counts: { [string]: number } = {}
	local picked = "NyanRocket"
	local runnerButtons: { TextButton } = {}
	local yarnBest = 0
	local koiBest = 0
	local arcadeBest = 0
	local yarnLead = ""

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
			if koiBest > 0 then
				if n <= 0 then
					return `PB catch {koiBest}`
				end
				return `{n} playing · PB {koiBest}`
			end
		end
		if id == "MemeArcade" then
			local n = counts[id] or 0
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
	for i, def in tiles do
		local col = (i - 1) % 3
		local row = math.floor((i - 1) / 3)
		local card = Instance.new("Frame")
		card.Name = def.id
		card.BackgroundColor3 = Theme.panelAlt
		card.Position = UDim2.new(col * 0.34, 0, 0, row * 220)
		card.Size = UDim2.new(0.32, 0, 0, 208)
		card.Parent = grid
		Theme.corner(card, 16)
		Theme.stroke(card, def.accent, 2, if def.playable then 0.15 else 0.55)
		Theme.pad(card, 10)

		swatchArt(card, def.art, def.swatch)

		local tag = Theme.text(card, "Tag", def.tag, 11, def.accent, Theme.fontMono)
		tag.Position = UDim2.fromOffset(0, 82)
		tag.Size = UDim2.new(1, 0, 0, 14)

		local name = Theme.text(card, "Name", def.title, 20, Theme.cream, Theme.fontTitle)
		name.Position = UDim2.fromOffset(0, 96)
		name.Size = UDim2.new(1, 0, 0, 22)

		local blurb = Theme.text(card, "Blurb", def.blurb, 12, Theme.peach)
		blurb.Position = UDim2.fromOffset(0, 118)
		blurb.Size = UDim2.new(1, 0, 0, 32)

		local pop = Theme.text(card, "Pop", countText(def.id), 11, Theme.muted)
		pop.Position = UDim2.fromOffset(0, 150)
		pop.Size = UDim2.new(1, 0, 0, 14)

		if def.id == "YarnRun" then
			local rowBtns = Instance.new("Frame")
			rowBtns.Name = "Cats"
			rowBtns.BackgroundTransparency = 1
			rowBtns.Position = UDim2.fromOffset(0, 164)
			rowBtns.Size = UDim2.new(1, 0, 0, 18)
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

		local play = Theme.button(card, "Play", if def.playable then "Play" else "Soon", if def.playable then Theme.amber else Theme.muted)
		play.Position = UDim2.new(0, 0, 1, -28)
		play.Size = UDim2.new(1, 0, 0, 26)
		play.TextSize = 15
		play.Active = def.playable
		play.AutoButtonColor = def.playable
		if def.playable then
			play.MouseButton1Click:Connect(function()
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
		end
	end

	mintBtn.MouseButton1Click:Connect(function()
		if mintHandler then
			mintHandler()
		end
	end)

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
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
		onMint = function(fn)
			mintHandler = fn
		end,
		onBoard = function(fn)
			boardHandler = fn
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
	}
end

return HubPanel
