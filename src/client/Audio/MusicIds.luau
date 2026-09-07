--!strict

-- Phase music beds. Engine builtins keep git free of audio binaries.
-- Swap any `id` for a Creator Store upload: "rbxassetid://123456789".
-- See README "Audio & juice" → Music beds.

export type BedId = "Lobby" | "ChampionSelect" | "InProgress" | "Ended"

export type BedDef = {
	id: string,
	volume: number,
	playbackSpeed: number,
	note: string,
}

-- Moods are playbackSpeed + volume on a quiet loop. Replace `id` with a real bed.
local MusicIds: { [BedId]: BedDef } = {
	Lobby = {
		id = "rbxasset://sounds/action_get_up.mp3",
		volume = 0.14,
		playbackSpeed = 0.52,
		note = "Cozy lobby — swap for a soft night-market loop",
	},
	ChampionSelect = {
		id = "rbxasset://sounds/action_get_up.mp3",
		volume = 0.16,
		playbackSpeed = 0.82,
		note = "Draft tension — swap for a short anticipatory bed",
	},
	InProgress = {
		id = "rbxasset://sounds/action_get_up.mp3",
		volume = 0.18,
		playbackSpeed = 1.08,
		note = "Rift bed — swap for a low combat underscore (keep quieter than SFX)",
	},
	Ended = {
		id = "rbxasset://sounds/action_get_up.mp3",
		volume = 0.11,
		playbackSpeed = 0.4,
		note = "Post-match wind-down — swap for a victory/defeat sting loop",
	},
}

return MusicIds
