-- Tab scoreboard paint helpers. Run through tools/test-scoreboard.py.

local function rgbEq(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

assert(ScoreboardPaint.isDead(nil, 100) == false)
assert(ScoreboardPaint.isDead(50, 100) == false, "past respawn is alive")
assert(ScoreboardPaint.isDead(150, 100) == true, "future respawn is dead")

assert(ScoreboardPaint.itemShort("Longclaw") == "LC")
assert(ScoreboardPaint.itemShort("ControlYarn") == "Pink")
assert(ScoreboardPaint.itemShort("Mystery") == "Mystery")

assert(ScoreboardPaint.itemsLine({}) == "—")
assert(ScoreboardPaint.itemsLine({ "Longclaw", "Longclaw", "Yarnplate" }) == "LC×2 · YP")
local packed = ScoreboardPaint.itemsLine({
	"Longclaw",
	"Yarnplate",
	"ManaTreat",
	"PounceBoots",
	"WhiskerLens",
	"ControlYarn",
	"YarnCleave",
	"StallFang",
	"PaperCharm",
}, 28)
assert(string.find(packed, "…", 1, true) ~= nil, "long item rows truncate with ellipsis")
assert(#packed <= 28, "items stay inside the column budget")

assert(ScoreboardPaint.catLabel("Whiskers", false, true, false) == "YOU · Whiskers")
assert(ScoreboardPaint.catLabel("Nib", true, false, false) == "Nib (Bot)")
assert(ScoreboardPaint.catLabel("Nib (Bot)", true, false, false) == "Nib (Bot)")
assert(ScoreboardPaint.catLabel("Whiskers", false, true, true) == "★ YOU · Whiskers")
assert(ScoreboardPaint.catLabel("Whiskers", false, false, true) == "★ Whiskers")

assert(ScoreboardPaint.sectionTitle("Blue") == "BLUE · Whiskers")
assert(ScoreboardPaint.sectionTitle("Red") == "RED · Paws")
assert(rgbEq(ScoreboardPaint.teamRgb("Blue"), ScoreboardPaint.Blue))
assert(rgbEq(ScoreboardPaint.teamRgb("Red"), ScoreboardPaint.Red))

local you = ScoreboardPaint.rowPaint("Blue", true, false, false)
assert(you.kind == "you")
assert(rgbEq(you.fill, ScoreboardPaint.Amber))
assert(you.fillAlpha < 0.9)

local youDead = ScoreboardPaint.rowPaint("Blue", true, true, false)
assert(youDead.kind == "you")
assert(rgbEq(youDead.text, ScoreboardPaint.Muted), "dead YOU still dims")

local dead = ScoreboardPaint.rowPaint("Red", false, true, false)
assert(dead.kind == "dead")
assert(rgbEq(dead.text, ScoreboardPaint.Muted))
assert(dead.textAlpha > 0)

local crown = ScoreboardPaint.rowPaint("Blue", false, false, true)
assert(crown.kind == "crown")
assert(rgbEq(crown.stroke, ScoreboardPaint.Amber))

local alive = ScoreboardPaint.rowPaint("Red", false, false, false)
assert(alive.kind == "alive")
assert(alive.fillAlpha == 1)

-- Soft mid-fight crown prefers living kill lead; mvpUserId wins when set.
local players = {
	{ userId = 1, kills = 8, damageDealt = 100, gold = 500, respawnAt = 999 },
	{ userId = 2, kills = 5, damageDealt = 50, gold = 400, respawnAt = nil },
	{ userId = 3, kills = 5, damageDealt = 80, gold = 450, respawnAt = nil },
}
assert(ScoreboardPaint.crownUserId(players, 100, nil) == 3, "alive damage lead over dead kill lead")
assert(ScoreboardPaint.crownUserId(players, 100, 1) == 1, "end-screen mvpUserId wins")

assert(
	ScoreboardPaint.totalsLine(3, 40, 900, 2, 30, 700)
		== "Blue  3 kills · 40 CS · 900g     Red  2 kills · 30 CS · 700g"
)

print("scoreboard paint ok")
