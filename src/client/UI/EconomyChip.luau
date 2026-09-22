--!strict

-- Always-on local purse for Cat Rift InProgress. Gold, CS, level, and whether
-- Yarn Cleave fits in the purse. A Canal Levi line names who holds the buff.
-- Hidden by Hud outside that phase. Hub, Yarn Run, Koi, Party, and Arcade never show it.

local FarmCredit = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("FarmCredit"))
local ItemKits = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ItemKits"))
local RiverEpic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RiverEpic"))
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local EconomyChip = {}

export type ChipApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (matchPlayer: Types.MatchPlayer, epic: Types.RiverEpicView?) -> (),
}

local TONE_COLOR: { [FarmCredit.CleaveTone]: Color3 } = {
	ready = Theme.good,
	short = Theme.peach,
	owned = Theme.mint,
}

function EconomyChip.create(parent: Instance): ChipApi
	local root = Instance.new("Frame")
	root.Name = "EconomyChip"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -252)
	root.Size = UDim2.fromOffset(248, 56)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.ZIndex = 12
	root.Parent = parent
	Theme.corner(root, 14)
	Theme.stroke(root, Theme.amber, 2, 0.15)
	Theme.pad(root, 8)

	local gold = Theme.text(root, "Gold", "0g", 18, Theme.amber, Theme.fontTitle)
	gold.Size = UDim2.fromOffset(92, 22)
	gold.TextWrapped = false
	gold.ZIndex = 13

	local cs = Theme.text(root, "CS", "0 CS", 14, Theme.cream, Theme.fontTitle)
	cs.Position = UDim2.fromOffset(96, 2)
	cs.Size = UDim2.fromOffset(72, 20)
	cs.TextWrapped = false
	cs.ZIndex = 13

	local level = Theme.text(root, "Level", "Lv 1", 14, Theme.peach, Theme.fontTitle)
	level.Position = UDim2.fromOffset(172, 2)
	level.Size = UDim2.fromOffset(60, 20)
	level.TextWrapped = false
	level.ZIndex = 13

	local cleave = Theme.text(root, "Cleave", "", 12, Theme.peach, Theme.fontBody)
	cleave.Position = UDim2.fromOffset(0, 24)
	cleave.Size = UDim2.new(1, 0, 0, 16)
	cleave.TextWrapped = false
	cleave.ZIndex = 13

	local buff = Theme.text(root, "EpicBuff", "", 12, Theme.amber, Theme.fontTitle)
	buff.Position = UDim2.fromOffset(0, 42)
	buff.Size = UDim2.new(1, 0, 0, 16)
	buff.TextWrapped = false
	buff.Visible = false
	buff.ZIndex = 13

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
		end,
		update = function(matchPlayer: Types.MatchPlayer, epic: Types.RiverEpicView?)
			local purseGold = matchPlayer.gold or 0
			local purseCs = matchPlayer.cs or 0
			gold.Text = `{purseGold}g`
			cs.Text = `{purseCs} CS`
			level.Text = `Lv {matchPlayer.level or 1}`
			local read = FarmCredit.cleaveRead(
				purseGold,
				ItemKits.owns(matchPlayer.items, ItemKits.CleaveId),
				ItemKits.CLEAVE_COST
			)
			cleave.Text = read.text
			cleave.TextColor3 = TONE_COLOR[read.tone]
			local line = if epic then RiverEpic.purseLine(matchPlayer.team, epic.blueBuff, epic.redBuff) else nil
			buff.Visible = line ~= nil
			buff.Text = line or ""
			local wide = line ~= nil and #line > #RiverEpic.BuffChip
			local width = if wide then 360 else 248
			root.Size = if line ~= nil then UDim2.fromOffset(width, 76) else UDim2.fromOffset(248, 56)
		end,
	}
end

return EconomyChip
