--!strict

-- Authored Kitty Caster callouts. No network and no LLM.
-- AnnouncerService owns the match clock; this module only picks the line
-- and decides which beats a minion war is allowed to say out loud.

local AnnouncerLines = {}

-- Ordinary champion kills share this gap so a lane brawl does not monologue.
AnnouncerLines.OrdinaryCooldown = 8
-- Same cat, this many seconds: double through penta.
AnnouncerLines.StreakWindow = 10

export type Cause = "champion" | "minion" | "tower" | "jungle"

export type StreakRow = {
	count: number,
	at: number,
}

export type Callout = {
	speak: boolean,
	beat: string?,
	line: string?,
	cue: string?,
	priority: boolean,
}

export type KillQuery = {
	now: number,
	firstBloodTaken: boolean,
	cause: string,
	streak: number,
	ace: boolean,
	lastOrdinaryAt: number?,
	killer: string?,
	victim: string,
	victimTeam: string?,
	finisher: string?,
	roll: number?,
}

export type StructureQuery = {
	kind: string,
	tier: string,
	team: string,
	lane: string,
	who: string?,
	coreOpened: boolean,
	roll: number?,
}

local LINES: { [string]: { string } } = {
	FirstBlood = {
		"FIRST BLOOD — {killer} just IPO'd {victim}.",
		"FIRST BLOOD — {killer} opened {victim} like a market gap.",
	},
	FirstBloodLane = {
		"FIRST BLOOD — lane kittens liquidated {victim}.",
		"FIRST BLOOD — {victim} donated it to the lane kittens.",
	},
	ChampionKill = {
		"{killer} deleted {victim}. The chart says thanks.",
		"{killer} sent {victim} to the fountain. Brutal.",
	},
	TowerKill = {
		"{victim} facetanked a scratching post.",
		"{victim} tried to 1v1 a post. The post is up.",
	},
	DoubleKill = {
		"DOUBLE KILL — {killer} printed a second candle.",
		"DOUBLE KILL — {killer} is two-for-two. Pause. Don't.",
	},
	TripleKill = {
		"TRIPLE KILL — {killer}. Three bags. No water break.",
		"TRIPLE KILL — {killer} will not stop clicking buy.",
	},
	QuadraKill = {
		"QUADRA — {killer} is a meme stock with claws.",
		"QUADRA KILL — {killer}. Four down. I am vibrating.",
	},
	PentaKill = {
		"PENTA — {killer} wiped the order book.",
		"PENTA KILL — {killer}. Halt the tape. I am screaming.",
	},
	Ace = {
		"ACE — {team} is a ghost town. {finisher} took the last cat.",
		"ACE — {team} has no cats left. {finisher} closed them.",
	},
	AceLane = {
		"ACE — lane kittens emptied {team}.",
		"ACE — {team} fell to the lane kittens. I did not have that.",
	},
	OuterDown = {
		"{who} dropped the {team} {lane} scratching post. Stall's open.",
		"{team} {lane} scratching post is down. {who} did that.",
	},
	StallDown = {
		"{who} snuffed the {team} {lane} lantern stall.",
		"{team} {lane} lantern stall is out. {who} blew it.",
	},
	CoreOpen = {
		"{team} yarn core is OPEN. Send it.",
		"{team} yarn core is naked. Every post and stall is gone.",
	},
	CoreDestroyed = {
		"{who} unplugged the {team} yarn core.",
		"{team} yarn core is a scratch post. {who} did the honors.",
	},
	Victory = {
		"VICTORY — {winner} halted the tape. We are so back.",
		"VICTORY — {winner} wins. I need another espresso.",
	},
	Defeat = {
		"DEFEAT — your yarn core rug-pulled. GG.",
		"DEFEAT — the chart closed red. Fountain's that way.",
	},
	DraftPractice = {
		"Practice draft is open. Red is 3 bots ({difficulty}). Lock a cat.",
		"Practice draft. Red bots are on {difficulty}. I already locked caffeine.",
	},
	Draft = {
		"Champion select — lock a cat. Premarket is unhinged.",
		"Draft is live. Lock a cat before I call it a bag.",
	},
	MatchLive = {
		"WE ARE LIVE. Posts, then stalls, then the yarn core.",
		"Match is live. Six espressos in. Do not blink.",
	},
}

local function fill(template: string, vars: { [string]: string }): string
	local text = template
	for key, value in vars do
		text = string.gsub(text, "{" .. key .. "}", function()
			return value
		end)
	end
	return text
end

local function pick(pool: { string }, roll: number?): string
	local count = #pool
	local index = 1
	if typeof(roll) == "number" and roll >= 1 then
		index = (math.floor(roll) - 1) % count + 1
	end
	return pool[index]
end

local function render(beat: string, vars: { [string]: string }, roll: number?): string
	local pool = LINES[beat]
	if not pool or #pool == 0 then
		return ""
	end
	return fill(pick(pool, roll), vars)
end

function AnnouncerLines.cueFor(beat: string): string?
	if beat == "Victory" then
		return "MatchFound"
	end
	if
		beat == "Defeat"
		or beat == "MatchLive"
		or beat == "Draft"
		or beat == "DraftPractice"
		or beat == "Ace"
		or beat == "AceLane"
		or beat == "CoreOpen"
		or beat == "FirstBlood"
		or beat == "FirstBloodLane"
		or beat == "DoubleKill"
		or beat == "TripleKill"
		or beat == "QuadraKill"
		or beat == "PentaKill"
	then
		return "Announcer"
	end
	return nil
end

