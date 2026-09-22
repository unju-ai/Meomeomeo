-- Run through tools/test-ping.py against PingLogic.

assert(PingLogic.CooldownSeconds == 2)
assert(PingLogic.cooling(0) == true)
assert(PingLogic.cooling(1.25) == true)
assert(PingLogic.cooling(1.99) == true)
assert(PingLogic.cooling(2) == false)
assert(PingLogic.cooling(3) == false)

assert(PingLogic.markerFor("Outer") == "post")
assert(PingLogic.markerFor("Inner") == "stall")
assert(PingLogic.markerFor("Core") == "core")
assert(PingLogic.markerFor(nil) == "dot")
assert(PingLogic.markerFor("Lane") == "dot")

assert(PingLogic.compose("⚠", "Caution", "Caution", "Nyan Rocket") == "⚠ Caution · Nyan Rocket")
assert(PingLogic.compose("⚔", "Attack", "Attack here", "lantern stall") == "⚔ Attack · lantern stall")
assert(PingLogic.compose("⚔", "Attack", "Attack here", nil) == "⚔ Attack here")
assert(PingLogic.compose("⚔", "Attack", "Attack here", "") == "⚔ Attack here")
assert(PingLogic.compose("📍", "Attention", "Attention", nil) == "📍 Attention")
assert(PingLogic.ticker("Alex", "⚠", "Caution", "Caution", "Nyan Rocket") == "Alex: ⚠ Caution · Nyan Rocket")
assert(PingLogic.ticker("Alex", "?", "Missing", "Enemy missing", nil) == "Alex: ? Enemy missing")

local function decide(kind: string, source: string, hit: string, visible: boolean, tier: string?, alive: boolean?)
	return PingLogic.resolve({
		kind = kind,
		source = source,
		hit = hit,
		visible = visible,
		tier = tier,
		alive = alive,
	})
end

-- Attention on a fogged enemy body refuses. Same spirit as an auto-attack.
local hidden = decide("Attention", "world", "enemy", false, nil, nil)
assert(hidden.ok == false)
assert(hidden.error == "No vision.")
assert(hidden.named == false)

-- Ground and minimap into fog stay legal and unnamed, including Missing.
local ground = decide("Attention", "world", "ground", false, nil, nil)
assert(ground.ok == true)
assert(ground.named == false)
assert(ground.marker == "dot")

local mapAttention = decide("Attention", "minimap", "ground", false, nil, nil)
assert(mapAttention.ok == true)
assert(mapAttention.named == false)

local mapMissing = decide("EnemyMissing", "minimap", "ground", false, nil, nil)
assert(mapMissing.ok == true)
assert(mapMissing.named == false)

-- A minimap click does not attach even if a body id was stuffed into the query.
local mapBody = decide("Attention", "minimap", "enemy", false, nil, nil)
assert(mapBody.ok == true)
assert(mapBody.named == false)

local missingBody = decide("EnemyMissing", "world", "enemy", false, nil, nil)
assert(missingBody.ok == true)
assert(missingBody.named == false)
assert(missingBody.marker == "dot")

local cautionHidden = decide("Caution", "world", "enemy", false, nil, nil)
assert(cautionHidden.ok == true)
assert(cautionHidden.named == false)

local visibleEnemy = decide("Caution", "world", "enemy", true, nil, nil)
assert(visibleEnemy.ok == true)
assert(visibleEnemy.named == true)
assert(visibleEnemy.marker == "dot")

local ally = decide("Assist", "world", "ally", true, nil, nil)
assert(ally.ok == true)
assert(ally.named == true)

local stall = decide("AttackHere", "world", "structure", true, "Inner", true)
assert(stall.ok == true)
assert(stall.named == true)
assert(stall.marker == "stall")

local post = decide("AttackHere", "world", "structure", true, "Outer", true)
assert(post.ok == true)
assert(post.named == true)
assert(post.marker == "post")

local core = decide("Attention", "world", "structure", true, "Core", true)
assert(core.ok == true)
assert(core.named == true)
assert(core.marker == "core")

local rubble = decide("AttackHere", "world", "structure", true, "Inner", false)
assert(rubble.ok == true)
assert(rubble.named == false)
assert(rubble.marker == "dot")

local ward = decide("Caution", "world", "ward", true, nil, true)
assert(ward.ok == true)
assert(ward.named == true)
assert(ward.marker == "dot")

local hiddenWard = decide("Caution", "world", "ward", false, nil, true)
assert(hiddenWard.ok == true)
assert(hiddenWard.named == false)

local camp = decide("OnMyWay", "world", "camp", true, nil, true)
assert(camp.ok == true)
assert(camp.named == true)

local hiddenCamp = decide("OnMyWay", "world", "camp", false, nil, true)
assert(hiddenCamp.ok == true)
assert(hiddenCamp.named == false)

print("ping smoke ok")
