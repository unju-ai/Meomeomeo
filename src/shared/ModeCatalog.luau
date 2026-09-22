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
	wash: Color3,
	glow: Color3,
	art: ModeArt,
}

local TILES: { ModeTile } = {
	{
		id = "CatRift",
		title = "Cat Rift",
		blurb = "Three lanes. Scratch posts, then the yarn core.",
		tag = "MOBA",
		playable = true,
		swatch = Color3.fromRGB(62, 108, 178),
		accent = Color3.fromRGB(255, 196, 74),
		wash = Color3.fromRGB(48, 38, 52),
		glow = Color3.fromRGB(255, 220, 120),
		art = "rift",
	},
	{
		id = "YarnRun",
		title = "Yarn Run",
		blurb = "Coral yarn dash. Dogs, Roombas, laundry tunnel.",
		tag = "RUNNER",
		playable = true,
		swatch = Color3.fromRGB(255, 112, 88),
		accent = Color3.fromRGB(255, 168, 128),
		wash = Color3.fromRGB(68, 36, 34),
		glow = Color3.fromRGB(255, 196, 168),
		art = "run",
	},
	{
		id = "KoiPond",
		title = "Koi Pond",
		blurb = "Canal mint. Cast yarn. Reel the cream window.",
		tag = "POND",
		playable = true,
		swatch = Color3.fromRGB(48, 118, 128),
		accent = Color3.fromRGB(110, 210, 168),
		wash = Color3.fromRGB(36, 48, 52),
		glow = Color3.fromRGB(150, 240, 196),
		art = "fish",
	},
	{
		id = "YarnParty",
		title = "Yarn Party",
		blurb = "Four seats. Three micro-rounds. Yarn chaos.",
		tag = "PARTY",
		playable = true,
		swatch = Color3.fromRGB(196, 72, 148),
		accent = Color3.fromRGB(255, 148, 196),
		wash = Color3.fromRGB(58, 32, 52),
		glow = Color3.fromRGB(255, 188, 220),
		art = "party",
	},
	{
		id = "MemeArcade",
		title = "Meme Arcade",
		blurb = "Neon tape. Buy low. Scream at the candles.",
		tag = "TAPE",
		playable = true,
		swatch = Color3.fromRGB(42, 72, 48),
		accent = Color3.fromRGB(255, 232, 64),
		wash = Color3.fromRGB(34, 48, 36),
		glow = Color3.fromRGB(255, 248, 140),
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

-- One-glance stall chip (hub tag row). Playable flags stay on the tile.
function ModeCatalog.stallTag(def: ModeTile): string
	return def.tag
end

-- Stream-readable one-liner under the title.
function ModeCatalog.oneLine(def: ModeTile): string
	return def.blurb
end

-- Play CTA copy. Does not change playable flags.
function ModeCatalog.playLabel(def: ModeTile): string
	if def.playable then
		return "Play"
	end
	return "Soon"
end

-- Soft glow used on hover / selected chrome.
function ModeCatalog.glowAccent(def: ModeTile): Color3
	return def.glow
end

return ModeCatalog
