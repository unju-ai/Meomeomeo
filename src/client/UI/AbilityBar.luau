--!strict

-- Cat Rift ability bar. QWER + item actives (4/5/6/7) share cooldown sweep,
-- ready flash, and mana-gate tint. Numbers still come from combat.cooldowns /
-- readyAt — this only paints.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local ItemKits = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ItemKits"))
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

local FLASH_SECONDS = 0.38
local COOLING_EPS = 0.15
local SWEEP_TRANSPARENCY = 0.42
local READY_BG = Theme.panelAlt
local COOLING_BG = Color3.fromRGB(48, 34, 32)
local MANA_BG = Color3.fromRGB(92, 48, 44)
local UNLEARNED_BG = Color3.fromRGB(52, 38, 36)

type SlotPaint = {
	cell: Frame,
	label: TextLabel,
	sweep: Frame,
	flash: Frame,
	stroke: UIStroke,
	readyAt: number,
	duration: number,
	cooling: boolean,
	flashUntil: number,
	manaLow: boolean,
	usable: boolean,
	readyTextColor: Color3,
}

local function makeSlot(parent: Instance, name: string, size: UDim2, layoutOrder: number?, tall: boolean): SlotPaint
	local cell = Instance.new("Frame")
	cell.Name = name
	cell.BackgroundColor3 = READY_BG
	cell.BackgroundTransparency = 0.05
	cell.Size = size
	cell.ClipsDescendants = true
	cell.Active = false
	if layoutOrder ~= nil then
		cell.LayoutOrder = layoutOrder
	end
	cell.Parent = parent
	Theme.corner(cell, if tall then 10 else 8)
	local stroke = Theme.stroke(cell, Theme.amber, if tall then 1.5 else 1.25, 0.3)

	-- Progressive dim from the top while cooling. Active=false so it never eats clicks.
	local sweep = Instance.new("Frame")
	sweep.Name = "CdSweep"
	sweep.BackgroundColor3 = Theme.ink
	sweep.BackgroundTransparency = SWEEP_TRANSPARENCY
	sweep.BorderSizePixel = 0
	sweep.AnchorPoint = Vector2.new(0, 0)
	sweep.Position = UDim2.fromScale(0, 0)
	sweep.Size = UDim2.fromScale(1, 0)
	sweep.Visible = false
	sweep.Active = false
	sweep.ZIndex = 2
	sweep.Parent = cell
	Theme.corner(sweep, if tall then 10 else 8)

	local flash = Instance.new("Frame")
	flash.Name = "ReadyFlash"
	flash.BackgroundColor3 = Theme.mint
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.Visible = false
	flash.Active = false
	flash.ZIndex = 3
	flash.Parent = cell
	Theme.corner(flash, if tall then 10 else 8)

	local label = Theme.text(cell, "L", name, if tall then 13 else 12, Theme.cream, Theme.fontTitle)
	label.Size = UDim2.fromScale(1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextWrapped = true
	label.ZIndex = 4
	label.Active = false

	return {
		cell = cell,
		label = label,
		sweep = sweep,
		flash = flash,
		stroke = stroke,
		readyAt = 0,
		duration = 1,
		cooling = false,
		flashUntil = 0,
		manaLow = false,
		usable = false,
		readyTextColor = Theme.cream,
	}
end

local function noteReadyAt(slot: SlotPaint, readyAt: number, now: number, fallbackDuration: number?)
	local left = math.max(0, readyAt - now)
	if readyAt > slot.readyAt + 0.05 and left > COOLING_EPS then
		local guessed = if fallbackDuration and fallbackDuration > 0 then fallbackDuration else left
		slot.duration = math.max(left, guessed)
	elseif left > slot.duration then
		slot.duration = left
	elseif slot.duration < 0.05 then
		slot.duration = math.max(left, fallbackDuration or 1)
	end
	slot.readyAt = readyAt
end

local function paintSlotFrame(slot: SlotPaint, now: number)
	local left = math.max(0, slot.readyAt - now)
	local cooling = slot.usable and left > COOLING_EPS
	if slot.cooling and not cooling and slot.usable and not slot.manaLow then
		slot.flashUntil = now + FLASH_SECONDS
	end
	slot.cooling = cooling

	if cooling then
		local total = math.max(slot.duration, left, 0.05)
		slot.sweep.Visible = true
		slot.sweep.Size = UDim2.fromScale(1, math.clamp(left / total, 0, 1))
		slot.cell.BackgroundColor3 = COOLING_BG
		slot.stroke.Color = Theme.muted
		slot.stroke.Transparency = 0.45
		slot.label.TextColor3 = slot.readyTextColor
	else
		slot.sweep.Visible = false
		slot.sweep.Size = UDim2.fromScale(1, 0)
		if not slot.usable then
			slot.cell.BackgroundColor3 = UNLEARNED_BG
			slot.stroke.Color = Theme.muted
			slot.stroke.Transparency = 0.55
			slot.label.TextColor3 = Theme.muted
		elseif slot.manaLow then
			slot.cell.BackgroundColor3 = MANA_BG
			slot.stroke.Color = Theme.coral
			slot.stroke.Transparency = 0.2
			slot.label.TextColor3 = Theme.coral
		else
			slot.cell.BackgroundColor3 = READY_BG
			slot.stroke.Color = Theme.amber
			slot.stroke.Transparency = 0.3
			slot.label.TextColor3 = slot.readyTextColor
		end
	end

	local flashLeft = slot.flashUntil - now
	if flashLeft > 0 and slot.usable and not slot.manaLow then
		local u = flashLeft / FLASH_SECONDS
		slot.flash.Visible = true
		slot.flash.BackgroundTransparency = 0.35 + 0.55 * (1 - u)
		slot.stroke.Color = Theme.mint
		slot.stroke.Transparency = 0.15
	else
		slot.flash.Visible = false
		slot.flash.BackgroundTransparency = 1
		if flashLeft <= 0 then
			slot.flashUntil = 0
		end
	end
end

function AbilityBar.create(parent: Instance): BarApi
	local root = Instance.new("Frame")
	root.Name = "AbilityBar"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -16)
	root.Size = UDim2.fromOffset(640, 168)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.Active = false
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

	local abilitySlots: { [string]: SlotPaint } = {}
	for index, slotName in Constants.Slots do
		abilitySlots[slotName] = makeSlot(row, slotName, UDim2.new(0.25, -6, 1, 0), index, true)
	end

	local tools = Instance.new("Frame")
	tools.BackgroundTransparency = 1
	tools.Position = UDim2.fromOffset(0, 120)
	tools.Size = UDim2.new(1, 0, 0, 28)
	tools.Parent = root
	Theme.list(tools, 8, Enum.FillDirection.Horizontal)

	local trinket = makeSlot(tools, "T4", UDim2.new(0.25, -6, 1, 0), 1, false)
	trinket.label.Text = "4  Ward"
	local lens = makeSlot(tools, "T5", UDim2.new(0.25, -6, 1, 0), 2, false)
	lens.label.Text = "5  Lens"
	local pink = makeSlot(tools, "T6", UDim2.new(0.25, -6, 1, 0), 3, false)
	pink.label.Text = "6  Pink"
	pink.readyTextColor = Theme.pink
	pink.label.TextColor3 = Theme.pink
	local cleave = makeSlot(tools, "T7", UDim2.new(0.25, -6, 1, 0), 4, false)
	cleave.label.Text = "7  Cleave"

	local itemSlots = { trinket, lens, pink, cleave }

	local recallBar = Instance.new("Frame")
	recallBar.Name = "Recall"
	recallBar.BackgroundColor3 = Theme.panelAlt
	recallBar.Position = UDim2.fromOffset(0, -22)
	recallBar.Size = UDim2.new(1, 0, 0, 10)
	recallBar.Visible = false
	recallBar.ZIndex = 4
	recallBar.Parent = root
	Theme.corner(recallBar, 6)
	local recallFill = Instance.new("Frame")
	recallFill.BackgroundColor3 = Theme.mint
	recallFill.Size = UDim2.fromScale(0, 1)
	recallFill.ZIndex = 5
	recallFill.Parent = recallBar
	Theme.corner(recallFill, 6)
	local recallLabel = Theme.text(root, "RecallLabel", "", 12, Theme.mint, Theme.fontTitle)
	recallLabel.Position = UDim2.fromOffset(0, -40)
	recallLabel.Size = UDim2.new(1, 0, 0, 16)
	recallLabel.TextXAlignment = Enum.TextXAlignment.Center
	recallLabel.Visible = false
	recallLabel.ZIndex = 5

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

	local function tickFrames()
		if not root.Visible then
			return
		end
		local now = Workspace:GetServerTimeNow()
		for _, slotName in Constants.Slots do
			paintSlotFrame(abilitySlots[slotName], now)
		end
		for _, slot in itemSlots do
			paintSlotFrame(slot, now)
		end
	end

	RunService.RenderStepped:Connect(tickFrames)

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if not visible then
				death.Visible = false
				recallBar.Visible = false
				recallLabel.Visible = false
			end
		end,
		update = function(matchPlayer: Types.MatchPlayer, combat: Types.CombatState?)
			local champ = if matchPlayer.championId then ChampionCatalog.get(matchPlayer.championId) else nil
			local level = matchPlayer.level or 1
			local _, into, need = Progression.progress(matchPlayer.xp or 0)
			local shield = if combat then (combat.shield or 0) else 0
			local aaBit = ""
			if combat then
				local waitAA = (combat.nextAutoAttack or 0) - Workspace:GetServerTimeNow()
				if waitAA > 0.05 then
					aaBit = ` · AA {string.format("%.1f", waitAA)}s`
				elseif combat.attackTarget then
					aaBit = ` · AA {combat.attackTarget}`
				end
			end
			local guardBit = ""
			if combat and combat.guardUntil and combat.guardUntil > Workspace:GetServerTimeNow() then
				guardBit = " · Guard"
			end
			local wickBit = ""
			if combat and combat.wickUntil and combat.wickStacks and combat.wickUntil > Workspace:GetServerTimeNow() and combat.wickStacks > 0 then
				wickBit = ` · Wick {combat.wickStacks}`
			end
			local dataBit = ""
			if combat and combat.dataUntil and combat.dataStacks and combat.dataUntil > Workspace:GetServerTimeNow() and combat.dataStacks > 0 then
				dataBit = ` · Data {combat.dataStacks}`
			end
			local bleedBit = ""
			if combat and combat.bleedEchoUntil and combat.bleedEchoStacks and combat.bleedEchoUntil > Workspace:GetServerTimeNow() and combat.bleedEchoStacks > 0 then
				bleedBit = ` · Bleed {combat.bleedEchoStacks}`
			end
			local markBit = ""
			if combat and combat.markUntil and combat.markUntil > Workspace:GetServerTimeNow() then
				markBit = " · Mark"
			end
			local vanishBit = ""
			if combat and combat.vanishUntil and combat.vanishUntil > Workspace:GetServerTimeNow() then
				vanishBit = " · Vanish"
			end
			local plateBit = ""
			if combat and combat.plateUntil and combat.plateStacks and combat.plateUntil > Workspace:GetServerTimeNow() and combat.plateStacks > 0 then
				plateBit = ` · Plate {combat.plateStacks}`
			end
			local omenBit = ""
			if combat and combat.omenUntil and combat.omenUntil > Workspace:GetServerTimeNow() then
				omenBit = " · Omen"
			end
			local chargeBit = ""
			if combat and combat.chargeUntil and combat.chargeStacks and combat.chargeUntil > Workspace:GetServerTimeNow() and combat.chargeStacks > 0 then
				chargeBit = ` · Charge {combat.chargeStacks}`
			end
			local curseBit = ""
			if combat and combat.curseEchoUntil and combat.curseEchoStacks and combat.curseEchoUntil > Workspace:GetServerTimeNow() and combat.curseEchoStacks > 0 then
				curseBit = ` · Curse {combat.curseEchoStacks}`
			elseif combat and combat.curseUntil and combat.curseStacks and combat.curseUntil > Workspace:GetServerTimeNow() and combat.curseStacks > 0 then
				curseBit = ` · Curse {combat.curseStacks}`
			end
			local psiBit = ""
			if combat and combat.psiUntil and combat.psiUntil > Workspace:GetServerTimeNow() then
				psiBit = " · Psi"
			end
			local charmBit = ""
			if combat then
				charmBit = ItemKits.charmHud(
					ItemKits.owns(matchPlayer.items, ItemKits.CharmId),
					Workspace:GetServerTimeNow(),
					combat.charmUntil,
					combat.charmReadyAt
				)
			end
			meta.Text = `{(if champ then champ.name else "Cat")}`
				.. guardBit
				.. wickBit
				.. dataBit
				.. bleedBit
				.. markBit
				.. vanishBit
				.. plateBit
				.. omenBit
				.. chargeBit
				.. curseBit
				.. psiBit
				.. charmBit
				.. if shield > 0 then ` · {math.floor(shield)}🛡` else ""
				.. ` · Lv {level} · {matchPlayer.kills} / {matchPlayer.deaths} / {matchPlayer.assists} · {matchPlayer.cs or 0} CS · {matchPlayer.gold}g`
				.. aaBit
			xpFill.Size = UDim2.fromScale(if need > 0 then into / need else 1, 1)
			if combat then
				hpFill.Size = UDim2.fromScale(if combat.maxHealth > 0 then combat.health / combat.maxHealth else 0, 1)
				mpFill.Size = UDim2.fromScale(if combat.maxMana > 0 then combat.mana / combat.maxMana else 0, 1)
				local t = Workspace:GetServerTimeNow()
				local ranks = combat.ranks or matchPlayer.ranks or Progression.emptyRanks()
				if champ then
					for _, slotName in Constants.Slots do
						local ability = champ.abilities[slotName]
						local paint = abilitySlots[slotName]
						local readyAt = combat.cooldowns[slotName] or 0
						local cd = math.max(0, readyAt - t)
						local rank = ranks[slotName] or 0
						local rankBit = if rank > 0 then ` {rank}` else " —"
						local manaCost = if ability then ability.manaCost else 0
						local fallback = if ability then ability.cooldown else nil
						noteReadyAt(paint, readyAt, t, fallback)
						paint.usable = rank > 0
						paint.manaLow = paint.usable and manaCost > 0 and combat.mana < manaCost
						if rank <= 0 then
							paint.label.Text = `{slotName}{rankBit}\n{if slotName == "R" then "Lv 6" else "soon"}`
						elseif ability and cd > COOLING_EPS then
							paint.label.Text = `{slotName}{rankBit}  {ability.name}\n{string.format("%.1f", cd)}s`
						elseif ability then
							paint.label.Text = `{slotName}{rankBit}  {ability.name}`
						else
							paint.label.Text = `{slotName}{rankBit}`
						end
					end
				end
				if not combat.alive then
					local left = math.max(0, (combat.respawnAt or matchPlayer.respawnAt or t) - t)
					death.Visible = true
					death.Text = `Respawn at fountain · {string.format("%.1f", left)}s`
					recallBar.Visible = false
					recallLabel.Visible = false
				elseif combat.channelEndsAt and combat.channelEndsAt > t then
					death.Visible = false
					local ends = combat.channelEndsAt
					local started = combat.channelStartedAt or ends
					local total = math.max(0.1, ends - started)
					local left = math.max(0, ends - t)
					local elapsed = math.clamp(t - started, 0, total)
					local channelName = "Beam"
					if champ and combat.channelSlot then
						local channelAbility = champ.abilities[combat.channelSlot]
						if channelAbility then
							channelName = channelAbility.name
						end
					end
					recallBar.Visible = true
					recallLabel.Visible = true
					recallFill.BackgroundColor3 = Theme.pink
					recallFill.Size = UDim2.fromScale(elapsed / total, 1)
					recallLabel.Text = `{channelName} · {string.format("%.1f", left)}s  (move or hit cancels)`
				elseif combat.recalling then
					death.Visible = false
					local ends = combat.recallEndsAt or t
					local started = combat.recallStartedAt or (ends - 7)
					local total = math.max(0.1, ends - started)
					local left = math.max(0, ends - t)
					local elapsed = math.clamp(t - started, 0, total)
					recallBar.Visible = true
					recallLabel.Visible = true
					recallFill.BackgroundColor3 = Theme.mint
					recallFill.Size = UDim2.fromScale(elapsed / total, 1)
					recallLabel.Text = `Recalling · {string.format("%.1f", left)}s  (move or click cancels)`
				else
					death.Visible = false
					recallBar.Visible = false
					recallLabel.Visible = false
				end

				local trinketReadyAt = combat.trinketReadyAt or 0
				local trinketCd = math.max(0, trinketReadyAt - t)
				noteReadyAt(trinket, trinketReadyAt, t, 70)
				trinket.usable = true
				trinket.manaLow = false
				trinket.label.Text = if trinketCd > COOLING_EPS
					then `4  Ward  {string.format("%.0f", trinketCd)}s`
					else "4  Ward  ready"

				local hasLens = false
				for _, id in matchPlayer.items do
					if id == "WhiskerLens" then
						hasLens = true
						break
					end
				end
				local lensReadyAt = combat.lensReadyAt or 0
				local lensCd = math.max(0, lensReadyAt - t)
				noteReadyAt(lens, lensReadyAt, t, 75)
				lens.usable = hasLens
				lens.manaLow = false
				if not hasLens then
					lens.label.Text = "5  Lens  (buy)"
					lens.readyAt = 0
					lens.cooling = false
				elseif lensCd > COOLING_EPS then
					lens.label.Text = `5  Lens  {string.format("%.0f", lensCd)}s`
				else
					lens.label.Text = "5  Lens  ready"
				end

				local pinkCount = 0
				for _, id in matchPlayer.items do
					if id == "ControlYarn" then
						pinkCount += 1
					end
				end
				pink.usable = pinkCount > 0
				pink.manaLow = false
				pink.readyAt = 0
				pink.cooling = false
				if pinkCount <= 0 then
					pink.label.Text = "6  Pink  (buy)"
				else
					pink.label.Text = `6  Pink  ×{pinkCount}`
				end

				local ownsCleave = ItemKits.owns(matchPlayer.items, ItemKits.CleaveId)
				local cleaveReadyAt = combat.cleaveReadyAt or 0
				noteReadyAt(cleave, cleaveReadyAt, t, ItemKits.CLEAVE_COOLDOWN)
				cleave.usable = ownsCleave
				cleave.manaLow = false
				cleave.label.Text = ItemKits.cleaveHud(ownsCleave, t, cleaveReadyAt)
				if not ownsCleave then
					cleave.readyAt = 0
					cleave.cooling = false
				end

				tickFrames()
			else
				death.Visible = false
				recallBar.Visible = false
				recallLabel.Visible = false
				for _, slotName in Constants.Slots do
					local paint = abilitySlots[slotName]
					paint.usable = false
					paint.manaLow = false
					paint.readyAt = 0
					paint.cooling = false
				end
				for _, slot in itemSlots do
					slot.usable = false
					slot.manaLow = false
					slot.readyAt = 0
					slot.cooling = false
				end
			end
		end,
	}
end

return AbilityBar
