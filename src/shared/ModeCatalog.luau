--!strict

-- Hub tiles. Night-market cat branding — not a Discover/Fortnite layout clone.

export type ModeId = "CatRift" | "YarnRun" | "KoiPond" | "YarnParty" | "MemeArcade"
export type ModeArt = "rift" | "run" | "fish" | "party" | "arcade"

export type ModeTile = {
	id: ModeId,
	title: string,
	blurb: string,
	tag: string,
	playable: boolean,
	swatch: Color3,
	accent: Color3,
	art: ModeArt,
}

local TILES: { ModeTile } = {
	{
		id = "CatRift",
		title = "Cat Rift",
		blurb = "3-lane MOBA. Lock a cat, scratch the nexus.",
		tag = "MOBA",
		playable = true,
		swatch = Color3.fromRGB(86, 148, 230),
		accent = Color3.fromRGB(255, 196, 74),
		art = "rift",
	},
	{
		id = "YarnRun",
		title = "Yarn Run",
		blurb = "Endless 3-lane dash. Dodge dogs, ride Roombas.",
		tag = "RUNNER",
		playable = true,
		swatch = Color3.fromRGB(255, 122, 98),
		accent = Color3.fromRGB(255, 184, 140),
		art = "run",
	},
	{
		id = "KoiPond",
		title = "Koi Pond",
		blurb = "Lazy fishing on the night-market canal.",
		tag = "SOON",
		playable = false,
		swatch = Color3.fromRGB(70, 110, 140),
		accent = Color3.fromRGB(120, 196, 150),
		art = "fish",
	},
	{
		id = "YarnParty",
		title = "Yarn Party",
		blurb = "Couch chaos. Four cats, one ball of yarn.",
		tag = "SOON",
		playable = false,
		swatch = Color3.fromRGB(180, 90, 140),
		accent = Color3.fromRGB(255, 160, 200),
		art = "party",
	},
	{
		id = "MemeArcade",
		title = "Meme Arcade",
		blurb = "Yarn tickers, tap trades, very illegal vibes.",
		tag = "SOON",
		playable = false,
		swatch = Color3.fromRGB(90, 140, 80),
		accent = Color3.fromRGB(255, 220, 70),
		art = "arcade",
	},
}

local ModeCatalog = {}

function ModeCatalog.all(): { ModeTile }
	return TILES
end

function ModeCatalog.get(id: string): ModeTile?
	for _, tile in TILES do
		if tile.id == id then
			return tile
		end
	end
	return nil
end

return ModeCatalog
