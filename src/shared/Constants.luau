--!strict

local Constants = {
	RemotesFolderName = "MeoRemotes",
	MapFolderName = "MeoMap",

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
		NpcId = "MeoNpcId",
		Team = "MeoTeam",
		ChampionId = "MeoChampionId",
		MinionId = "MeoMinionId",
		JungleId = "MeoJungleId",
		WardId = "MeoWardId",
		Recalling = "MeoRecalling",
		UserId = "MeoUserId",
		TutorialDone = "MeoTutorialDone",
		SfxVolume = "MeoSfxVolume",
		SfxMuted = "MeoSfxMuted",
		MusicVolume = "MeoMusicVolume",
		MusicMuted = "MeoMusicMuted",
		MuteOthersEmotes = "MeoMuteOthersEmotes",
		PracticeDifficulty = "MeoPracticeDifficulty",
	},

	Lanes = { "Top", "Mid", "Bot" } :: { string },
	LaneZ = {
		Top = -80,
		Mid = 0,
		Bot = 80,
	},

	-- Matches MapBuilder ground (420 x 280 centered at origin).
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
