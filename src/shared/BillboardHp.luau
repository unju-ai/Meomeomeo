--!strict

-- Pure rules for night-market HP billboards on structures and Canal Levi.
-- Health stays on the model attributes. The client paints; no new remotes.
-- Champion nameplates and lane-kitten bars stay on their own paths.

local BillboardHp = {}

BillboardHp.GuiName = "MeoHpBar"
BillboardHp.FillName = "Fill"
BillboardHp.CaptionName = "Caption"
BillboardHp.TrackName = "Track"

-- Cream / amber / coral. Not the default Roblox humanoid green.
BillboardHp.Cream = { 255, 243, 224 }
BillboardHp.Amber = { 255, 196, 74 }
BillboardHp.Coral = { 255, 122, 98 }
BillboardHp.Ink = { 52, 36, 32 }
BillboardHp.Track = { 44, 30, 28 }
BillboardHp.Stroke = { 255, 220, 180 }

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

function BillboardHp.structureCaption(title: string, hpLine: string, gated: boolean): string
	if gated then
		return `{title}  {hpLine}  (gated)`
	end
	return `{title}  {hpLine}`
end

function BillboardHp.epicCaption(name: string, hpLine: string): string
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
