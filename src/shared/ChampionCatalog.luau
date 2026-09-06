--!strict

local Types = require(script.Parent.Types)

local function ability(
	slot: Types.AbilitySlot,
	name: string,
	description: string,
	kind: Types.AbilityKind,
	stats: { cooldown: number, manaCost: number, range: number, radius: number, damage: number, heal: number }
): Types.AbilityDef
	return {
		slot = slot,
		name = name,
		description = description,
		kind = kind,
		cooldown = stats.cooldown,
		manaCost = stats.manaCost,
		range = stats.range,
		radius = stats.radius,
		damage = stats.damage,
		heal = stats.heal,
	}
end

local CATALOG: { [string]: Types.ChampionDef } = {
	ChairmanMeow = {
		id = "ChairmanMeow",
		name = "Chairman Meow",
		title = "CEO of the Rift",
		role = "Tank",
		blurb = "Slams the frontline with hostile takeovers and board-approved shields.",
		color = Color3.fromRGB(92, 64, 51),
		maxHealth = 820,
		maxMana = 280,
		abilities = {
			Q = ability("Q", "Paw Slam", "Slam the ground, scratching nearby foes.", "damage", {
				cooldown = 5,
				manaCost = 40,
				range = 28,
				radius = 14,
				damage = 70,
				heal = 0,
			}),
			W = ability("W", "Board Meeting", "Call a quick huddle and mend yourself.", "heal", {
				cooldown = 10,
				manaCost = 50,
				range = 8,
				radius = 8,
				damage = 0,
				heal = 90,
			}),
			E = ability("E", "Hostile Takeover", "Dash-pounce toward a point.", "dash", {
				cooldown = 8,
				manaCost = 35,
				range = 36,
				radius = 8,
				damage = 40,
				heal = 0,
			}),
			R = ability("R", "Executive Order", "Massive AoE decree that hurts the other board.", "damage", {
				cooldown = 40,
				manaCost = 100,
				range = 32,
				radius = 20,
				damage = 160,
				heal = 0,
			}),
		},
	},

	NyanRocket = {
		id = "NyanRocket",
		name = "Nyan Rocket",
		title = "Pop-Star Assassin",
		role = "Assassin",
		blurb = "Leaves a rainbow trail and deletes the backline before the beat drops.",
		color = Color3.fromRGB(255, 105, 180),
		maxHealth = 620,
		maxMana = 340,
		abilities = {
			Q = ability("Q", "Rainbow Dash", "A sparkling poke along the rainbow.", "damage", {
				cooldown = 4,
				manaCost = 35,
				range = 42,
				radius = 8,
				damage = 80,
				heal = 0,
			}),
			W = ability("W", "Warp Trail", "Blink-dash through the beat.", "dash", {
				cooldown = 9,
				manaCost = 40,
				range = 40,
				radius = 6,
				damage = 30,
				heal = 0,
			}),
			E = ability("E", "Pixel Slash", "Close-range crit slash.", "damage", {
				cooldown = 6,
				manaCost = 30,
				range = 18,
				radius = 10,
				damage = 95,
				heal = 0,
			}),
			R = ability("R", "Hyperbeam", "Channel the entire 2000s into one laser.", "damage", {
				cooldown = 50,
				manaCost = 120,
				range = 50,
				radius = 12,
				damage = 220,
				heal = 0,
			}),
		},
	},

	ChonkKnight = {
		id = "ChonkKnight",
		name = "Chonk Knight",
		title = "Loaf of the Rift",
		role = "Bruiser",
		blurb = "A heavily armored loaf. What he lacks in speed, he makes up in gravity.",
		color = Color3.fromRGB(232, 168, 88),
		maxHealth = 900,
		maxMana = 240,
		abilities = {
			Q = ability("Q", "Chonk Charge", "Roll forward and bowl people over.", "dash", {
				cooldown = 7,
				manaCost = 35,
				range = 32,
				radius = 10,
				damage = 65,
				heal = 0,
			}),
			W = ability("W", "Loaf Guard", "Tuck in and regenerate.", "heal", {
				cooldown = 12,
				manaCost = 45,
				range = 6,
				radius = 6,
				damage = 0,
				heal = 110,
			}),
			E = ability("E", "Belly Flop", "Airborne slam. Physics optional.", "damage", {
				cooldown = 8,
				manaCost = 40,
				range = 22,
				radius = 16,
				damage = 90,
				heal = 0,
			}),
			R = ability("R", "Maximum Chonk", "Become the objective.", "damage", {
				cooldown = 45,
				manaCost = 90,
				range = 24,
				radius = 22,
				damage = 180,
				heal = 40,
			}),
		},
	},

	ProfessorWhiskers = {
		id = "ProfessorWhiskers",
		name = "Professor Whiskers",
		title = "Lane Tutor",
		role = "Mage",
		blurb = "Corrects your last-hits and your life choices with a laser pointer.",
		color = Color3.fromRGB(90, 122, 180),
		maxHealth = 640,
		maxMana = 420,
		abilities = {
			Q = ability("Q", "Lecture Laser", "A precise beam of unsolicited advice.", "damage", {
				cooldown = 4,
				manaCost = 45,
				range = 48,
				radius = 7,
				damage = 85,
				heal = 0,
			}),
			W = ability("W", "Extra Credit", "Grade-curve heal for an ally or yourself.", "heal", {
				cooldown = 9,
				manaCost = 55,
				range = 36,
				radius = 10,
				damage = 0,
				heal = 100,
			}),
			E = ability("E", "Pop Quiz", "Zone the lane with confusing diagrams.", "damage", {
				cooldown = 8,
				manaCost = 50,
				range = 34,
				radius = 16,
				damage = 70,
				heal = 0,
			}),
			R = ability("R", "Tenure Storm", "Final exam, entire river.", "damage", {
				cooldown = 55,
				manaCost = 130,
				range = 40,
				radius = 22,
				damage = 200,
				heal = 0,
			}),
		},
	},

	ScammyMcMittens = {
		id = "ScammyMcMittens",
		name = "Scammy McMittens",
		title = "Certified Financial Menace",
		role = "Marksman",
		blurb = "Pokes from fog, then rugs the wave. Trust him, bro.",
		color = Color3.fromRGB(120, 200, 90),
		maxHealth = 600,
		maxMana = 300,
		abilities = {
			Q = ability("Q", "Pump & Dump", "A long-range candle wick of damage.", "damage", {
				cooldown = 3.5,
				manaCost = 30,
				range = 50,
				radius = 6,
				damage = 75,
				heal = 0,
			}),
			W = ability("W", "Rug Pull", "Dash out of the thread.", "dash", {
				cooldown = 10,
				manaCost = 40,
				range = 34,
				radius = 6,
				damage = 20,
				heal = 0,
			}),
			E = ability("E", "Hype Candle", "Splash poke around the aim point.", "damage", {
				cooldown = 7,
				manaCost = 40,
				range = 38,
				radius = 14,
				damage = 80,
				heal = 0,
			}),
			R = ability("R", "Market Crash", "Everyone's portfolio, and HP, dumps.", "damage", {
				cooldown = 60,
				manaCost = 110,
				range = 46,
				radius = 18,
				damage = 210,
				heal = 0,
			}),
		},
	},

	GrandmaFluff = {
		id = "GrandmaFluff",
		name = "Grandma Fluff",
		title = "Enchanter of the Den",
		role = "Support",
		blurb = "Keeps the squad fed, shielded, and slightly judged.",
		color = Color3.fromRGB(245, 214, 186),
		maxHealth = 680,
		maxMana = 380,
		abilities = {
			Q = ability("Q", "Warm Milk", "A soothing sip that heals.", "heal", {
				cooldown = 6,
				manaCost = 40,
				range = 32,
				radius = 10,
				damage = 0,
				heal = 85,
			}),
			W = ability("W", "Knitted Sweater", "Wrap an ally in +2 defense and leftovers.", "heal", {
				cooldown = 11,
				manaCost = 50,
				range = 34,
				radius = 8,
				damage = 0,
				heal = 120,
			}),
			E = ability("E", "No Running", "Scold enemies in a cone-ish splash.", "damage", {
				cooldown = 8,
				manaCost = 45,
				range = 26,
				radius = 14,
				damage = 60,
				heal = 0,
			}),
			R = ability("R", "Sunday Dinner", "The whole team sits down and recovers.", "heal", {
				cooldown = 50,
				manaCost = 100,
				range = 28,
				radius = 24,
				damage = 0,
				heal = 160,
			}),
		},
	},
}

local ORDER = {
	"ChairmanMeow",
	"NyanRocket",
	"ChonkKnight",
	"ProfessorWhiskers",
	"ScammyMcMittens",
	"GrandmaFluff",
}

local ChampionCatalog = {}

function ChampionCatalog.get(id: string): Types.ChampionDef?
	return CATALOG[id]
end

function ChampionCatalog.all(): { Types.ChampionDef }
	local list = {}
	for _, id in ORDER do
		table.insert(list, CATALOG[id])
	end
	return list
end

function ChampionCatalog.ids(): { string }
	return table.clone(ORDER)
end

function ChampionCatalog.defaultId(): string
	return ORDER[1]
end

return ChampionCatalog
