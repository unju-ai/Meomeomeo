--!strict

-- Night-market party plan. Two micro-games, three rounds. Not a Fall Guys clone.

export type RoundKind = "Dodge" | "Pillows"

local PLAN: { RoundKind } = { "Dodge", "Pillows", "Dodge" }

local BOT_NAMES = { "LoafBot", "NibBot", "PurrBot" }
local BOT_CHAMPS = { "Shadowpounce", "Bytekit", "ChairmanMeow" }

local YarnPartyCatalog = {
	SeatCount = 4,
	RoundCount = 3,
	CountdownSeconds = 3.2,
	IntroSeconds = 2.15,
	RecapSeconds = 2.4,
	DodgeSeconds = 12,
	PillowSeconds = 14,
	YarnRadius = 3.35,
	JumpSafeY = 4.6,
	WalkSpeed = 20,
	PadRadius = 4.6,
	ArenaHalf = 18,
	Plan = PLAN,
}

function YarnPartyCatalog.roundAt(index: number): RoundKind
	local i = ((math.clamp(math.floor(index), 1, YarnPartyCatalog.RoundCount) - 1) % #PLAN) + 1
	return PLAN[i]
end

function YarnPartyCatalog.kinds(): { RoundKind }
	local seen: { [string]: boolean } = {}
	local out: { RoundKind } = {}
	for _, kind in PLAN do
		if not seen[kind] then
			seen[kind] = true
			table.insert(out, kind)
		end
	end
	return out
end

function YarnPartyCatalog.titleOf(kind: RoundKind): string
	if kind == "Dodge" then
		return "YARN DODGE"
	end
	return "STALL FREEZE"
end

function YarnPartyCatalog.hintOf(kind: RoundKind): string
	if kind == "Dodge" then
		return "Hop the coral yarn · last loaf standing"
	end
	return "When the lanterns blink, stand on a lit pillow"
end

-- Short stream banner under the giant round title (HUD only; fairness unchanged).
function YarnPartyCatalog.ruleBanner(kind: RoundKind): string
	if kind == "Dodge" then
		return "Space hop · last loaf standing"
	end
	return "Lit pillow = safe · lanterns blink"
end

function YarnPartyCatalog.lobbyTitle(secs: number): string
	return `STARTS IN {math.max(0, math.ceil(secs))}`
end

function YarnPartyCatalog.seatRole(isLocal: boolean, isBot: boolean, isOpen: boolean): string
	if isLocal then
		return "YOU"
	elseif isBot then
		return "BOT"
	elseif isOpen then
		return "OPEN"
	end
	return "CAT"
end

function YarnPartyCatalog.seatLine(seat: number, role: string, name: string): string
	return `{seat}  [{role}]  {name}`
end

function YarnPartyCatalog.isElimPop(event: string?): boolean
	if not event or event == "" then
		return false
	end
	return string.find(event, "YARN BONK", 1, true) ~= nil or string.find(event, "WRONG PILLOW", 1, true) ~= nil
end

function YarnPartyCatalog.isRoundTitle(event: string?): boolean
	return event == "YARN DODGE" or event == "STALL FREEZE"
end

function YarnPartyCatalog.podiumWinnerLine(name: string): string
	return `{name}  ·  WINNER`
end

function YarnPartyCatalog.podiumRecapLine(place: number, name: string, score: number, isBot: boolean): string
	local role = if isBot then "BOT" else "CAT"
	return `#{place}  {score}  {name}  {role}`
end

function YarnPartyCatalog.pointsForPlace(place: number): number
	if place == 1 then
		return 3
	elseif place == 2 then
		return 2
	elseif place == 3 then
		return 1
	end
	return 0
end

function YarnPartyCatalog.botName(index: number): string
	return BOT_NAMES[math.clamp(index, 1, #BOT_NAMES)]
end

function YarnPartyCatalog.botChampion(index: number): string
	return BOT_CHAMPS[math.clamp(index, 1, #BOT_CHAMPS)]
end

function YarnPartyCatalog.padOffsets(): { Vector3 }
	return {
		Vector3.new(-11, 0, -11),
		Vector3.new(11, 0, -11),
		Vector3.new(-11, 0, 11),
		Vector3.new(11, 0, 11),
	}
end

function YarnPartyCatalog.spawnOffsets(): { Vector3 }
	return {
		Vector3.new(-13, 3.2, -13),
		Vector3.new(13, 3.2, -13),
		Vector3.new(-13, 3.2, 13),
		Vector3.new(13, 3.2, 13),
	}
end

function YarnPartyCatalog.rankByScore(scores: { { id: number, score: number, alive: boolean } }): { number }
	table.sort(scores, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		if a.alive ~= b.alive then
			return a.alive
		end
		return a.id < b.id
	end)
	local ids = {}
	for _, row in scores do
		table.insert(ids, row.id)
	end
	return ids
end

return YarnPartyCatalog
