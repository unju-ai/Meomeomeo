--!strict

-- Server-only tunables. Do not put live API keys here.
-- For a future HTTP AI provider: paste a key locally (never commit) and
-- flip Ai.Provider to "http" after enabling Studio HTTP requests.

export type VoiceMode = "Team" | "Proximity"

local Config = {
	Match = {
		TeamSize = 5,
		-- Real queue waits for this many players. Practice bypasses it.
		MinPlayersToStart = 2,
		ChampionSelectSeconds = 25,
		PostMatchSeconds = 10,
		PracticeEnabled = true,
		StartingGold = 500,
		KillGold = 180,
		TowerGold = 120,
	},

	Combat = {
		RespawnSeconds = 7,
		RegenPerSecond = 4,
		ManaRegenPerSecond = 6,
		StructureTouchRadius = 18,
	},

	Voice = {
		-- Team = only teammates hear you (Audio API access lists).
		-- Proximity = default Roblox spatial voice.
		Mode = "Team" :: VoiceMode,
		FallbackToProximity = true,
	},

	Ai = {
		-- "mock" always works offline. "http" uses Endpoint + ApiKey when set.
		Provider = "mock",
		Endpoint = "", -- e.g. https://api.openai.com/v1/chat/completions
		ApiKey = "", -- placeholder only; never commit a real key
		Model = "gpt-4o-mini",
		TimeoutSeconds = 12,
		MaxMessageLength = 240,
		RateLimitSeconds = 1.25,
	},

	Economy = {
		Enabled = true,
		StartingYarn = 100,
		CheerCost = 10,
		CheerBump = 0.08,
	},
}

return Config
