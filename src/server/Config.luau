--!strict

-- Server-only tunables. Do not put live API keys or chain private keys here.
-- AI / claim HTTP secrets may be pasted locally for experiments — never commit.
-- The Meo404 minter key belongs on a hosted backend, not in this ModuleScript.
--
-- PRODUCTION CHECKLIST — 0 / "" is the Studio-safe stub. Fill locally before publish.
-- See PLAYTEST.md and README "Production config".
--   Match.MatchPlaceId            published PlaceId for ReserveServer (0 = in-place)
--   Match.LobbyPlaceId            published lobby PlaceId for "Back to lobby" (0 = remember origin)
--   Match.MinPlayersToStart       2 for testing; 6 (3v3) or 10 (5v5) live
--   Nft404.DeveloperProductId     Creator Dashboard Developer Product (0 = Studio mock grant)
--   Nft404.ClaimApiUrl            hosted POST /v1/meo404 ("" + Provider=mock until the bridge is live)
--   Nft404.ClaimApiSecret         Bearer shared secret — NEVER a chain key; never commit
--   Nft404.AllowSiweMockBypass    true in Studio; false before any live Robux claim
--   Ai.Endpoint / Ai.ApiKey       only if Ai.Provider = "http"; never commit a real key

export type VoiceMode = "Team" | "Proximity"

