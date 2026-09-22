-- Cat Rift outer posts, inner lantern stalls, and yarn-core gates.
-- Run through tools/test-structure.py.

local function aliveUp(): { [string]: boolean }
	local alive: { [string]: boolean } = {}
	for _, def in StructureLogic.defs() do
		alive[def.id] = true
	end
	return alive
end

local defs = StructureLogic.defs()
assert(#defs == 14, "3 posts + 3 stalls + 1 core, each team")
assert(StructureLogic.towersPerTeam() == 6, "six towers gate each yarn core")

local seen: { [string]: boolean } = {}
for _, def in defs do
	assert(seen[def.id] ~= true, "structure ids are unique")
	seen[def.id] = true
	local sign = if def.team == "Blue" then -1 else 1
	assert(def.x * sign > 0, "Blue stays west, Red stays east")
	if def.kind == "Tower" then
		assert(def.z == StructureLogic.LaneZ[def.lane], "towers sit on their lane")
		assert(math.abs(def.x) < StructureLogic.MinionTurnX, "kittens reach the tower before cutting to the core")
		assert(math.abs(def.x) < StructureLogic.KeepGateX, "towers stand outside the fountain yard")
	end
end

for _, team in { "Blue", "Red" } do
	for _, lane in StructureLogic.Lanes do
		local outer = StructureLogic.get(`{team}{lane}Outer`)
		local inner = StructureLogic.get(`{team}{lane}Inner`)
		local core = StructureLogic.get(`{team}Nexus`)
		assert(outer ~= nil and inner ~= nil and core ~= nil, "each lane has a post, a stall, and a core")
		assert(outer.tier == "Outer" and inner.tier == "Inner" and core.tier == "Core")
		assert(math.abs(inner.x) > math.abs(outer.x), "stall is closer to base than the post")
		assert(math.abs(core.x) > math.abs(inner.x), "yarn core is behind the stall")
		assert(outer.maxHealth == StructureLogic.OuterHealth)
		assert(inner.maxHealth > outer.maxHealth, "stalls are tougher than posts")
		assert(StructureLogic.damageFor("Tower", "Inner") > StructureLogic.damageFor("Tower", "Outer"))
		assert(StructureLogic.rangeFor("Tower", "Inner") == StructureLogic.InnerRange)
		assert(StructureLogic.rangeFor("Tower", "Outer") == StructureLogic.OuterRange)
		assert(StructureLogic.rangeFor("Nexus", "Core") == StructureLogic.NexusRange)

		-- River-side auto-attack on the post should not pull the stall.
		local approach = if team == "Blue" then 1 else -1
		local siegePost = outer.x + approach * StructureLogic.AttackRange
		local postGap = math.abs(siegePost - inner.x)
		assert(postGap > StructureLogic.InnerRange, `{team} {lane} stall does not cover a post siege`)

		-- River-side auto-attack on the stall should not pull the yarn core.
		local siegeStall = inner.x + approach * StructureLogic.AttackRange
		local coreGap = math.abs(siegeStall - core.x)
		assert(coreGap > StructureLogic.NexusRange, `{team} {lane} core does not cover a stall siege`)
	end
end

local alive = aliveUp()
local redMidStall = StructureLogic.get("RedMidInner")
local redMidPost = StructureLogic.get("RedMidOuter")
local redCore = StructureLogic.get("RedNexus")
local redTopStall = StructureLogic.get("RedTopInner")
assert(redMidStall and redMidPost and redCore and redTopStall)

assert(StructureLogic.isVulnerable(redMidPost, alive) == true, "posts start open")
assert(StructureLogic.isVulnerable(redMidStall, alive) == false, "stall stays dark while its post stands")
assert(StructureLogic.isVulnerable(redCore, alive) == false, "core stays gated")
assert(string.find(StructureLogic.billboard(redMidStall, false), "Lantern Stall", 1, true) ~= nil)
assert(string.find(StructureLogic.billboard(redMidStall, false), "(gated)", 1, true) ~= nil)
assert(string.find(StructureLogic.billboard(redMidStall, true), "(gated)", 1, true) == nil)
assert(StructureLogic.billboard(redMidPost, true) == "Red Tower (Mid)")

alive[redMidPost.id] = false
assert(StructureLogic.isVulnerable(redMidStall, alive) == true, "mid stall lights when the mid post falls")
assert(StructureLogic.isVulnerable(redTopStall, alive) == false, "top stall waits for the top post")
assert(StructureLogic.isVulnerable(redCore, alive) == false, "one post does not open the core")

local blueStall = StructureLogic.get("BlueMidInner")
assert(blueStall ~= nil)
assert(StructureLogic.isVulnerable(blueStall, alive) == false, "the other team's stall stays dark")

for _, def in StructureLogic.defs() do
	if def.team == "Red" and def.kind == "Tower" then
		alive[def.id] = false
	end
end
assert(StructureLogic.isVulnerable(redCore, alive) == true, "core opens after every post and stall")
assert(StructureLogic.billboard(redCore, true) == "Red Nexus (OPEN)")
assert(StructureLogic.billboard(redCore, false) == "Red Nexus (gated)")

alive = aliveUp()
alive["RedTopOuter"] = false
alive["RedMidOuter"] = false
alive["RedBotOuter"] = false
assert(StructureLogic.isVulnerable(redCore, alive) == false, "posts alone do not open the core")

assert(StructureLogic.deathLine("Miso", redMidPost) == "Miso knocked over the Red scratching post")
assert(StructureLogic.deathLine("Miso", redMidStall) == "Miso snuffed the Red Mid lantern stall")
assert(string.find(StructureLogic.deathLine("Miso", redCore), "yarn core", 1, true) ~= nil)
assert(StructureLogic.pingName(redMidStall) == "Red Mid lantern stall")
assert(StructureLogic.fallLabel("Inner", "Bot") == "Bot stall")
assert(StructureLogic.fallLabel("Outer", "Top") == "Top post")
assert(StructureLogic.fallLabel("Core", "Base") == "yarn core")

-- A missing tower id still counts as standing.
local partial: { [string]: boolean } = { RedNexus = true }
assert(StructureLogic.isVulnerable(redCore, partial) == false, "unknown towers do not count as down")

-- Night-market HP bar visibility (Shared.BillboardHp). Presentation is client-side.
assert(BillboardHp.formatHp(842.7, 1400) == "842 / 1400")
assert(BillboardHp.damaged(1400, 1400) == false)
assert(BillboardHp.damaged(1399, 1400) == true)
assert(BillboardHp.fillTone(0.2) == "coral")
assert(BillboardHp.fillTone(0.4) == "amber")
assert(BillboardHp.fillTone(0.9) == "cream")
assert(BillboardHp.structureTitle("Outer", "Mid") == "Mid post")
assert(BillboardHp.structureTitle("Inner", "Bot") == "Bot stall")
assert(BillboardHp.structureTitle("Core", "Base") == "Yarn core")
assert(string.find(BillboardHp.structureCaption("Mid post", "100 / 1400", true), "(gated)", 1, true) ~= nil)
assert(string.find(BillboardHp.structureCaption("Mid post", "100 / 1400", false), "(gated)", 1, true) == nil)
assert(BillboardHp.epicCaption("Canal Levi", "1100 / 1100") == "Canal Levi  1100 / 1100")
assert(BillboardHp.campCaption("Pigeon Pack", "40 / 95") == "Pigeon Pack  40 / 95")
assert(BillboardHp.MaxUnitBars >= 16)

local blueFill = BillboardHp.teamFillRgb("cream", "Blue")
local redFill = BillboardHp.teamFillRgb("cream", "Red")
local plainFill = BillboardHp.teamFillRgb("cream", nil)
assert(blueFill[3] > plainFill[3], "Blue kitten fill leans cooler")
assert(redFill[2] < plainFill[2], "Red kitten fill pulls green down toward coral")
assert(blueFill[3] ~= redFill[3], "Blue and Red kitten washes differ")

assert(
	BillboardHp.showStructure({
		alive = true,
		ally = false,
		inVision = false,
		damaged = true,
		aimed = false,
	}) == false,
	"enemy structure HP stays hidden in fog"
)
assert(
	BillboardHp.showStructure({
		alive = true,
		ally = true,
		inVision = false,
		damaged = true,
		aimed = false,
	}) == true,
	"ally structure HP can stay visible through fog"
)
assert(
	BillboardHp.showStructure({
		alive = true,
		ally = false,
		inVision = true,
		damaged = false,
		aimed = false,
	}) == false,
	"full enemy post stays quiet until damaged or aimed"
)
assert(
	BillboardHp.showStructure({
		alive = true,
		ally = false,
		inVision = true,
		damaged = false,
		aimed = true,
	}) == true,
	"aiming a visible enemy post shows the bar"
)
assert(
	BillboardHp.showStructure({
		alive = true,
		ally = false,
		inVision = true,
		damaged = true,
		aimed = false,
	}) == true,
	"damaged enemy post in vision shows the bar"
)
assert(
	BillboardHp.showStructure({
		alive = false,
		ally = false,
		inVision = true,
		damaged = false,
		aimed = true,
	}) == false,
	"fallen structures do not keep an HP bar"
)
assert(BillboardHp.showEpic({ alive = true, inVision = true }) == true, "Levi UP in vision shows the epic bar")
assert(BillboardHp.showEpic({ alive = true, inVision = false }) == false, "Levi HP does not pierce fog")
assert(BillboardHp.showEpic({ alive = false, inVision = true }) == false, "spent Levi has no bar")

assert(
	BillboardHp.showKitten({
		alive = true,
		ally = false,
		inVision = false,
		damaged = true,
		aimed = false,
	}) == false,
	"enemy kitten HP stays hidden in fog"
)
assert(
	BillboardHp.showKitten({
		alive = true,
		ally = true,
		inVision = false,
		damaged = true,
		aimed = false,
	}) == true,
	"ally kitten HP can stay visible through fog"
)
assert(
	BillboardHp.showKitten({
		alive = true,
		ally = false,
		inVision = true,
		damaged = false,
		aimed = false,
	}) == false,
	"full healthy kitten stays quiet until damaged or aimed"
)
assert(
	BillboardHp.showKitten({
		alive = true,
		ally = false,
		inVision = true,
		damaged = false,
		aimed = true,
	}) == true,
	"aiming a visible enemy kitten shows the bar"
)
assert(
	BillboardHp.showKitten({
		alive = true,
		ally = false,
		inVision = true,
		damaged = true,
		aimed = false,
	}) == true,
	"damaged enemy kitten in vision shows the bar"
)
assert(
	BillboardHp.showKitten({
		alive = false,
		ally = false,
		inVision = true,
		damaged = false,
		aimed = true,
	}) == false,
	"dead kittens do not keep an HP bar"
)

assert(
	BillboardHp.showCamp({
		alive = true,
		inVision = false,
		damaged = true,
		inCombat = false,
	}) == false,
	"camp HP stays hidden in fog"
)
assert(
	BillboardHp.showCamp({
		alive = true,
		inVision = true,
		damaged = false,
		inCombat = false,
	}) == false,
	"idle full camp stays quiet"
)
assert(
	BillboardHp.showCamp({
		alive = true,
		inVision = true,
		damaged = true,
		inCombat = false,
	}) == true,
	"damaged camp in vision shows the bar"
)
assert(
	BillboardHp.showCamp({
		alive = true,
		inVision = true,
		damaged = false,
		inCombat = true,
	}) == true,
	"camp in combat (aim or aggro) shows the bar"
)
assert(
	BillboardHp.showCamp({
		alive = false,
		inVision = true,
		damaged = false,
		inCombat = true,
	}) == false,
	"spent camp has no bar"
)
-- Levi stays on showEpic, not the small-camp rule.
assert(BillboardHp.showEpic({ alive = true, inVision = true }) == true, "Levi still uses the epic rule")

-- Champion nameplate visibility + labels (Shared.ChampionPlate). Client paints fill.
assert(ChampionPlate.GuiName == "MeoNameplate")
assert(ChampionPlate.nameLine("Professor Whiskers", false, false) == "Professor Whiskers")
assert(ChampionPlate.nameLine("Professor Whiskers", true, false) == "Professor Whiskers (Bot)")
assert(ChampionPlate.nameLine("Professor Whiskers", false, true) == "YOU · Professor Whiskers")
assert(ChampionPlate.nameLine("Bytekit", true, true) == "YOU · Bytekit (Bot)")
assert(ChampionPlate.tagLine("Mage", nil) == "Mage")
assert(ChampionPlate.tagLine("Mage", "Office hours") == "Mage · Office hours")
assert(ChampionPlate.MaxPlates >= 8)

assert(
	ChampionPlate.show({
		alive = true,
		ally = false,
		inVision = false,
	}) == false,
	"enemy champion plate stays hidden in fog (same as AA refuse)"
)
assert(
	ChampionPlate.show({
		alive = true,
		ally = true,
		inVision = false,
	}) == true,
	"ally champion plate can stay visible through fog"
)
assert(
	ChampionPlate.show({
		alive = true,
		ally = false,
		inVision = true,
	}) == true,
	"enemy champion plate shows in vision"
)
assert(
	ChampionPlate.show({
		alive = false,
		ally = true,
		inVision = true,
	}) == false,
	"dead champions do not keep a nameplate"
)

local bluePlate = ChampionPlate.teamFillRgb("cream", "Blue")
local redPlate = ChampionPlate.teamFillRgb("cream", "Red")
assert(bluePlate[3] ~= redPlate[3], "champion plate fill reuses Blue/Red team wash")
local keyA = ChampionPlate.paintKey(100, 200, true, "A", "Mage", "Blue")
local keyB = ChampionPlate.paintKey(100, 200, true, "A", "Mage", "Blue")
local keyC = ChampionPlate.paintKey(50, 200, true, "A", "Mage", "Blue")
assert(keyA == keyB, "unchanged plate paint key is stable")
assert(keyA ~= keyC, "HP change dirties the plate paint key")

-- Structure-take juice. Paint only: HP and isVulnerable stay the gate.
assert(StructureLogic.OuterHealth == 1400, "post HP is unchanged")
assert(StructureLogic.InnerHealth == 1850, "stall HP is unchanged")
assert(StructureLogic.NexusHealth == 2200, "core HP is unchanged")
assert(StructureDeathJuice.modeAllows("Moba", "InProgress") == true)
assert(StructureDeathJuice.modeAllows("Moba", "Ended") == true, "yarn-core blow still paints as the match ends")
assert(StructureDeathJuice.modeAllows("Moba", "Lobby") == false)
assert(StructureDeathJuice.modeAllows("Moba", "ChampionSelect") == false)
assert(StructureDeathJuice.modeAllows("Hub", "InProgress") == false)
assert(StructureDeathJuice.modeAllows("YarnRun", "InProgress") == false)
assert(StructureDeathJuice.modeAllows("KoiPond", "InProgress") == false)
assert(StructureDeathJuice.modeAllows("YarnParty", "InProgress") == false)
assert(StructureDeathJuice.modeAllows("MemeArcade", "InProgress") == false)
assert(StructureDeathJuice.look("Tower", "Outer") == "post")
assert(StructureDeathJuice.look("Tower", "Inner") == "stall")
assert(StructureDeathJuice.look("Nexus", "Core") == "core")
assert(StructureDeathJuice.look("Tower", nil) == "post")
assert(StructureDeathJuice.shouldPaint(true, false, false) == true, "ally structure takes paint through fog")
assert(StructureDeathJuice.shouldPaint(false, true, false) == true, "enemy take paints when the site is lit")
assert(StructureDeathJuice.shouldPaint(false, false, true) == true, "enemy take paints if the site was just lit")
assert(StructureDeathJuice.shouldPaint(false, false, false) == false, "fogged enemy takes stay quiet")
assert(StructureDeathJuice.shouldPaint(false, false, nil) == false)

local postPalette = StructureDeathJuice.palette("post")
local stallPalette = StructureDeathJuice.palette("stall")
local corePalette = StructureDeathJuice.palette("core")
local gatePalette = StructureDeathJuice.gatePalette()
assert(postPalette[1][1] == StructureDeathJuice.Wood[1], "posts shatter wood")
assert(postPalette[2][1] == StructureDeathJuice.Cream[1], "posts collapse cream")
assert(stallPalette[1][1] == StructureDeathJuice.Lantern[1], "stalls burst lantern")
assert(stallPalette[1][2] < postPalette[2][2], "stall lantern is warmer than cream dust")
assert(stallPalette[1][3] < StructureDeathJuice.Wood[3], "stall lantern is more orange than post wood")
assert(corePalette[1][1] == StructureDeathJuice.Yarn[1] and corePalette[1][3] > 150, "core unravels pink yarn")
assert(gatePalette[1][2] > gatePalette[1][1], "gate cue leads with mint")
assert(gatePalette[2][1] == StructureDeathJuice.GateWood[1], "gate cue keeps a wood edge")
assert(gatePalette[1][1] ~= StructureDeathJuice.Yarn[1], "a gate open is not another yarn burst")
assert(StructureDeathJuice.pieceCount("post") == 7)
assert(StructureDeathJuice.pieceCount("stall") == 6)
assert(StructureDeathJuice.pieceCount("core") == 8)
assert(StructureDeathJuice.pieceCount("post") ~= StructureDeathJuice.pieceCount("stall"))
assert(StructureDeathJuice.pieceCount("stall") ~= StructureDeathJuice.pieceCount("core"))
assert(StructureDeathJuice.life("core") > StructureDeathJuice.life("post"))
assert(StructureDeathJuice.GateSeconds < StructureDeathJuice.life("post"), "gate open is the short calm cue")
assert(StructureDeathJuice.thumpIsLocal() == true)
assert(StructureDeathJuice.wantsThump(false, 8) == false)
assert(StructureDeathJuice.wantsThump(true, nil) == false)
assert(StructureDeathJuice.wantsThump(true, 20) == true)
assert(StructureDeathJuice.wantsThump(true, StructureDeathJuice.ThumpRadius + 1) == false)
assert(StructureDeathJuice.thumpAmp("post") < 0.28)
assert(StructureDeathJuice.thumpAmp("core") > StructureDeathJuice.thumpAmp("stall"))

local function sameIds(got, expect): boolean
	if #got ~= #expect then
		return false
	end
	for i, id in got do
		if expect[i] ~= id then
			return false
		end
	end
	return true
end

local function aliveAfterFall(fallenId: string): { [string]: boolean }
	local alive = aliveUp()
	alive[fallenId] = false
	return alive
end

local midPostDown = aliveAfterFall("RedMidOuter")
assert(sameIds(StructureDeathJuice.openedIds("RedMidOuter", midPostDown), { "RedMidInner" }), "a post opens only its lane stall")
assert(StructureLogic.isVulnerable(redMidStall, midPostDown) == true)
assert(StructureLogic.isVulnerable(redCore, midPostDown) == false)

local topOnly = aliveAfterFall("RedTopOuter")
assert(sameIds(StructureDeathJuice.openedIds("RedTopOuter", topOnly), { "RedTopInner" }))
local blueOnly = aliveAfterFall("BlueBotOuter")
assert(sameIds(StructureDeathJuice.openedIds("BlueBotOuter", blueOnly), { "BlueBotInner" }))
assert(StructureDeathJuice.openedIds("nope", midPostDown) ~= nil and #StructureDeathJuice.openedIds("nope", midPostDown) == 0)

-- A stall that is already down does not get a second open cue.
local postAndStall = aliveAfterFall("RedMidOuter")
postAndStall["RedMidInner"] = false
assert(#StructureDeathJuice.openedIds("RedMidOuter", postAndStall) == 0, "a fallen stall is not opened again")

-- Last standing tower opens the core and nothing else.
local lastStall = aliveUp()
for _, def in StructureLogic.defs() do
	if def.team == "Red" and def.kind == "Tower" and def.id ~= "RedBotInner" then
		lastStall[def.id] = false
	end
end
assert(StructureLogic.isVulnerable(redCore, lastStall) == false, "one stall still gates the core")
lastStall["RedBotInner"] = false
assert(sameIds(StructureDeathJuice.openedIds("RedBotInner", lastStall), { "RedNexus" }), "the last tower opens the yarn core")

local coreDown = aliveUp()
for _, def in StructureLogic.defs() do
	if def.team == "Red" then
		coreDown[def.id] = false
	end
end
assert(#StructureDeathJuice.openedIds("RedNexus", coreDown) == 0, "the core opens nothing further")

-- Structure lock juice. Paint only: range, damage, and pick order stay in TowerService.
assert(StructureLogic.OuterRange == 44 and StructureLogic.OuterDamage == 50, "post shot numbers stay put")
assert(StructureLogic.InnerRange == 40 and StructureLogic.InnerDamage == 64, "stall shot numbers stay put")
assert(StructureLogic.NexusRange == 36 and StructureLogic.NexusDamage == 58, "core shot numbers stay put")
assert(StructureAggroJuice.LockAttribute == "MeoLockUserId")
assert(StructureAggroJuice.modeAllows("Moba", "InProgress") == true)
assert(StructureAggroJuice.modeAllows("Moba", "Ended") == false, "lock cue ends with the fight")
assert(StructureAggroJuice.modeAllows("Moba", "Lobby") == false)
assert(StructureAggroJuice.modeAllows("Moba", "ChampionSelect") == false)
assert(StructureAggroJuice.modeAllows("Hub", "InProgress") == false)
assert(StructureAggroJuice.modeAllows("YarnRun", "InProgress") == false)
assert(StructureAggroJuice.modeAllows("KoiPond", "InProgress") == false)
assert(StructureAggroJuice.modeAllows("YarnParty", "InProgress") == false)
assert(StructureAggroJuice.modeAllows("MemeArcade", "InProgress") == false)
assert(StructureAggroJuice.look("Tower", "Outer") == "post")
assert(StructureAggroJuice.look("Tower", "Inner") == "stall")
assert(StructureAggroJuice.look("Nexus", "Core") == "core")
assert(StructureAggroJuice.cueKind(7, 7, true, false) == "local", "you read a lock even if the post is dark")
assert(StructureAggroJuice.cueKind(7, 8, true, true) == "ally", "a visible ally lock is a faint cue")
assert(StructureAggroJuice.cueKind(7, 8, true, false) == "none", "a fogged ally lock stays quiet")
assert(StructureAggroJuice.cueKind(7, 9, false, true) == "none", "an enemy who is the pick is not marked")
assert(StructureAggroJuice.cueKind(7, nil, true, true) == "none", "a kitten bolt is not a champion lock")
assert(StructureAggroJuice.shouldPaint("local") == true)
assert(StructureAggroJuice.shouldPaint("ally") == true)
assert(StructureAggroJuice.shouldPaint("none") == false)
assert(StructureAggroJuice.wantsFootRing("local") == true)
assert(StructureAggroJuice.wantsFootRing("ally") == false, "the foot ring is only yours")
assert(StructureAggroJuice.wantsStructureRing("ally") == true)
assert(StructureAggroJuice.wantsLantern("local", "stall") == true)
assert(StructureAggroJuice.wantsLantern("local", "post") == false, "posts stay a coral ring")
assert(StructureAggroJuice.wantsLantern("local", "core") == false)
assert(StructureAggroJuice.wantsLantern("none", "stall") == false)
assert(StructureAggroJuice.wantsShotFlash("local") == true)
assert(StructureAggroJuice.wantsShotFlash("ally") == true)
assert(StructureAggroJuice.wantsShotFlash("none") == false)
assert(StructureAggroJuice.ringSpan("ally") < StructureAggroJuice.ringSpan("local"))
assert(StructureAggroJuice.ringTransparency("ally") > StructureAggroJuice.ringTransparency("local"))
assert(StructureAggroJuice.lanternTransparency("ally") > StructureAggroJuice.lanternTransparency("local"))
assert(StructureAggroJuice.flashScale("ally") < StructureAggroJuice.flashScale("local"))
assert(StructureAggroJuice.flashRgb()[1] == StructureAggroJuice.Coral[1], "the hit flash is coral, not a new damage number")
assert(StructureAggroJuice.ringRgb()[1] > 200 and StructureAggroJuice.ringRgb()[2] < StructureAggroJuice.ringRgb()[1])
assert(StructureAggroJuice.lanternRgb()[1] > StructureAggroJuice.lanternRgb()[3], "stall glare stays warm")
assert(StructureAggroJuice.LanternLift > 0)
assert(StructureAggroJuice.FootSpan < StructureAggroJuice.RingSpan)

-- Hard core siege reads the same gate. A winning wave on a closed core is still not a walk.
local function coreQuery(def: StructureLogic.Def, aliveMap: { [string]: boolean }, partial: {
	health: number?,
	alive: boolean?,
	allyKittens: number?,
	enemyKittens: number?,
	allyHitters: number?,
	x: number?,
	difficulty: BotCoreLogic.Difficulty?,
}): BotCoreLogic.CoreGoal?
	return BotCoreLogic.pick({
		difficulty = partial.difficulty or "Hard",
		x = if partial.x == nil then def.x - 40 else partial.x,
		z = def.z,
		selfHp = 1,
		retreatHp = 0.16,
		peelCritical = false,
		core = {
			id = def.id,
			x = def.x,
			z = def.z,
			health = if partial.health == nil then def.maxHealth else partial.health,
			maxHealth = def.maxHealth,
			vulnerable = StructureLogic.isVulnerable(def, aliveMap),
			alive = if partial.alive == nil then true else partial.alive,
			allyKittens = partial.allyKittens or 0,
			enemyKittens = partial.enemyKittens or 0,
			allyHitters = partial.allyHitters or 0,
		},
	})
end

local gatedCore = aliveUp()
assert(StructureLogic.isVulnerable(redCore, gatedCore) == false)
assert(coreQuery(redCore, gatedCore, { allyKittens = 3, health = 400, allyHitters = 2 }) == nil, "stalls up keep the core closed")
local openCore = aliveUp()
for _, def in StructureLogic.defs() do
	if def.team == "Red" and def.kind == "Tower" then
		openCore[def.id] = false
	end
end
assert(StructureLogic.isVulnerable(redCore, openCore) == true, "stalls down open the yarn core")
local withWave = coreQuery(redCore, openCore, { allyKittens = 2 })
assert(withWave ~= nil and withWave.id == "RedNexus", "an open core with a winning wave is a Hard goal")
assert(coreQuery(redCore, openCore, {}) == nil, "an open full-HP core with nobody under it stays back")
assert(coreQuery(redCore, openCore, { health = 1100 }) ~= nil, "an open core at half HP is a goal")
assert(coreQuery(redCore, openCore, { allyKittens = 2, difficulty = "Easy" }) == nil, "Easy still ignores an open core")
assert(coreQuery(redCore, openCore, { allyKittens = 2, difficulty = "Normal" }) == nil, "Normal still ignores an open core")
assert(StructureLogic.NexusHealth == 2200 and redCore.maxHealth == 2200, "core HP is unchanged")

print("PASS: inner lantern stalls, lane gates, yarn-core gate, hard core siege gate, structure take juice, structure lock juice, structure/Levi/kitten/camp HP bars, champion plates")
