--!strict

local Constants = {
	RemotesFolderName = "MeoRemotes",
	MapFolderName = "MeoMap",
	-- Thick rift cover lives here. Click rays skip it; vision queries do not.
	VisionCoverName = "VisionCover",
	YarnRunFolderName = "MeoYarnRun",
	YarnRunOrigin = Vector3.new(0, 2, 4200),
	KoiPondFolderName = "MeoKoiPond",
	KoiPondOrigin = Vector3.new(900, 2, 0),
	YarnPartyFolderName = "MeoYarnParty",
	YarnPartyOrigin = Vector3.new(0, 2, -4200),
	MemeArcadeFolderName = "MeoMemeArcade",
	MemeArcadeOrigin = Vector3.new(-900, 2, 0),

	Teams = {
		Blue = "Blue" :: "Blue",
		Red = "Red" :: "Red",
		BlueInstance = "BlueWhiskers",
		RedInstance = "RedPaws",
	},

	Phases = {
		Lobby = "Lobby" :: "Lobby",
		ChampionSelect = "ChampionSelect" :: "ChampionSelect",
		InProgress = "InProgress" :: "InProgress",
		Ended = "Ended" :: "Ended",
	},

	Slots = { "Q", "W", "E", "R" } :: { "Q" | "W" | "E" | "R" },

	Attributes = {
		ObjectiveId = "MeoObjectiveId",
		BlocksVision = "MeoBlocksVision",
		NpcId = "MeoNpcId",
		Team = "MeoTeam",
		ChampionId = "MeoChampionId",
		MinionId = "MeoMinionId",
		JungleId = "MeoJungleId",
		WardId = "MeoWardId",
		WardKind = "MeoWardKind",
		-- Display surface for ward juice. Place rules still live in WardService.
		PlacedAt = "MeoPlacedAt",
		ExpiresAt = "MeoExpiresAt",
		Recalling = "MeoRecalling",
		Channeling = "MeoChanneling",
		UserId = "MeoUserId",
		TutorialDone = "MeoTutorialDone",
		SfxVolume = "MeoSfxVolume",
		SfxMuted = "MeoSfxMuted",
		MusicVolume = "MeoMusicVolume",
		MusicMuted = "MeoMusicMuted",
		MuteOthersEmotes = "MeoMuteOthersEmotes",
		HideBoardName = "MeoHideBoardName",
		PracticeDifficulty = "MeoPracticeDifficulty",
		GameMode = "MeoGameMode",
		YarnBest = "MeoYarnBest",
		CosmeticHat = "MeoHat",
		CosmeticTrail = "MeoTrail",
		PublishSummary = "MeoPublishSummary",
	},

	Lanes = { "Top", "Mid", "Bot" } :: { string },
	LaneZ = {
		Top = -80,
		Mid = 0,
		Bot = 80,
	},

	-- Matches MapBuilder ground (420 x 280 centered at origin).
	-- Shared.VisionLogic.MinX/MaxX/MinZ/MaxZ must stay in sync (10-stud fog grid).
	MapBounds = {
		MinX = -210,
		MaxX = 210,
		MinZ = -140,
		MaxZ = 140,
	},

	Collision = {
		Map = Enum.RaycastFilterType.Exclude,
	},
}

return Constants
