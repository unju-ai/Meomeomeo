--!strict

-- Pure helpers for Cat Rift champion nameplates (name + role/look + HP fill).
-- Server builds the BillboardGui; the client paints fill from Health attributes /
-- Humanoid. Fog rules match AA refuse: enemy plates need vision; allies can stay.
-- Lane-kitten / structure bars stay on Shared.BillboardHp — champions only here.

local BillboardHp = require(script.Parent.BillboardHp)

local ChampionPlate = {}

ChampionPlate.GuiName = "MeoNameplate"
ChampionPlate.ChampName = "Champ"
ChampionPlate.RoleName = "Role"
ChampionPlate.TrackName = BillboardHp.TrackName
ChampionPlate.FillName = BillboardHp.FillName

-- Soft cap: Practice Blue stays at 3 (solo is 1 human + 2 allies) vs 3 Red. Backstop for padded queues.
ChampionPlate.MaxPlates = 12

export type ShowInfo = {
	alive: boolean,
	ally: boolean,
	-- Enemy plate needs vision (same gate as AA refuse). Allies ignore fog.
	inVision: boolean,
}

-- Ally living plates stay up through fog. Enemy plates only while the body is lit.
function ChampionPlate.show(info: ShowInfo): boolean
	if not info.alive then
		return false
	end
	if info.ally then
		return true
	end
	return info.inVision
end

-- Bots keep (Bot). Local YOU is optional and applied on the client only.
function ChampionPlate.nameLine(champName: string, isBot: boolean, isYou: boolean?): string
	local base = if isBot then `{champName} (Bot)` else champName
	if isYou == true then
		return `YOU · {base}`
	end
	return base
end

-- Role stays primary; look label (draft "role · look") is optional second tag.
function ChampionPlate.tagLine(role: string, lookLabel: string?): string
	if typeof(lookLabel) == "string" and lookLabel ~= "" then
		return `{role} · {lookLabel}`
	end
	return role
end

function ChampionPlate.ratio(health: number, maxHealth: number): number
	return BillboardHp.ratio(health, maxHealth)
end

function ChampionPlate.fillTone(ratio: number): BillboardHp.Tone
	return BillboardHp.fillTone(ratio)
end

function ChampionPlate.teamFillRgb(tone: BillboardHp.Tone, team: string?): { number }
	return BillboardHp.teamFillRgb(tone, team)
end

-- Dirty signature so the client can skip paint when nothing meaningful changed.
function ChampionPlate.paintKey(
	health: number,
	maxHealth: number,
	show: boolean,
	nameText: string,
	tagText: string,
	team: string?
): string
	local ratio = math.floor(ChampionPlate.ratio(health, maxHealth) * 100 + 0.5)
	local teamKey = team or "-"
	local flag = if show then "1" else "0"
	return `{flag}|{ratio}|{math.floor(maxHealth + 0.5)}|{teamKey}|{nameText}|{tagText}`
end

return ChampionPlate
