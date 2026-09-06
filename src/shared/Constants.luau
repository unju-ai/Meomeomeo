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
	},

	Lanes = { "Top", "Mid", "Bot" } :: { string },
	LaneZ = {
		Top = -80,
		Mid = 0,
		Bot = 80,
	},

	Collision = {
		Map = Enum.RaycastFilterType.Exclude,
	},
}

return Constants
