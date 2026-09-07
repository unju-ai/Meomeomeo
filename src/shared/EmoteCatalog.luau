--!strict

export type EmoteId = "Meow" | "Hiss" | "Purr" | "Flex" | "Dance" | "Laugh" | "Cry" | "GG"
export type EmoteMotion = "nod" | "puff" | "float" | "flex" | "dance" | "bounce" | "droop" | "spin"
export type EmoteCue =
	"EmoteMeow"
	| "EmoteHiss"
	| "EmotePurr"
	| "EmoteFlex"
	| "EmoteDance"
	| "EmoteLaugh"
	| "EmoteCry"
	| "EmoteGG"

export type EmoteDef = {
	id: EmoteId,
	label: string,
	emoji: string,
	cue: EmoteCue,
	motion: EmoteMotion,
	color: Color3,
}

local ORDER: { EmoteId } = { "Meow", "Hiss", "Purr", "Flex", "Dance", "Laugh", "Cry", "GG" }

local BY_ID: { [EmoteId]: EmoteDef } = {
	Meow = {
		id = "Meow",
		label = "Meow",
		emoji = "😺",
		cue = "EmoteMeow",
		motion = "nod",
		color = Color3.fromRGB(255, 196, 74),
	},
	Hiss = {
		id = "Hiss",
		label = "Hiss",
		emoji = "😾",
		cue = "EmoteHiss",
		motion = "puff",
		color = Color3.fromRGB(230, 86, 96),
	},
	Purr = {
		id = "Purr",
		label = "Purr",
		emoji = "😻",
		cue = "EmotePurr",
		motion = "float",
		color = Color3.fromRGB(255, 184, 140),
	},
	Flex = {
		id = "Flex",
		label = "Flex",
		emoji = "💪",
		cue = "EmoteFlex",
		motion = "flex",
		color = Color3.fromRGB(86, 148, 230),
	},
	Dance = {
		id = "Dance",
		label = "Dance",
		emoji = "💃",
		cue = "EmoteDance",
		motion = "dance",
		color = Color3.fromRGB(180, 120, 230),
	},
	Laugh = {
		id = "Laugh",
		label = "Laugh",
		emoji = "😹",
		cue = "EmoteLaugh",
		motion = "bounce",
		color = Color3.fromRGB(255, 196, 74),
	},
	Cry = {
		id = "Cry",
		label = "Cry",
		emoji = "😿",
		cue = "EmoteCry",
		motion = "droop",
		color = Color3.fromRGB(120, 160, 220),
	},
	GG = {
		id = "GG",
		label = "GG",
		emoji = "🎉",
		cue = "EmoteGG",
		motion = "spin",
		color = Color3.fromRGB(120, 196, 150),
	},
}

local EmoteCatalog = {}

function EmoteCatalog.list(): { EmoteDef }
	local out = {}
	for _, id in ORDER do
		table.insert(out, BY_ID[id])
	end
	return out
end

function EmoteCatalog.get(id: unknown): EmoteDef?
	if typeof(id) ~= "string" then
		return nil
	end
	return BY_ID[id :: EmoteId]
end

function EmoteCatalog.isId(id: unknown): boolean
	return EmoteCatalog.get(id) ~= nil
end

return EmoteCatalog
