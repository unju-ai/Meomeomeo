--!strict

-- Compact Cat Rift tape under the kill feed. Symbol, price, green/red change.
-- A play bump flashes that chip. Hidden outside a Rift fight. Not the Arcade board.

local TweenService = game:GetService("TweenService")

local MemeStockLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("MemeStockLogic"))
local Theme = require(script.Parent.Parent.Theme)

local MemeTape = {}

export type Row = {
	id: string,
	symbol: string,
	price: number,
	change: number,
}

export type TapeApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	setRows: (rows: { Row }, flash: { string }?) -> (),
}

type Chip = {
	frame: Frame,
	label: TextLabel,
}

local function hexFor(tone: string): string
	if tone == "up" then
		return "#60C478"
	elseif tone == "down" then
		return "#DC5050"
	end
	return "#7A5C50"
end

local function rowRich(row: Row): string
	local tone = MemeStockLogic.tone(row.change)
	local change = MemeStockLogic.signed(row.change)
	local price = MemeStockLogic.priceText(row.price)
	return `<font color="#FFC44A">{row.symbol}</font>  <font color="#FFF3E0">{price}</font>  <font color="{hexFor(tone)}">{change}</font>`
end

local function plainWidth(row: Row): number
	local plain = `{row.symbol}  {MemeStockLogic.priceText(row.price)}  {MemeStockLogic.signed(row.change)}`
	return math.clamp(18 + #plain * 7, 112, 176)
end

function MemeTape.create(parent: Instance): TapeApi
	local root = Instance.new("Frame")
	root.Name = "MemeTape"
	root.AnchorPoint = Vector2.new(0.5, 0)
	-- Below the kill-feed chip stack (feed Y≈36, ~4×20px rows) with a clear gap.
	root.Position = UDim2.new(0.5, 0, 0, 136)
	root.Size = UDim2.fromOffset(720, 28)
	root.BackgroundColor3 = Theme.ink
	root.BackgroundTransparency = 0.22
	root.Visible = false
	root.ClipsDescendants = true
	root.ZIndex = 6
	root.Parent = parent
	Theme.corner(root, 8)
	Theme.stroke(root, Theme.amber, 1, 0.45)

	local mark = Theme.text(root, "Mark", "🧶", 14, Theme.amber, Theme.fontTitle)
	mark.Position = UDim2.fromOffset(2, 0)
	mark.Size = UDim2.fromOffset(24, 28)
	mark.TextXAlignment = Enum.TextXAlignment.Center
	mark.TextWrapped = false
	mark.ZIndex = 7

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundTransparency = 1
	strip.AnchorPoint = Vector2.new(0.5, 0)
	strip.Position = UDim2.new(0.5, 12, 0, 3)
	strip.Size = UDim2.fromOffset(640, 22)
	strip.ZIndex = 7
	strip.Parent = root

	local layout = Theme.list(strip, 6, Enum.FillDirection.Horizontal)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local chips: { [string]: Chip } = {}
	local pulseToken: { [string]: number } = {}
	local scrollToken = 0
	local scrollingSpan = 0
	local activeTween: Tween? = nil

	local function stopScroll()
		scrollToken += 1
		scrollingSpan = 0
		if activeTween then
			activeTween:Cancel()
			activeTween = nil
		end
	end

	local function centerStrip(contentWidth: number)
		stopScroll()
		strip.AnchorPoint = Vector2.new(0.5, 0)
		strip.Position = UDim2.new(0.5, 12, 0, 3)
		strip.Size = UDim2.fromOffset(math.max(contentWidth, 1), 22)
	end

	local function startScroll(span: number)
		scrollToken += 1
		local token = scrollToken
		scrollingSpan = span
		if activeTween then
			activeTween:Cancel()
			activeTween = nil
		end
		strip.AnchorPoint = Vector2.new(0, 0)
		strip.Position = UDim2.fromOffset(28, 3)
		task.spawn(function()
			while scrollToken == token and root.Parent ~= nil do
				local duration = math.max(8, span / 36)
				local tween = TweenService:Create(strip, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
					Position = UDim2.fromOffset(28 - span, 3),
				})
				activeTween = tween
				tween:Play()
				tween.Completed:Wait()
				if activeTween == tween then
					activeTween = nil
				end
				if scrollToken ~= token then
					return
				end
				strip.Position = UDim2.fromOffset(28, 3)
				task.wait(0.8)
			end
		end)
	end

	local function refit()
		local content = layout.AbsoluteContentSize.X
		local view = root.AbsoluteSize.X - 36
		if content <= 0 or view <= 0 then
			return
		end
		if content <= view then
			if scrollingSpan ~= 0 or strip.AnchorPoint.X ~= 0.5 or math.abs(strip.Size.X.Offset - content) > 1 then
				centerStrip(content)
			end
			return
		end
		local span = content - view
		strip.Size = UDim2.fromOffset(content, 22)
		if math.abs(scrollingSpan - span) > 8 then
			startScroll(span)
		end
	end

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		refit()
	end)

	local function pulse(id: string, frame: Frame, tone: string)
		pulseToken[id] = (pulseToken[id] or 0) + 1
		local token = pulseToken[id]
		local color = if tone == "down" then Theme.bad elseif tone == "up" then Theme.good else Theme.amber
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = 0.02
		local tween = TweenService:Create(frame, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = Theme.panel,
			BackgroundTransparency = 0.12,
		})
		tween:Play()
		task.delay(0.55, function()
			if pulseToken[id] == token and frame.Parent then
				frame.BackgroundColor3 = Theme.panel
				frame.BackgroundTransparency = 0.12
			end
		end)
	end

	local function ensure(row: Row): Chip
		local existing = chips[row.id]
		if existing then
			return existing
		end
		local frame = Instance.new("Frame")
		frame.Name = row.symbol
		frame.BackgroundColor3 = Theme.panel
		frame.BackgroundTransparency = 0.12
		frame.Size = UDim2.fromOffset(plainWidth(row), 22)
		frame.ZIndex = 7
		frame.Parent = strip
		Theme.corner(frame, 6)
		local label = Theme.text(frame, "Quote", rowRich(row), 13, Theme.cream, Theme.fontMono)
		label.Size = UDim2.fromScale(1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextWrapped = false
		label.RichText = true
		label.ZIndex = 8
		local chip: Chip = {
			frame = frame,
			label = label,
		}
		chips[row.id] = chip
		return chip
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if not visible then
				stopScroll()
				strip.AnchorPoint = Vector2.new(0.5, 0)
				strip.Position = UDim2.new(0.5, 12, 0, 3)
			end
		end,
		setRows = function(rows: { Row }, flash: { string }?)
			local seen: { [string]: boolean } = {}
			local flashSet: { [string]: boolean } = {}
			if flash then
				for _, symbol in flash do
					flashSet[symbol] = true
				end
			end
			for index, row in rows do
				seen[row.id] = true
				local chip = ensure(row)
				chip.frame.LayoutOrder = index
				chip.frame.Size = UDim2.fromOffset(plainWidth(row), 22)
				chip.label.Text = rowRich(row)
				if flashSet[row.symbol] then
					pulse(row.id, chip.frame, MemeStockLogic.tone(row.change))
				end
			end
			local stale = {}
			for id in chips do
				if not seen[id] then
					table.insert(stale, id)
				end
			end
			for _, id in stale do
				local chip = chips[id]
				if chip then
					chip.frame:Destroy()
				end
				chips[id] = nil
				pulseToken[id] = nil
			end
			task.defer(function()
				task.defer(refit)
			end)
		end,
	}
end

return MemeTape
