--!strict

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local AbilityBar = {}

export type BarApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (championId: string?, combat: Types.CombatState?, gold: number, kda: string) -> (),
}

function AbilityBar.create(parent: Instance): BarApi
	local root = Instance.new("Frame")
	root.Name = "AbilityBar"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -16)
	root.Size = UDim2.fromOffset(560, 118)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.Parent = parent
	Theme.corner(root, 18)
	Theme.stroke(root, Theme.peach, 2, 0.2)
	Theme.pad(root, 10)

	local meta = Theme.text(root, "Meta", "Champion · 0 / 0 / 0 · 0g", 14, Theme.cream, Theme.fontTitle)
	meta.Size = UDim2.new(1, 0, 0, 20)

	local hp = Instance.new("Frame")
	hp.Name = "HP"
	hp.BackgroundColor3 = Theme.panelAlt
	hp.Position = UDim2.fromOffset(0, 24)
	hp.Size = UDim2.new(1, 0, 0, 10)
	hp.Parent = root
	Theme.corner(hp, 6)
	local hpFill = Instance.new("Frame")
	hpFill.BackgroundColor3 = Theme.good
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.Parent = hp
	Theme.corner(hpFill, 6)

	local mp = Instance.new("Frame")
	mp.Name = "MP"
	mp.BackgroundColor3 = Theme.panelAlt
	mp.Position = UDim2.fromOffset(0, 38)
	mp.Size = UDim2.new(1, 0, 0, 8)
	mp.Parent = root
	Theme.corner(mp, 6)
	local mpFill = Instance.new("Frame")
	mpFill.BackgroundColor3 = Theme.blue
	mpFill.Size = UDim2.fromScale(1, 1)
	mpFill.Parent = mp
	Theme.corner(mpFill, 6)

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 52)
	row.Size = UDim2.new(1, 0, 0, 56)
	row.Parent = root
	Theme.list(row, 8, Enum.FillDirection.Horizontal)

	local slots: { [string]: TextLabel } = {}
	for index, slot in Constants.Slots do
		local cell = Instance.new("Frame")
		cell.Name = slot
		cell.BackgroundColor3 = Theme.panelAlt
		cell.Size = UDim2.new(0.25, -6, 1, 0)
		cell.LayoutOrder = index
		cell.Parent = row
		Theme.corner(cell, 10)
		Theme.stroke(cell, Theme.amber, 1.5, 0.3)
		local label = Theme.text(cell, "L", `{slot}`, 13, Theme.cream, Theme.fontTitle)
		label.Size = UDim2.fromScale(1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextWrapped = true
		slots[slot] = label
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
		end,
		update = function(championId: string?, combat: Types.CombatState?, gold: number, kda: string)
			local champ = if championId then ChampionCatalog.get(championId) else nil
			local shield = if combat then (combat.shield or 0) else 0
			meta.Text = `{(if champ then champ.name else "Cat")} · {kda} · {gold}g`
				.. if shield > 0 then ` · {math.floor(shield)}🛡` else ""
			if combat then
				hpFill.Size = UDim2.fromScale(if combat.maxHealth > 0 then combat.health / combat.maxHealth else 0, 1)
				mpFill.Size = UDim2.fromScale(if combat.maxMana > 0 then combat.mana / combat.maxMana else 0, 1)
				local t = workspace:GetServerTimeNow()
				if champ then
					for _, slot in Constants.Slots do
						local ability = champ.abilities[slot]
						local readyAt = combat.cooldowns[slot]
						local cd = if readyAt then math.max(0, readyAt - t) else 0
						slots[slot].Text = if cd > 0.15
							then `{slot}  {ability.name}\n{string.format("%.1f", cd)}s`
							else `{slot}  {ability.name}`
					end
				end
			end
		end,
	}
end

return AbilityBar