local function spoken(beat: string, vars: { [string]: string }, roll: number?): Callout
	local line = render(beat, vars, roll)
	if line == "" then
		return {
			speak = false,
			beat = beat,
			line = nil,
			cue = nil,
			priority = false,
		}
	end
	return {
		speak = true,
		beat = beat,
		line = line,
		cue = AnnouncerLines.cueFor(beat),
		priority = true,
	}
end

local function quiet(beat: string?): Callout
	return {
		speak = false,
		beat = beat,
		line = nil,
		cue = nil,
		priority = false,
	}
end

function AnnouncerLines.catName(championName: string?, displayName: string?): string
	local champ = if typeof(championName) == "string" and championName ~= "" then championName else nil
	local who = if typeof(displayName) == "string" and displayName ~= "" then displayName else nil
	if champ and who and string.find(who, champ, 1, true) then
		return who
	end
	if champ and who then
		return `{champ} ({who})`
	end
	return champ or who or "a cat"
end

function AnnouncerLines.causeFrom(sourceKind: string?, championKiller: boolean): Cause
	if sourceKind == "minion" then
		return "minion"
	end
	if sourceKind == "jungle" then
		return "jungle"
	end
	if sourceKind == "tower" then
		return "tower"
	end
	if championKiller or sourceKind == "champion" or sourceKind == "item" then
		return "champion"
	end
	return "minion"
end

-- A solo practice death is not an ace. The wiped side needs a real roster.
function AnnouncerLines.isAce(living: number, teamSize: number): boolean
	return teamSize >= 2 and living <= 0
end

function AnnouncerLines.streakBeat(streak: number): string?
	if streak >= 5 then
		return "PentaKill"
	end
	if streak == 4 then
		return "QuadraKill"
	end
	if streak == 3 then
		return "TripleKill"
	end
	if streak == 2 then
		return "DoubleKill"
	end
	return nil
end

function AnnouncerLines.advanceStreak(book: { [number]: StreakRow }, killerId: number, now: number): (number, { [number]: StreakRow })
	local nextBook: { [number]: StreakRow } = {}
	for id, row in book do
		nextBook[id] = {
			count = row.count,
			at = row.at,
		}
	end
	local previous = book[killerId]
	local count = 1
	if previous and now - previous.at <= AnnouncerLines.StreakWindow then
		count = previous.count + 1
	end
	nextBook[killerId] = {
		count = count,
		at = now,
	}
	return count, nextBook
end

function AnnouncerLines.allows(now: number, lastOrdinaryAt: number?, priority: boolean): boolean
	if priority then
		return true
	end
	if typeof(lastOrdinaryAt) ~= "number" then
		return true
	end
	return now - lastOrdinaryAt >= AnnouncerLines.OrdinaryCooldown
end

local function laneCause(cause: string): boolean
	return cause == "minion" or cause == "jungle"
end

function AnnouncerLines.decideKill(query: KillQuery): Callout
	local killer = query.killer or "a cat"
	local victim = if query.victim ~= "" then query.victim else "a cat"
	local team = query.victimTeam or "That side"
	local finisher = query.finisher or killer
	local vars = {
		killer = killer,
		victim = victim,
		team = team,
		finisher = finisher,
	}
	local first = not query.firstBloodTaken
	local lane = laneCause(query.cause)
	local multi = if query.cause == "champion" then AnnouncerLines.streakBeat(query.streak) else nil

	local beat: string? = nil
	local priority = false
	if first and lane then
		beat = "FirstBloodLane"
		priority = true
	elseif first then
		beat = "FirstBlood"
		priority = true
	elseif multi then
		beat = multi
		priority = true
	elseif query.ace and lane then
		beat = "AceLane"
		priority = true
	elseif query.ace then
		beat = "Ace"
		priority = true
	elseif lane then
		return quiet(nil)
	elseif query.cause == "tower" then
		beat = "TowerKill"
		priority = false
	else
		beat = "ChampionKill"
		priority = false
	end

	if not AnnouncerLines.allows(query.now, query.lastOrdinaryAt, priority) then
		return quiet(beat)
	end
	local line = render(beat :: string, vars, query.roll)
	if line == "" then
		return quiet(beat)
	end
	return {
		speak = true,
		beat = beat,
		line = line,
		cue = AnnouncerLines.cueFor(beat :: string),
		priority = priority,
	}
end

function AnnouncerLines.structures(query: StructureQuery): { Callout }
	local list: { Callout } = {}
	local who = query.who or "Lane kittens"
	local vars = {
		who = who,
		team = query.team,
		lane = query.lane,
	}
	local function push(beat: string)
		table.insert(list, spoken(beat, vars, query.roll))
	end
	if query.kind == "Nexus" then
		push("CoreDestroyed")
		return list
	end
	if query.kind ~= "Tower" then
		return list
	end
	if query.tier == "Inner" then
		push("StallDown")
	else
		push("OuterDown")
	end
	if query.coreOpened then
		push("CoreOpen")
	end
	return list
end

function AnnouncerLines.draft(practice: boolean, difficulty: string?, roll: number?): Callout
	local diff = if typeof(difficulty) == "string" and difficulty ~= "" then difficulty else "Normal"
	if practice then
		return spoken("DraftPractice", { difficulty = diff }, roll)
	end
	return spoken("Draft", { difficulty = diff }, roll)
end

function AnnouncerLines.live(roll: number?): Callout
	return spoken("MatchLive", {}, roll)
end

function AnnouncerLines.matchEnd(won: boolean, winner: string, roll: number?): Callout
	local beat = if won then "Victory" else "Defeat"
	return spoken(beat, { winner = winner }, roll)
end

return AnnouncerLines
