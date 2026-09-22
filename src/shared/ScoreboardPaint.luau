--!strict

-- Pure display helpers for the Cat Rift hold-Tab scoreboard.
-- Stats stay on MatchSnapshot; this only styles mid-fight scanability.
-- RGB tables stay Color3-free so smokes can assert without Theme / Instance.

local ScoreboardPaint = {}

ScoreboardPaint.Cream = { 255, 243, 224 }
ScoreboardPaint.Muted = { 122, 92, 80 }
ScoreboardPaint.Peach = { 255, 184, 140 }
ScoreboardPaint.Amber = { 255, 196, 74 }
ScoreboardPaint.Blue = { 86, 148, 230 }
ScoreboardPaint.Red = { 230, 86, 96 }
ScoreboardPaint.Ink = { 52, 36, 32 }
ScoreboardPaint.Panel = { 44, 30, 28 }

-- Items column budget (GothamBold ~ width of the Items header cell).
ScoreboardPaint.ItemsMaxChars = 28

-- Short stall labels so six items fit without eating the row.
local ITEM_SHORT: { [string]: string } = {
	Longclaw = "LC",
	Yarnplate = "YP",
	ManaTreat = "Treat",
	PounceBoots = "Boots",
	WhiskerLens = "Lens",
	ControlYarn = "Pink",
	YarnCleave = "Cleave",
	StallFang = "Fang",
	PaperCharm = "Charm",
}

export type RowKind = "you" | "crown" | "dead" | "alive"

export type RowPaint = {
	kind: RowKind,
	fill: { number },
	stroke: { number },
	text: { number },
	fillAlpha: number,
	strokeAlpha: number,
	textAlpha: number,
}

export type LeadPlayer = {
	userId: number,
	kills: number,
	damageDealt: number?,
	gold: number,
	respawnAt: number?,
}

-- Dead while a future respawnAt is on the snapshot (CombatService / MatchService).
function ScoreboardPaint.isDead(respawnAt: number?, now: number): boolean
	return typeof(respawnAt) == "number" and (respawnAt :: number) > now
end

function ScoreboardPaint.itemShort(id: string): string
	return ITEM_SHORT[id] or id
end

-- Compact item list with ×N stacks; truncates cleanly for the Items column.
function ScoreboardPaint.itemsLine(ids: { string }, maxChars: number?): string
	local budget = maxChars or ScoreboardPaint.ItemsMaxChars
	if #ids == 0 then
		return "—"
	end
	local counts: { [string]: number } = {}
	local order: { string } = {}
	for _, id in ids do
		if not counts[id] then
			table.insert(order, id)
			counts[id] = 0
		end
		counts[id] += 1
	end
	local bits: { string } = {}
	for _, id in order do
		local label = ScoreboardPaint.itemShort(id)
		local n = counts[id]
		table.insert(bits, if n > 1 then `{label}×{n}` else label)
	end
	local full = table.concat(bits, " · ")
	if #full <= budget then
		return full
	end
	-- Drop trailing entries until one fits with an ellipsis.
	while #bits > 1 do
		table.remove(bits)
		local cut = table.concat(bits, " · ") .. "…"
		if #cut <= budget then
			return cut
		end
	end
	local first = bits[1] or "—"
	if #first + 1 <= budget then
		return first .. "…"
	end
	return string.sub(first, 1, math.max(1, budget - 1)) .. "…"
end

-- Champion label: bots tagged, local YOU, optional live-lead ★.
-- afk appends a small chip for teammates. Bots never wear it.
function ScoreboardPaint.catLabel(baseName: string, isBot: boolean, isYou: boolean, isCrown: boolean, afk: boolean?): string
	local name = baseName
	if isBot and not string.find(name, "%(Bot%)") then
		name = `{name} (Bot)`
	end
	local labeled = name
	if isYou and isCrown then
		labeled = `★ YOU · {name}`
	elseif isYou then
		labeled = `YOU · {name}`
	elseif isCrown then
		labeled = `★ {name}`
	end
	if afk == true and not isBot then
		return `{labeled} · AFK`
	end
	return labeled
