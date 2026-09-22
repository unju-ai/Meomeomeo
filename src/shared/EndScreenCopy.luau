--!strict

-- Pure display helpers for the Cat Rift match end screen.
-- Stats math, MVP pick, and Kitty Caster lines stay on the server.

local EndScreenCopy = {}

export type FallBit = {
	team: string,
	tier: string,
	lane: string,
}

export type OutcomeTone = "win" | "loss" | "neutral"

-- Left chip on the end card. Practice (including a Practice remake) offers Again.
-- A live fight (including a remake of a live fight) offers Queue.
export type ReplayChip = "queue" | "again"

local function fallLabel(tier: string, lane: string): string
	if tier == "Core" then
		return "yarn core"
	end
	if tier == "Inner" then
		return `{lane} stall`
	end
	return `{lane} post`
end

function EndScreenCopy.outcomeTitle(won: boolean?, reason: string?): string
	if reason == "remake" then
		return "REMAKE"
	end
	if won == true then
		return "VICTORY"
	elseif won == false then
		return "DEFEAT"
	end
	return "MATCH OVER"
end

function EndScreenCopy.outcomeTone(won: boolean?, reason: string?): OutcomeTone
	if reason == "remake" then
		return "neutral"
	end
	if won == true then
		return "win"
	elseif won == false then
		return "loss"
	end
	return "neutral"
end

function EndScreenCopy.subLine(won: boolean?, winner: string?, reason: string?): string
	if reason == "remake" then
		return "Fight called early"
	end
	local side = winner or "??"
	if reason == "surrender" then
		if won == true then
			return `{side} wins · the other side folded`
		elseif won == false then
			return `{side} wins · your team surrendered`
		end
		return "Surrender signed — match over"
	end
	if won == true then
		return `{side} wins · enemy yarn core unplugged`
	elseif won == false then
		return `{side} wins · your yarn core fell`
	end
	return "Yarn core down — match over"
end

function EndScreenCopy.mvpLine(name: string?, kills: number?, deaths: number?, assists: number?, damage: number?): string
	if not name then
		return "MVP · nobody clawed hard enough"
	end
	local k = kills or 0
	local d = deaths or 0
	local a = assists or 0
	local dmg = math.floor(damage or 0)
	return `MVP · {name} · {k}/{d}/{a} · {dmg} dmg`
end

-- Canal Levi take from the existing riverEpic buff flags (no new remotes).
function EndScreenCopy.leviLine(blueBuff: boolean?, redBuff: boolean?): string?
	if blueBuff and redBuff then
		return "Levi · Blue + Red"
	elseif blueBuff then
		return "Levi · Blue take"
	elseif redBuff then
		return "Levi · Red take"
	end
	return nil
end

local function fallBit(fall: FallBit): string
	return `{fall.team} {fallLabel(fall.tier, fall.lane)}`
end

-- One-glance structure timeline: posts → stalls → core (+ optional Levi).
function EndScreenCopy.timelineLines(falls: { FallBit }?, levi: string?): string
	local posts: { string } = {}
	local stalls: { string } = {}
	local cores: { string } = {}
	for _, fall in falls or {} do
		local bit = fallBit(fall)
		if fall.tier == "Inner" then
			table.insert(stalls, bit)
		elseif fall.tier == "Core" then
			table.insert(cores, bit)
		else
			-- Outer posts (and any unexpected tier) land in the posts lane.
			table.insert(posts, bit)
		end
	end
	local lines: { string } = {}
	if #posts > 0 then
		table.insert(lines, `Posts  {table.concat(posts, " → ")}`)
	end
	if #stalls > 0 then
		table.insert(lines, `Stalls  {table.concat(stalls, " → ")}`)
	end
	if #cores > 0 then
		table.insert(lines, `Core  {table.concat(cores, " → ")}`)
	end
	if #lines == 0 then
		table.insert(lines, "Timeline  no structures down")
	end
	if levi then
		table.insert(lines, levi)
	end
	return table.concat(lines, "\n")
end

function EndScreenCopy.replayChip(practice: boolean?): ReplayChip
	if practice == true then
		return "again"
	end
	return "queue"
end

function EndScreenCopy.difficultyName(difficulty: string?): string
	if difficulty == "Easy" or difficulty == "Hard" or difficulty == "Normal" then
		return difficulty
	end
	-- PlayAgain falls back through the same Normal default. Display only.
	return "Normal"
end

function EndScreenCopy.againLabel(difficulty: string?): string
	return `Again · {EndScreenCopy.difficultyName(difficulty)}`
end

function EndScreenCopy.queueLabel(): string
	return "Queue"
end

function EndScreenCopy.replayLabel(practice: boolean?, difficulty: string?): string
	if EndScreenCopy.replayChip(practice) == "again" then
		return EndScreenCopy.againLabel(difficulty)
	end
	return EndScreenCopy.queueLabel()
end

function EndScreenCopy.rowMark(isLocal: boolean, isMvp: boolean): string
	if isMvp and isLocal then
		return "*YOU"
	elseif isMvp then
		return "*MVP"
	elseif isLocal then
		return " YOU"
	end
	return "    "
end

return EndScreenCopy
