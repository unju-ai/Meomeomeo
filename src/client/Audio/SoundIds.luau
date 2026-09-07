--!strict

-- Placeholder cues. Engine builtins (rbxasset://sounds/…) keep git free of binaries.
-- Swap any `id` for a Toolbox / Creator Store upload: "rbxassetid://123456789".
-- See README "Audio & juice".

export type Cue =
	"AutoHit"
	| "AbilityCast"
	| "LevelUp"
	| "Kill"
	| "TowerDown"
	| "NexusDown"
	| "RecallLoop"
	| "ShopBuy"
	| "WardPlace"
	| "MatchFound"
	| "Announcer"
	| "Heal"
	| "EmoteMeow"
	| "EmoteHiss"
	| "EmotePurr"
	| "EmoteFlex"
	| "EmoteDance"
	| "EmoteLaugh"
	| "EmoteCry"
	| "EmoteGG"

export type CueDef = {
	id: string,
	volume: number,
	playbackSpeed: number,
	looped: boolean?,
}

local SoundIds: { [Cue]: CueDef } = {
	AutoHit = {
		id = "rbxasset://sounds/hit.wav",
		volume = 0.28,
		playbackSpeed = 1.18,
	},
	AbilityCast = {
		id = "rbxasset://sounds/swoosh.wav",
		volume = 0.32,
		playbackSpeed = 1.05,
	},
	LevelUp = {
		id = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.42,
		playbackSpeed = 0.82,
	},
	Kill = {
		id = "rbxasset://sounds/snap.wav",
		volume = 0.4,
		playbackSpeed = 0.92,
	},
	TowerDown = {
		id = "rbxasset://sounds/collision.wav",
		volume = 0.45,
		playbackSpeed = 0.78,
	},
	NexusDown = {
		id = "rbxasset://sounds/collision.wav",
		volume = 0.55,
		playbackSpeed = 0.62,
	},
	RecallLoop = {
		id = "rbxasset://sounds/action_get_up.mp3",
		volume = 0.22,
		playbackSpeed = 0.7,
		looped = true,
	},
	ShopBuy = {
		id = "rbxasset://sounds/switch.wav",
		volume = 0.38,
		playbackSpeed = 1.1,
	},
	WardPlace = {
		id = "rbxasset://sounds/button.wav",
		volume = 0.34,
		playbackSpeed = 0.95,
	},
	MatchFound = {
		id = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.5,
		playbackSpeed = 1,
	},
	Announcer = {
		id = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.28,
		playbackSpeed = 1.35,
	},
	Heal = {
		id = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.22,
		playbackSpeed = 1.55,
	},
	EmoteMeow = {
		id = "rbxasset://sounds/button.wav",
		volume = 0.36,
		playbackSpeed = 1.35,
	},
	EmoteHiss = {
		id = "rbxasset://sounds/swoosh.wav",
		volume = 0.34,
		playbackSpeed = 0.82,
	},
	EmotePurr = {
		id = "rbxasset://sounds/action_get_up.mp3",
		volume = 0.22,
		playbackSpeed = 1.15,
	},
	EmoteFlex = {
		id = "rbxasset://sounds/snap.wav",
		volume = 0.36,
		playbackSpeed = 1.05,
	},
	EmoteDance = {
		id = "rbxasset://sounds/switch.wav",
		volume = 0.34,
		playbackSpeed = 1.22,
	},
	EmoteLaugh = {
		id = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.3,
		playbackSpeed = 1.65,
	},
	EmoteCry = {
		id = "rbxasset://sounds/hit.wav",
		volume = 0.26,
		playbackSpeed = 0.72,
	},
	EmoteGG = {
		id = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.38,
		playbackSpeed = 1.08,
	},
}

return SoundIds
