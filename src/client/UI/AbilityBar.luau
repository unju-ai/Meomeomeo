--!strict

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Progression = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Progression"))
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local AbilityBar = {}

export type BarApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (matchPlayer: Types.MatchPlayer, combat: Types.CombatState?) -> (),
}

function AbilityBar.create(parent: Instance): BarApi
	local root = Instance.new("Frame")
	root.Name = "AbilityBar"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -16)
	root.Size = UDim2.fromOffset(560, 136)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.Parent = parent
	Theme.corner(root, 18)
	Theme.stroke(root, Theme.peach, 2, 0.2)
	Theme.pad(root, 10)

	local meta = Theme.text(root, "Meta", "Champion · Lv 1 · 0 / 0 / 0 · 0g", 14, Theme.cream, Theme.fontTitle)
	meta.Size = UDim2.new(1, 0, 0, 18)

	local hp = Instance.new("Frame")
	hp.Name = "HP"
	hp.BackgroundColor3 = Theme.panelAlt
	hp.Position = UDim2.fromOffset(0, 22)
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
	mp.Position = UDim2.fromOffset(0, 36)
	mp.Size = UDim2.new(1, 0, 0, 8)
	mp.Parent = root
	Theme.corner(mp, 6)
	local mpFill = Instance.new("Frame")
	mpFill.BackgroundColor3 = Theme.blue
	mpFill.Size = UDim2.fromScale(1, 1)
	mpFill.Parent = mp
	Theme.corner(mpFill, 6)

	local xp = Instance.new("Frame")
	xp.Name = "XP"
	xp.BackgroundColor3 = Theme.panelAlt
	xp.Position = UDim2.fromOffset(0, 48)
	xp.Size = UDim2.new(1, 0, 0, 6)
	xp.Parent = root
	Theme.corner(xp, 6)
	local xpFill = Instance.new("Frame")
	xpFill.BackgroundColor3 = Theme.amber
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.Parent = xp
	Theme.corner(xpFill, 6)

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 60)
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

	local death = Theme.text(root, "Death", "", 16, Theme.coral, Theme.fontTitle)
	death.AnchorPoint = Vector2.new(0.5, 0.5)
	death.Position = UDim2.fromScale(0.5, 0.5)
	death.Size = UDim2.new(1, -16, 0, 28)
	death.TextXAlignment = Enum.TextXAlignment.Center
	death.BackgroundColor3 = Theme.ink
	death.BackgroundTransparency = 0.2
	death.Visible = false
	death.ZIndex = 5
	Theme.corner(death, 10)

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if not visible then
				death.Visible = false
			end
		end,
		update = function(matchPlayer: Types.MatchPlayer, combat: Types.CombatState?)
			local champ = if matchPlayer.championId then ChampionCatalog.get(matchPlayer.championId) else nil
			local level = matchPlayer.level or 1
			local _, into, need = Progression.progress(matchPlayer.xp or 0)
			local shield = if combat then (combat.shield or 0) else 0
			local aaBit = ""
			if combat then
				local waitAA = (combat.nextAutoAttack or 0) - workspace:GetServerTimeNow()
				if waitAA > 0.05 then
					aaBit = ` · AA {string.format("%.1f", waitAA)}s`
				elseif combat.attackTarget then
					aaBit = ` · AA {combat.attackTarget}`
				end
			end
			meta.Text = `{(if champ then champ.name else "Cat")} · Lv {level} · {matchPlayer.kills} / {matchPlayer.deaths} / {matchPlayer.assists} · {matchPlayer.cs or 0} CS · {matchPlayer.gold}g`
				.. if shield > 0 then ` · {math.floor(shield)}🛡` else ""
				.. aaBit
			xpFill.Size = UDim2.fromScale(if need > 0 then into / need else 1, 1)
			if combat then
				hpFill.Size = UDim2.fromScale(if combat.maxHealth > 0 then combat.health / combat.maxHealth else 0, 1)
				mpFill.Size = UDim2.fromScale(if combat.maxMana > 0 then combat.mana / combat.maxMana else 0, 1)
				local t = workspace:GetServerTimeNow()
				local ranks = combat.ranks or matchPlayer.ranks or Progression.emptyRanks()
				if champ then
					for _, slot in Constants.Slots do
						local ability = champ.abilities[slot]
						local readyAt = combat.cooldowns[slot]
						local cd = if readyAt then math.max(0, readyAt - t) else 0
						local rank = ranks[slot] or 0
						local rankBit = if rank > 0 then ` {rank}` else " —"
						if rank <= 0 then
							slots[slot].Text = `{slot}{rankBit}\n{if slot == "R" then "Lv 6" else "soon"}`
						elseif cd > 0.15 then
							slots[slot].Text = `{slot}{rankBit}  {ability.name}\n{string.format("%.1f", cd)}s`
						else
							slots[slot].Text = `{slot}{rankBit}  {ability.name}`
						end
					end
				end
				if not combat.alive then
					local left = math.max(0, (combat.respawnAt or matchPlayer.respawnAt or t) - t)
					death.Visible = true
					death.Text = `Respawn at fountain · {string.format("%.1f", left)}s`
				else
					death.Visible = false
				end
			else
				death.Visible = false
			end
		end,
	}
end

return AbilityBar
