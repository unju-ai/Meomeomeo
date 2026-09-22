--!strict

-- Cat Rift death receipt. Server sends the lines. This panel only paints them.
-- Hub, Yarn Run, Koi, Party, and Arcade never mount a recap.

local DamageLog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DamageLog"))
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local DeathRecap = {}

export type RecapApi = {
	root: Frame,
	chip: TextButton,
	show: (recap: Types.DeathRecap) -> (),
	hide: () -> (),
}

local KIND_COLOR: { [string]: Color3 } = {
	champion = Theme.peach,
	tower = Theme.amber,
	minion = Theme.mint,
	jungle = Theme.pink,
	item = Theme.coral,
}

function DeathRecap.create(parent: Instance): RecapApi
	local generation = 0
	local payload: Types.DeathRecap? = nil
	local pinned = false

	local card = Instance.new("Frame")
	card.Name = "DeathRecap"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.4)
	card.Size = UDim2.fromOffset(380, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Theme.panel
	card.Visible = false
	card.Active = true
	card.ZIndex = 16
	card.Parent = parent
	Theme.corner(card, 18)
	Theme.stroke(card, Theme.coral, 2, 0.12)
	Theme.pad(card, 12)
	Theme.list(card, 6)

	local titleRow = Instance.new("Frame")
	titleRow.Name = "TitleRow"
	titleRow.BackgroundTransparency = 1
	titleRow.Size = UDim2.new(1, 0, 0, 28)
	titleRow.LayoutOrder = 1
	titleRow.ZIndex = 17
	titleRow.Parent = card

	local title = Theme.text(titleRow, "Title", "Death recap", 20, Theme.coral, Theme.fontTitle)
	title.Size = UDim2.new(1, -36, 1, 0)
	title.ZIndex = 17

	local close = Theme.button(titleRow, "Close", "✕", Theme.coral)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(28, 28)
	close.TextSize = 14
	close.ZIndex = 18

	local sub = Theme.text(card, "Sub", "Who scratched you", 13, Theme.peach, Theme.fontBody)
	sub.Size = UDim2.new(1, 0, 0, 16)
	sub.LayoutOrder = 2
	sub.ZIndex = 17

	local empty = Theme.text(card, "Empty", "The rift blinked. No scratches on the receipt.", 13, Theme.cream, Theme.fontBody)
	empty.Size = UDim2.new(1, 0, 0, 32)
	empty.LayoutOrder = 3
	empty.Visible = false
	empty.ZIndex = 17

	local rowFrames: { Frame } = {}
	local rowChips: { TextLabel } = {}
	local rowNames: { TextLabel } = {}
	local rowAmounts: { TextLabel } = {}
	for i = 1, DamageLog.MaxLines do
		local row = Instance.new("Frame")
		row.Name = `Row{i}`
		row.BackgroundColor3 = Theme.panelAlt
		row.Size = UDim2.new(1, 0, 0, 36)
		row.LayoutOrder = 10 + i
		row.Visible = false
		row.ZIndex = 17
		row.Parent = card
		Theme.corner(row, 8)

		local chip = Theme.text(row, "Kind", "", 11, Theme.ink, Theme.fontMono)
		chip.BackgroundColor3 = Theme.amber
		chip.BackgroundTransparency = 0
		chip.Position = UDim2.fromOffset(6, 8)
		chip.Size = UDim2.fromOffset(58, 20)
		chip.TextXAlignment = Enum.TextXAlignment.Center
		chip.ZIndex = 18
		Theme.corner(chip, 6)

		local name = Theme.text(row, "Name", "", 13, Theme.cream, Theme.fontBody)
		name.Position = UDim2.fromOffset(72, 2)
		name.Size = UDim2.new(1, -148, 0, 32)
		name.TextWrapped = false
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.ZIndex = 18

		local amount = Theme.text(row, "Amount", "", 13, Theme.cream, Theme.fontMono)
		amount.AnchorPoint = Vector2.new(1, 0.5)
		amount.Position = UDim2.new(1, -8, 0.5, 0)
		amount.Size = UDim2.fromOffset(64, 32)
		amount.TextXAlignment = Enum.TextXAlignment.Right
		amount.ZIndex = 18

		table.insert(rowFrames, row)
		table.insert(rowChips, chip)
		table.insert(rowNames, name)
		table.insert(rowAmounts, amount)
	end

	local footer = Theme.text(card, "Footer", "Hides before the fountain · Recap brings it back", 11, Theme.muted, Theme.fontBody)
	footer.Size = UDim2.new(1, 0, 0, 16)
	footer.LayoutOrder = 40
	footer.ZIndex = 17

	local chipButton = Theme.button(parent, "DeathRecapChip", "Recap", Theme.peach)
	chipButton.AnchorPoint = Vector2.new(0.5, 1)
	chipButton.Position = UDim2.new(0.5, 0, 1, -218)
	chipButton.Size = UDim2.fromOffset(88, 28)
	chipButton.TextSize = 14
	chipButton.Visible = false
	chipButton.ZIndex = 16

	local function showCard()
		card.Visible = true
		chipButton.Visible = false
	end

	local function showChip()
		if payload == nil then
			card.Visible = false
			chipButton.Visible = false
			return
		end
		card.Visible = false
		chipButton.Visible = true
	end

	local function paint(recap: Types.DeathRecap)
		local lines = recap.lines
		empty.Visible = #lines == 0
		empty.Size = if #lines == 0 then UDim2.new(1, 0, 0, 32) else UDim2.fromOffset(0, 0)
		for i, row in rowFrames do
			local line = lines[i]
			if line then
				row.Visible = true
				row.Size = UDim2.new(1, 0, 0, 36)
				local kindColor = KIND_COLOR[line.sourceKind] or Theme.amber
				rowChips[i].Text = DamageLog.kindWord(line.sourceKind)
				rowChips[i].BackgroundColor3 = kindColor
				rowNames[i].Text = if line.killingBlow
					then `{line.sourceName} · {line.label} · killing blow`
					else `{line.sourceName} · {line.label}`
				rowNames[i].TextColor3 = if line.killingBlow then Theme.peach else Theme.cream
				rowAmounts[i].Text = `~{line.amount}`
				rowAmounts[i].TextColor3 = if line.killingBlow then Theme.coral else Theme.cream
				row.BackgroundColor3 = if line.killingBlow then Color3.fromRGB(92, 42, 40) else Theme.panelAlt
			else
				row.Visible = false
				row.Size = UDim2.fromOffset(0, 0)
			end
		end
	end

	close.MouseButton1Click:Connect(function()
		pinned = false
		showChip()
	end)

	chipButton.MouseButton1Click:Connect(function()
		if payload == nil then
			return
		end
		pinned = true
		showCard()
	end)

	return {
		root = card,
		chip = chipButton,
		show = function(recap: Types.DeathRecap)
			generation += 1
			local gen = generation
			payload = recap
			pinned = false
			paint(recap)
			showCard()
			local now = workspace:GetServerTimeNow()
			local respawnAt = recap.respawnAt or (now + 6)
			local waitFor = (respawnAt - DamageLog.HideLead) - now
			if waitFor < 0.35 then
				waitFor = 1.2
			end
			task.delay(waitFor, function()
				if generation ~= gen or pinned then
					return
				end
				showChip()
			end)
		end,
		hide = function()
			generation += 1
			payload = nil
			pinned = false
			card.Visible = false
			chipButton.Visible = false
		end,
	}
end

return DeathRecap
