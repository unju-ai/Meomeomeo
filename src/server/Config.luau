--!strict

-- Server-only tunables. Do not put live API keys or chain private keys here.
-- AI / claim HTTP secrets may be pasted locally for experiments — never commit.
-- The Meo404 minter key belongs on a hosted backend, not in this ModuleScript.

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
		AssistGold = 60,
		AssistWindow = 8,
		TowerGold = 120,
		MinionGold = 18,
		MinionXp = 12,
		KillXp = 50,
		AssistXp = 20,
	},

	Combat = {
		RespawnSeconds = 7,
		RegenPerSecond = 4,
		ManaRegenPerSecond = 6,
		StructureTouchRadius = 18,
	},

	AutoAttack = {
		Range = 26,
		AcquireRange = 36,
		Interval = 1.05,
		Windup = 0.16,
		BaseDamage = 24,
	},

	Minions = {
		FirstWaveDelay = 6,
		WaveInterval = 22,
		PerLane = 3,
		Health = 95,
		Damage = 14,
		AttackRange = 15,
		AttackInterval = 1.15,
		Speed = 18,
		HitRadius = 10,
	},

	Towers = {
		Range = 44,
		Damage = 50,
		Interval = 1.25,
		NexusRange = 36,
		NexusDamage = 58,
		AggroSeconds = 4,
	},

	-- All 3 outer towers on a team must fall before that nexus takes damage.
	Nexus = {
		TowersRequiredDown = 3,
	},

	Vision = {
		ChampionRadius = 54,
		TowerRadius = 46,
		MinionRadius = 28,
	},

	Shop = {
		FountainRadius = 32,
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

	-- Meo404: Robux Developer Product → entitlement → hosted mint.
	-- This is not a Robux-to-crypto swap. See README "Meo404 / Robux caveat".
	Nft404 = {
		ProductName = "Mint Meo 404",
		-- Creator Dashboard → Monetization → Developer Products. 0 = unset.
		DeveloperProductId = 0,
		-- "mock" never talks to chain. "http" POSTs to ClaimApiUrl.
		Provider = "mock",
		ClaimApiUrl = "", -- hosted backend, e.g. https://claims.example.com/v1/meo404
		ClaimApiSecret = "", -- shared secret with the backend; NEVER a chain private key
		AllowStudioMockPurchase = true,
	},
}

return Config