local Config = {
	Match = {
		TeamSize = 5,
		-- Real queue waits for this many humans. Practice bypasses it.
		-- Testing default is 2. Set 6 for 3v3 or 10 for a full 5v5.
		MinPlayersToStart = 2,
		-- Dedicated match place. 0 = never teleport; start the match in this
		-- server (Studio-safe). Set to a published PlaceId to ReserveServer.
		-- Can be this lobby's PlaceId (same-place reserved instance) or a
		-- separate match place. Reserved servers need a published experience.
		MatchPlaceId = 0,
		-- Where "Back to lobby" sends reserved-server players. 0 = remember
		-- the PlaceId they queued from (written into teleport data).
		LobbyPlaceId = 0,
		-- Form a match after this many seconds if PadQueueWithBots is on.
		MaxWaitSeconds = 90,
		-- Fill empty roster slots with BotService cats (see Config.Bots.QueueFillTo).
		PadQueueWithBots = true,
		-- How long a reserved match instance waits for teleported cats.
		ArrivalTimeoutSeconds = 20,
		EstimatedSecondsPerMissing = 14,
		ChampionSelectSeconds = 25,
		PostMatchSeconds = 45,
		PracticeEnabled = true,
		StartingGold = 500,
		KillGold = 180,
		AssistGold = 60,
		AssistWindow = 8,
		TowerGold = 120,
		MinionGold = 18,
		MinionXp = 18,
		NearbyMinionXp = 10,
		NearbyXpRadius = 42,
		KillXp = 80,
		AssistXp = 30,
	},

	-- Levels 1–18. See Shared.Progression for the XP curve and auto-ranks.
	Progression = {
		MaxLevel = 18,
		RUnlockLevel = 6,
	},

	Emotes = {
		CooldownSeconds = 2.6,
		BroadcastRadius = 96,
		BillboardSeconds = 2.4,
		-- Hold T. G is unused if a later bind steals T.
		HoldKey = "T",
	},

	Combat = {
		RespawnSeconds = 7,
		RegenPerSecond = 4,
		ManaRegenPerSecond = 6,
		FountainHpRegen = 48,
		FountainManaRegen = 56,
		StructureTouchRadius = 18,
		-- B is Pawmart. F channels home. Damage / combat orders cancel.
		RecallSeconds = 7,
		RecallMoveCancel = 2.5,
	},

	Jungle = {
		FirstSpawnDelay = 8,
		Leash = 38,
		AttackRange = 14,
		AttackInterval = 1.2,
		Speed = 15,
		NearbyXp = 12,
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
		WardRadius = 40,
		WardPlaceRange = 28,
		TrinketCooldown = 70,
		TrinketDuration = 60,
		WardHealth = 60,
		ProximityReveal = 14,
		LensCooldown = 75,
		LensRadius = 32,
		LensDamage = 80,
		RevealSeconds = 5,
	},

	Shop = {
		FountainRadius = 32,
	},

	-- Practice / underfilled-queue AI. Finite state machine, not ML.
	Bots = {
		PracticeEnemies = 3,
		PracticeAllies = 0,
		QueueFillTo = 3,
		DefaultDifficulty = "Normal" :: "Easy" | "Normal" | "Hard",
		Pool = { "NyanRocket", "Bytekit", "Shadowpounce", "ChonkKnight", "SirScratchalot", "Chromeclaw" },
		-- Easy stays sloppy: slow thinks, early retreat, no CS wait, no lead, two items.
		Easy = {
			ThinkInterval = 0.55,
			RetreatHp = 0.42,
			AbilityChance = 0.45,
			ExtraAaDelay = 0.25,
			DamageAmp = 0.88,
			LastHit = false,
			LastHitMul = 2,
			LeadShots = false,
			SkillshotSpeed = 55,
			Jungle = false,
			Ward = false,
			Dodge = false,
			AvoidAoe = false,
			DiveIq = false,
			UseLens = false,
			ShopItems = { "Longclaw", "Yarnplate" },
		},
		Normal = {
			ThinkInterval = 0.28,
			RetreatHp = 0.28,
			AbilityChance = 0.85,
			ExtraAaDelay = 0,
			DamageAmp = 1,
			LastHit = true,
			LastHitMul = 1.4,
			LeadShots = true,
			SkillshotSpeed = 64,
			Jungle = true,
			Ward = false,
			Dodge = true,
			AvoidAoe = true,
			DiveIq = true,
			UseLens = false,
			ShopItems = { "Longclaw", "Yarnplate", "ManaTreat", "PounceBoots" },
		},
		-- Hard: faster, stingier retreat, last-hits, leads skillshots, mid can jungle, early ward.
		Hard = {
			ThinkInterval = 0.16,
			RetreatHp = 0.16,
			AbilityChance = 0.95,
			ExtraAaDelay = 0,
			DamageAmp = 1.22,
			LastHit = true,
			LastHitMul = 1.18,
			LeadShots = true,
			SkillshotSpeed = 78,
			Jungle = true,
			Ward = true,
			Dodge = true,
			AvoidAoe = true,
			DiveIq = true,
			UseLens = true,
			ShopItems = { "Longclaw", "Yarnplate", "ManaTreat", "PounceBoots", "WhiskerLens" },
		},
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

	-- Meo404: Robux Developer Product → DataStore entitlement → hosted mint.
	-- This is not a Robux-to-crypto swap. See README "Meo404 / Robux caveat".
	-- ClaimApiSecret is a shared Bearer token, NEVER a chain private key.
	Nft404 = {
		ProductName = "Mint Meo 404",
		-- Creator Dashboard → Monetization → Developer Products. 0 = unset.
		DeveloperProductId = 0,
		-- "mock" never talks to chain. "http" POSTs to ClaimApiUrl.
		Provider = "mock",
		ClaimApiUrl = "", -- hosted backend, e.g. https://claims.example.com/v1/meo404
		ClaimApiSecret = "", -- shared secret with the backend; NEVER a chain private key
		AllowStudioMockPurchase = true,
		-- Studio / mock: claim + verify can skip ECDSA recover. Turn OFF before live Robux.
		AllowSiweMockBypass = true,
		-- Shown in the SIWE message. Production must bind these to the real HTTPS host.
		SiweDomain = "meo404.local",
		SiweUri = "https://meo404.local/siwe",
		SiweChainId = 1,
		SiweNonceTtlSec = 600,
	},
}

return Config
