--!strict

-- Placeholder silhouettes for the 14 cats. Primitive colors / flair only —
-- no mesh binaries. Server builds Parts from this table; draft UI uses it
-- for card swatches. Swap recipes later without touching combat binds.

export type Archetype =
	"meme"
	| "robot"
	| "cyborg"
	| "wizard"
	| "sorcerer"
	| "mystic"
	| "warrior"
	| "rogue"
	| "esper"

export type Flair = {
	goldCollar: boolean?,
	bowtie: boolean?,
	rainbowTail: boolean?,
	rocket: boolean?,
	armor: boolean?,
	visor: boolean?,
	glasses: boolean?,
	grannyGlasses: boolean?,
	shades: boolean?,
	mortar: boolean?,
	fedora: boolean?,
	shawl: boolean?,
	bun: boolean?,
	antenna: boolean?,
	chestLight: boolean?,
	blades: boolean?,
	hood: boolean?,
	cape: boolean?,
	wizardHat: boolean?,
	crystalHat: boolean?,
	aura: boolean?,
	orbs: boolean?,
	crest: boolean?,
}

export type LookDef = {
	id: string,
	archetype: Archetype,
	label: string,
	body: Color3,
	accent: Color3,
	neon: Color3,
	material: Enum.Material,
	earScale: number,
	tailLength: number,
	torsoScale: number,
	flair: Flair,
}

