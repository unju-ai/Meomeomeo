--!strict

-- Pure rules for the Cat Rift fight-begin cue.
-- MatchService.beginFight already sets phase to InProgress and startedAt to
-- the server clock in the same step, then teleports. phaseEndsAt is cleared.
-- There is no pre-roll and no walk freeze. This module only reads that edge.
-- A 3 · 2 · 1 plays only when startedAt is already ~3s ahead. The live stamp
-- is "now", so the cue is a single Fight!. It does not lock input.
-- Hub / Yarn Run / Koi / Party / Arcade stay quiet. Wave and camp clocks stay put.

local MatchStartJuice = {}

-- Night-market cream and amber. Display only.
MatchStartJuice.Cream = { 255, 243, 224 }
MatchStartJuice.Amber = { 255, 196, 74 }
MatchStartJuice.Ink = { 52, 36, 32 }

MatchStartJuice.FightText = "Fight!"
-- Visual hold. The overlay is not Active, and this does not change WalkSpeed.
MatchStartJuice.FightHold = 1.15
MatchStartJuice.GlowSeconds = 0.85
MatchStartJuice.WashSeconds = 0.42

-- Room required before a digit is honest. Shorter than this is not a countdown.
MatchStartJuice.CountdownRoom = 3.05
-- A client that receives the snapshot a moment late still paints. A rejoin does not.
MatchStartJuice.FreshSeconds = 2.5

-- Same pads MapBuilder / FountainRegenJuice already use. Glow only; no radius change.
MatchStartJuice.BlueX = -176
MatchStartJuice.RedX = 176
MatchStartJuice.PadZ = 0
MatchStartJuice.PadY = 0.35

-- Quiet tick under Kitty Caster's existing MatchLive line. Not a new script line.
MatchStartJuice.StingCue = "PingSoft"

export type Kind = "count" | "fight"

export type Cue = {
	text: string,
	kind: Kind,
	glow: boolean,
	sting: boolean,
	startedAt: number,
}

function MatchStartJuice.blocksInput(): boolean
	return false
end

function MatchStartJuice.padX(team: string): number
	if team == "Red" then
		return MatchStartJuice.RedX
	end
	return MatchStartJuice.BlueX
end

-- Cat Rift fight only. Draft, the end screen, and the hub do not get a start cue.
function MatchStartJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

function MatchStartJuice.digit(remain: number): string?
	if remain > 2 and remain <= MatchStartJuice.CountdownRoom then
		return "3"
	end
	if remain > 1 and remain <= 2 then
		return "2"
	end
	if remain > 0 and remain <= 1 then
		return "1"
	end
	return nil
end

local function finite(value: number?): boolean
	return typeof(value) == "number" and value == value
end

-- Keep sampling until the begin cue has painted or the edge is stale.
-- A few milliseconds of clock skew must not drop the only snapshot.
function MatchStartJuice.shouldWatch(
	gameMode: string,
	phase: string?,
	startedAt: number?,
	now: number,
	inRoster: boolean,
	fightShownFor: number?
): boolean
	if not inRoster or not MatchStartJuice.modeAllows(gameMode, phase) then
		return false
	end
	if not finite(startedAt) or not finite(now) then
		return false
	end
	local stamp = startedAt :: number
	if fightShownFor == stamp then
		return false
	end
	local age = (now :: number) - stamp
	if age > MatchStartJuice.FreshSeconds then
		return false
	end
	return true
end

-- fightShownFor: startedAt that already played Fight!.
-- armedFor: startedAt that already showed a digit, so 2 and 1 still resolve.
function MatchStartJuice.decide(
	gameMode: string,
	phase: string?,
	startedAt: number?,
	now: number,
	inRoster: boolean,
	fightShownFor: number?,
	armedFor: number?
): Cue?
	if not inRoster or not MatchStartJuice.modeAllows(gameMode, phase) then
		return nil
	end
	if not finite(startedAt) or not finite(now) then
		return nil
	end
	local stamp = startedAt :: number
	local clock = now :: number
	if fightShownFor == stamp then
		return nil
	end
	local remain = stamp - clock
	local armed = armedFor == stamp
	if remain > 0 then
		-- Digits only after the stamp already left a full 3s, or we are inside that count.
		local full = remain > 2 or armed
		if not full or remain > MatchStartJuice.CountdownRoom then
			return nil
		end
		local text = MatchStartJuice.digit(remain)
		if text == nil then
			return nil
		end
		return {
			text = text,
			kind = "count",
			glow = false,
			sting = false,
			startedAt = stamp,
		}
	end
	local age = clock - stamp
	local fresh = age <= MatchStartJuice.FreshSeconds
	local hitch = armed and age <= MatchStartJuice.FreshSeconds + MatchStartJuice.CountdownRoom
	if not fresh and not hitch then
		return nil
	end
	return {
		text = MatchStartJuice.FightText,
		kind = "fight",
		glow = true,
		sting = true,
		startedAt = stamp,
	}
end

return MatchStartJuice
