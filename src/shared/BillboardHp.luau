--!strict

-- Pure rules for night-market HP billboards on structures, Canal Levi,
-- lane kittens, and jungle camps. Health stays on the model attributes.
-- The client paints; no new remotes. Champion plates use Shared.ChampionPlate.

local BillboardHp = {}

BillboardHp.GuiName = "MeoHpBar"
BillboardHp.FillName = "Fill"
BillboardHp.CaptionName = "Caption"
BillboardHp.TrackName = "Track"

-- Soft cap: only damaged / aimed / in-combat units get bars, and the pool
-- reuses billboards. This is a backstop if a huge wave is somehow all hurt.
BillboardHp.MaxUnitBars = 28

-- Cream / amber / coral. Not the default Roblox humanoid green.
BillboardHp.Cream = { 255, 243, 224 }
BillboardHp.Amber = { 255, 196, 74 }
BillboardHp.Coral = { 255, 122, 98 }
BillboardHp.Ink = { 52, 36, 32 }
BillboardHp.Track = { 44, 30, 28 }
BillboardHp.Stroke = { 255, 220, 180 }
-- Light team wash on kitten fills (not flat team paint).
BillboardHp.BlueTint = { 130, 175, 230 }
BillboardHp.RedTint = { 235, 130, 125 }

export type Tone = "cream" | "amber" | "coral"

export type StructureShow = {
	alive: boolean,
	ally: boolean,
	-- Fog cell lit at the structure. Ally bars ignore this (stay visible).
	inVision: boolean,
	damaged: boolean,
	-- Cursor aim or auto-attack lock on this structure id.
	aimed: boolean,
}

export type EpicShow = {
	alive: boolean,
	inVision: boolean,
}

export type KittenShow = {
	alive: boolean,
	ally: boolean,
	inVision: boolean,
	damaged: boolean,
	aimed: boolean,
}

export type CampShow = {
	alive: boolean,
	inVision: boolean,
	damaged: boolean,
	-- Cursor aim, AA lock, or camp aggro (InCombat attribute).
	inCombat: boolean,
}

function BillboardHp.ratio(health: number, maxHealth: number): number
	if maxHealth <= 0 then
		return 0
	end
	return math.clamp(health / maxHealth, 0, 1)
end

function BillboardHp.damaged(health: number, maxHealth: number): boolean
	return health > 0 and health < (maxHealth - 0.5)
end

function BillboardHp.formatHp(health: number, maxHealth: number): string
	return `{math.floor(health + 1e-6)} / {math.floor(maxHealth + 1e-6)}`
end

function BillboardHp.fillTone(ratio: number): Tone
	if ratio <= 0.28 then
		return "coral"
	end
	if ratio <= 0.55 then
		return "amber"
	end
	return "cream"
end

function BillboardHp.toneRgb(tone: Tone): { number }
	if tone == "coral" then
		return BillboardHp.Coral
	end
	if tone == "amber" then
		return BillboardHp.Amber
	end
	return BillboardHp.Cream
end

-- Blend fill tone with a light Blue / Red wash for lane kittens.
function BillboardHp.teamFillRgb(tone: Tone, team: string?): { number }
	local base = BillboardHp.toneRgb(tone)
	local wash: { number }?
	if team == "Blue" then
		wash = BillboardHp.BlueTint
	elseif team == "Red" then
		wash = BillboardHp.RedTint
	end
	if wash == nil then
		return base
	end
	local w = wash :: { number }
	local mix = 0.38
	return {
		math.floor(base[1] * (1 - mix) + w[1] * mix + 0.5),
		math.floor(base[2] * (1 - mix) + w[2] * mix + 0.5),
		math.floor(base[3] * (1 - mix) + w[3] * mix + 0.5),
	}
end

-- Ally: damaged or aimed, even through fog. Enemy: only while the body cell is lit.
function BillboardHp.showStructure(info: StructureShow): boolean
	if not info.alive then
		return false
	end
	local want = info.damaged or info.aimed
	if not want then
		return false
	end
	if info.ally then
		return true
	end
	return info.inVision
end

-- Canal Levi: clear epic bar while UP and the living body is in vision.
function BillboardHp.showEpic(info: EpicShow): boolean
	return info.alive and info.inVision
end

-- Lane kitten: small bar when damaged or aimed. Ally through fog; enemy needs vision.
function BillboardHp.showKitten(info: KittenShow): boolean
	if not info.alive then
		return false
	end
	local want = info.damaged or info.aimed
	if not want then
		return false
	end
	if info.ally then
		return true
	end
	return info.inVision
end

-- Jungle camp (pigeon / golem / crab): damaged or in combat, and in vision.
-- Canal Levi stays on showEpic (always while UP in vision).
function BillboardHp.showCamp(info: CampShow): boolean
	if not info.alive then
		return false
	end
	if not (info.damaged or info.inCombat) then
		return false
	end
	return info.inVision
end

function BillboardHp.structureCaption(title: string, hpLine: string, gated: boolean): string
	if gated then
		return `{title}  {hpLine}  (gated)`
	end
	return `{title}  {hpLine}`
end

function BillboardHp.epicCaption(name: string, hpLine: string): string
	return `{name}  {hpLine}`
end

function BillboardHp.campCaption(name: string, hpLine: string): string
	return `{name}  {hpLine}`
end

function BillboardHp.structureTitle(tier: string, lane: string): string
	if tier == "Core" then
		return "Yarn core"
	end
	if tier == "Inner" then
		return `{lane} stall`
	end
	return `{lane} post`
end

return BillboardHp