local LOOKS: { [string]: LookDef } = {
	ChairmanMeow = {
		id = "ChairmanMeow",
		archetype = "meme",
		label = "Boardroom",
		body = Color3.fromRGB(92, 64, 51),
		accent = Color3.fromRGB(212, 168, 72),
		neon = Color3.fromRGB(255, 214, 96),
		material = Enum.Material.SmoothPlastic,
		earScale = 1.05,
		tailLength = 1.6,
		torsoScale = 1.12,
		flair = { goldCollar = true, bowtie = true },
	},
	NyanRocket = {
		id = "NyanRocket",
		archetype = "meme",
		label = "Pop trail",
		body = Color3.fromRGB(255, 105, 180),
		accent = Color3.fromRGB(120, 220, 255),
		neon = Color3.fromRGB(255, 160, 220),
		material = Enum.Material.SmoothPlastic,
		earScale = 0.95,
		tailLength = 2.1,
		torsoScale = 0.96,
		flair = { rainbowTail = true, rocket = true },
	},
	ChonkKnight = {
		id = "ChonkKnight",
		archetype = "meme",
		label = "Armored loaf",
		body = Color3.fromRGB(232, 168, 88),
		accent = Color3.fromRGB(180, 150, 120),
		neon = Color3.fromRGB(255, 210, 140),
		material = Enum.Material.SmoothPlastic,
		earScale = 0.85,
		tailLength = 1.2,
		torsoScale = 1.22,
		flair = { armor = true, visor = true },
	},
	ProfessorWhiskers = {
		id = "ProfessorWhiskers",
		archetype = "meme",
		label = "Tutor",
		body = Color3.fromRGB(90, 122, 180),
		accent = Color3.fromRGB(40, 44, 56),
		neon = Color3.fromRGB(255, 80, 70),
		material = Enum.Material.SmoothPlastic,
		earScale = 0.9,
		tailLength = 1.5,
		torsoScale = 1,
		flair = { glasses = true, mortar = true },
	},
	ScammyMcMittens = {
		id = "ScammyMcMittens",
		archetype = "meme",
		label = "Rug",
		body = Color3.fromRGB(120, 200, 90),
		accent = Color3.fromRGB(36, 40, 32),
		neon = Color3.fromRGB(255, 220, 70),
		material = Enum.Material.SmoothPlastic,
		earScale = 1,
		tailLength = 1.7,
		torsoScale = 0.98,
		flair = { shades = true, fedora = true },
	},
	GrandmaFluff = {
		id = "GrandmaFluff",
		archetype = "meme",
		label = "Den mom",
		body = Color3.fromRGB(245, 214, 186),
		accent = Color3.fromRGB(186, 120, 168),
		neon = Color3.fromRGB(255, 190, 210),
		material = Enum.Material.SmoothPlastic,
		earScale = 0.8,
		tailLength = 1.4,
		torsoScale = 1.08,
		flair = { grannyGlasses = true, shawl = true, bun = true },
	},
	Bytekit = {
		id = "Bytekit",
		archetype = "robot",
		label = "Robot",
		body = Color3.fromRGB(160, 176, 196),
		accent = Color3.fromRGB(70, 90, 110),
		neon = Color3.fromRGB(80, 220, 255),
		material = Enum.Material.Metal,
		earScale = 0.75,
		tailLength = 1.3,
		torsoScale = 1,
		flair = { antenna = true, visor = true, chestLight = true },
	},
	Chromeclaw = {
		id = "Chromeclaw",
		archetype = "cyborg",
		label = "Cyborg",
		body = Color3.fromRGB(90, 210, 200),
		accent = Color3.fromRGB(70, 80, 90),
		neon = Color3.fromRGB(255, 90, 80),
		material = Enum.Material.Metal,
		earScale = 0.85,
		tailLength = 1.5,
		torsoScale = 1.06,
		flair = { blades = true, chestLight = true, visor = true },
	},
	OraclePaws = {
		id = "OraclePaws",
		archetype = "mystic",
		label = "Mystic",
		body = Color3.fromRGB(186, 140, 220),
		accent = Color3.fromRGB(72, 48, 96),
		neon = Color3.fromRGB(210, 160, 255),
		material = Enum.Material.SmoothPlastic,
		earScale = 1.05,
		tailLength = 1.8,
		torsoScale = 1,
		flair = { hood = true, aura = true },
	},
	Archmeow = {
		id = "Archmeow",
		archetype = "wizard",
		label = "Wizard",
		body = Color3.fromRGB(70, 90, 190),
		accent = Color3.fromRGB(40, 32, 80),
		neon = Color3.fromRGB(255, 214, 90),
		material = Enum.Material.SmoothPlastic,
		earScale = 0.9,
		tailLength = 1.6,
		torsoScale = 1,
		flair = { wizardHat = true, aura = true },
	},
	Hexkit = {
		id = "Hexkit",
		archetype = "sorcerer",
		label = "Sorcerer",
		body = Color3.fromRGB(168, 70, 200),
		accent = Color3.fromRGB(255, 140, 70),
		neon = Color3.fromRGB(255, 120, 255),
		material = Enum.Material.SmoothPlastic,
		earScale = 1,
		tailLength = 1.7,
		torsoScale = 0.98,
		flair = { crystalHat = true, aura = true },
	},
	SirScratchalot = {
		id = "SirScratchalot",
		archetype = "warrior",
		label = "Warrior",
		body = Color3.fromRGB(196, 80, 70),
		accent = Color3.fromRGB(200, 180, 120),
		neon = Color3.fromRGB(255, 200, 90),
		material = Enum.Material.SmoothPlastic,
		earScale = 0.88,
		tailLength = 1.4,
		torsoScale = 1.1,
		flair = { armor = true, blades = true, crest = true },
	},
	Shadowpounce = {
		id = "Shadowpounce",
		archetype = "rogue",
		label = "Rogue",
		body = Color3.fromRGB(48, 52, 72),
		accent = Color3.fromRGB(24, 22, 32),
		neon = Color3.fromRGB(160, 80, 200),
		material = Enum.Material.SmoothPlastic,
		earScale = 1.1,
		tailLength = 1.9,
		torsoScale = 0.88,
		flair = { hood = true, cape = true },
	},
	Mindwhisker = {
		id = "Mindwhisker",
		archetype = "esper",
		label = "Esper",
		body = Color3.fromRGB(210, 120, 230),
		accent = Color3.fromRGB(120, 80, 180),
		neon = Color3.fromRGB(180, 140, 255),
		material = Enum.Material.SmoothPlastic,
		earScale = 1,
		tailLength = 1.6,
		torsoScale = 0.97,
		flair = { aura = true, orbs = true },
	},
}

local FALLBACK: LookDef = LOOKS.ChairmanMeow

local ChampionLooks = {}

function ChampionLooks.get(id: string): LookDef
	return LOOKS[id] or FALLBACK
end

function ChampionLooks.teamColor(team: "Blue" | "Red"): Color3
	if team == "Blue" then
		return Color3.fromRGB(70, 130, 255)
	end
	return Color3.fromRGB(220, 70, 70)
end

function ChampionLooks.tintedBody(look: LookDef, team: "Blue" | "Red"): Color3
	-- Light team wash so champs stay distinct but sides stay readable.
	return look.body:Lerp(ChampionLooks.teamColor(team), 0.18)
end

return ChampionLooks
