--!strict

-- Pure helpers for Cat Rift Canal Levi take / buff juice.
-- Spawn at 3:00, the one return, HP, and the non-stacking +8% stay in RiverEpic.
-- The client only paints the match snapshot the purse chip already reads.
-- Hub / Yarn Run / Koi / Party / Arcade stay quiet.

local RiverEpic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RiverEpic"))

local RiverEpicJuice = {}

export type TeamName = "Blue" | "Red"
export type CueKind = "local" | "ally" | "enemy" | "none"
export type Rgb = { number }

-- Night-market cream (Blue take) and coral (Red take). Not a second buff.
RiverEpicJuice.Cream = { 255, 243, 224 }
RiverEpicJuice.Coral = { 255, 122, 98 }

-- Display only. These do not change Levi's HP, leash, or respawn.
RiverEpicJuice.BurstSeconds = 0.42
RiverEpicJuice.BurstScale = 4.4
RiverEpicJuice.RingRadius = 7
RiverEpicJuice.MoteCount = 4
RiverEpicJuice.GroundY = 1.2

export type Watch = {
	matchId: string?,
	seen: boolean,
	phase: string?,
	blue: boolean,
	red: boolean,
}

function RiverEpicJuice.blank(): Watch
	return {
		matchId = nil,
		seen = false,
		phase = nil,
		blue = false,
		red = false,
	}
end

-- Cat Rift fight only. A take during Ended does not happen; rims clear with the match.
function RiverEpicJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

function RiverEpicJuice.pitX(): number
	return RiverEpic.X
end

function RiverEpicJuice.pitZ(): number
	return RiverEpic.Z
end

function RiverEpicJuice.tint(team: string): Rgb
	if team == "Red" then
		return RiverEpicJuice.Coral
	end
	return RiverEpicJuice.Cream
end

-- Same flags as RiverEpic.purseLine / CombatService epicOutgoing. Not a new buff.
function RiverEpicJuice.holds(team: string, blue: boolean, red: boolean): boolean
	if team == "Blue" then
		return blue
	end
	if team == "Red" then
		return red
	end
	return false
end

-- Living champions only. An explicit combat alive flag wins (local cat).
-- Peers use the roster respawn stamp: a future stamp means they are down.
function RiverEpicJuice.isLiving(alive: boolean?, respawnAt: number?, now: number): boolean
	if alive == true then
		return true
	end
	if alive == false then
		return false
	end
	if typeof(respawnAt) == "number" and respawnAt > now then
		return false
	end
	return true
end

-- One death snapshot carries the phase leave AND the post-grant flags
-- (JungleService publishes them together). A new flag is that team's take.
-- A second take on the same side does not flip a flag; the side that already
-- held is the tint. Wakes (into alive) are not takes.
function RiverEpicJuice.takeTeam(
	prevPhase: string?,
	nextPhase: string,
	prevBlue: boolean,
	prevRed: boolean,
	nextBlue: boolean,
	nextRed: boolean
): TeamName?
	if prevPhase ~= "alive" then
		return nil
	end
	if nextPhase ~= "returning" and nextPhase ~= "spent" then
		return nil
	end
	local gainedBlue = nextBlue and not prevBlue
	local gainedRed = nextRed and not prevRed
	if gainedBlue and not gainedRed then
		return "Blue"
	end
	if gainedRed and not gainedBlue then
		return "Red"
	end
	if prevBlue and not prevRed and nextBlue and not nextRed then
		return "Blue"
	end
	if prevRed and not prevBlue and nextRed and not nextBlue then
		return "Red"
	end
	return nil
end

-- First snapshot of a match only seeds. Later diffs can burst once.
function RiverEpicJuice.observe(
	watch: Watch,
	matchId: string?,
	phase: string,
	blue: boolean,
	red: boolean
): (Watch, TeamName?)
	if not watch.seen or watch.matchId ~= matchId then
		return {
			matchId = matchId,
			seen = true,
			phase = phase,
			blue = blue,
			red = red,
		}, nil
	end
	local team = RiverEpicJuice.takeTeam(watch.phase, phase, watch.blue, watch.red, blue, red)
	return {
		matchId = matchId,
		seen = true,
		phase = phase,
		blue = blue,
		red = red,
	}, team
end

-- Ally-side takes always paint (you already know your team cashed it).
-- Enemy takes paint only when the pit is in vision now, or was on the previous mask.
function RiverEpicJuice.shouldPaintTake(allySide: boolean, pitLit: boolean, pitWasLit: boolean?): boolean
	if allySide then
		return true
	end
	if pitLit then
		return true
	end
	return pitWasLit == true
end

-- Local always. Allies stay visible with their bodies. Enemies only while fog-lit.
-- Dead cats and teams that do not hold the buff get no rim.
function RiverEpicJuice.rimCue(
	localUserId: number,
	targetUserId: number,
	sameTeam: boolean,
	inVision: boolean,
	living: boolean,
	teamHolds: boolean
): CueKind
	if not living or not teamHolds then
		return "none"
	end
	if localUserId == targetUserId then
		return "local"
	end
	if sameTeam then
		return "ally"
	end
	if inVision then
		return "enemy"
	end
	return "none"
end

function RiverEpicJuice.shouldPaintRim(cue: string): boolean
	return cue == "local" or cue == "ally" or cue == "enemy"
end

-- Local outline is a bit clearer. Still calm — not a level-up flash.
function RiverEpicJuice.outlineTransparency(cue: string): number
	if cue == "local" then
		return 0.18
	end
	if cue == "ally" then
		return 0.5
	end
	return 0.68
end

function RiverEpicJuice.fillTransparency(cue: string): number
	if cue == "local" then
		return 0.86
	end
	if cue == "ally" then
		return 0.95
	end
	return 0.97
end

-- The purse chip is the lasting text. Do not float +8% on a timer.
function RiverEpicJuice.wantsFloat(_cue: string): boolean
	return false
end

-- Kitty Caster already calls the take. A real flag drop would be the only toast.
function RiverEpicJuice.casterCoversTake(): boolean
	return true
end

function RiverEpicJuice.lossLine(held: boolean, holdsNow: boolean, casterSpoke: boolean): string?
	if held and not holdsNow and not casterSpoke then
		return "Levi buff faded"
	end
	return nil
end

return RiverEpicJuice