end

function ScoreboardPaint.sectionTitle(team: string): string
	if team == "Blue" then
		return "BLUE · Whiskers"
	elseif team == "Red" then
		return "RED · Paws"
	end
	return team
end

function ScoreboardPaint.teamRgb(team: string): { number }
	if team == "Blue" then
		return ScoreboardPaint.Blue
	elseif team == "Red" then
		return ScoreboardPaint.Red
	end
	return ScoreboardPaint.Cream
end

-- Soft mid-fight crown from existing kills / damage / gold among living cats.
-- Prefer snapshot.mvpUserId when the match already picked one (end screen).
function ScoreboardPaint.crownUserId(players: { LeadPlayer }, now: number, mvpUserId: number?): number?
	if typeof(mvpUserId) == "number" then
		return mvpUserId
	end
	local best: LeadPlayer? = nil
	local bestAlive = false
	for _, matchPlayer in players do
		local alive = not ScoreboardPaint.isDead(matchPlayer.respawnAt, now)
		if not best then
			best = matchPlayer
			bestAlive = alive
		else
			local better = false
			if alive and not bestAlive then
				better = true
			elseif alive == bestAlive then
				if matchPlayer.kills > best.kills then
					better = true
				elseif matchPlayer.kills == best.kills then
					local dmg = matchPlayer.damageDealt or 0
					local bestDmg = best.damageDealt or 0
					if dmg > bestDmg then
						better = true
					elseif dmg == bestDmg and matchPlayer.gold > best.gold then
						better = true
					end
				end
			end
			if better then
				best = matchPlayer
				bestAlive = alive
			end
		end
	end
	return if best then best.userId else nil
end

function ScoreboardPaint.rowPaint(team: string, isYou: boolean, isDead: boolean, isCrown: boolean): RowPaint
	local teamColor = ScoreboardPaint.teamRgb(team)
	if isYou and isDead then
		-- Still find yourself, but grey the numbers while waiting on fountain.
		return {
			kind = "you",
			fill = ScoreboardPaint.Amber,
			stroke = ScoreboardPaint.Muted,
			text = ScoreboardPaint.Muted,
			fillAlpha = 0.82,
			strokeAlpha = 0.55,
			textAlpha = 0.25,
		}
	end
	if isYou then
		return {
			kind = "you",
			fill = ScoreboardPaint.Amber,
			stroke = ScoreboardPaint.Amber,
			text = ScoreboardPaint.Cream,
			fillAlpha = 0.72,
			strokeAlpha = 0.25,
			textAlpha = 0,
		}
	end
	if isDead then
		return {
			kind = "dead",
			fill = ScoreboardPaint.Panel,
			stroke = ScoreboardPaint.Muted,
			text = ScoreboardPaint.Muted,
			fillAlpha = 0.55,
			strokeAlpha = 0.7,
			textAlpha = 0.35,
		}
	end
	if isCrown then
		return {
			kind = "crown",
			fill = ScoreboardPaint.Peach,
			stroke = ScoreboardPaint.Amber,
			text = teamColor,
			fillAlpha = 0.82,
			strokeAlpha = 0.45,
			textAlpha = 0,
		}
	end
	return {
		kind = "alive",
		fill = ScoreboardPaint.Panel,
		stroke = teamColor,
		text = teamColor,
		fillAlpha = 1,
		strokeAlpha = 1,
		textAlpha = 0,
	}
end

function ScoreboardPaint.totalsLine(
	blueK: number,
	blueCs: number,
	blueG: number,
	redK: number,
	redCs: number,
	redG: number
): string
	return `Blue  {blueK} kills · {blueCs} CS · {blueG}g     Red  {redK} kills · {redCs} CS · {redG}g`
end

return ScoreboardPaint
