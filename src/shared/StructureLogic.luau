--!strict

-- Cat Rift structures: outer scratching posts, inner lantern stalls, then the yarn core.
-- Layout and gate rules only. Shots, aggro, and gold still go through TowerService / CombatService.

local StructureLogic = {}

StructureLogic.OuterHealth = 1400
StructureLogic.InnerHealth = 1850
StructureLogic.NexusHealth = 2200

-- Lane X (absolute). Blue is negative, Red is positive. Same Z as Constants.LaneZ.
StructureLogic.OuterX = 90
StructureLogic.InnerX = 132
StructureLogic.NexusX = 168
StructureLogic.TowerY = 11
StructureLogic.NexusY = 10

StructureLogic.OuterRange = 44
StructureLogic.InnerRange = 40
StructureLogic.NexusRange = 36

StructureLogic.OuterDamage = 50
StructureLogic.InnerDamage = 64
StructureLogic.NexusDamage = 58

-- Minions keep their lane until this |x|, then cut in toward the enemy core.
StructureLogic.MinionTurnX = 145
-- Keep face / mid gate. Stalls sit on the lane, outside the fountain yard.
StructureLogic.KeepGateX = 146
-- River-side auto-attack standoff the stall gap is built around. Matches Config.AutoAttack.Range.
StructureLogic.AttackRange = 26

StructureLogic.Lanes = { "Top", "Mid", "Bot" }
StructureLogic.LaneZ = {
	Top = -80,
	Mid = 0,
	Bot = 80,
}

export type TeamId = "Blue" | "Red"
export type Tier = "Outer" | "Inner" | "Core"
export type Kind = "Tower" | "Nexus"

export type Def = {
	id: string,
	team: TeamId,
	kind: Kind,
	tier: Tier,
	lane: string,
	x: number,
	y: number,
	z: number,
	maxHealth: number,
}

local cached: { Def }? = nil

local function signOf(team: TeamId): number
	return if team == "Blue" then -1 else 1
end

function StructureLogic.defs(): { Def }
	if cached then
		return cached
	end
	local list: { Def } = {}
	for _, team in { "Blue" :: TeamId, "Red" :: TeamId } do
		local sign = signOf(team)
		for _, lane in StructureLogic.Lanes do
			local z = StructureLogic.LaneZ[lane]
			table.insert(list, {
				id = `{team}{lane}Outer`,
				team = team,
				kind = "Tower",
				tier = "Outer",
				lane = lane,
				x = sign * StructureLogic.OuterX,
				y = StructureLogic.TowerY,
				z = z,
				maxHealth = StructureLogic.OuterHealth,
			})
			table.insert(list, {
				id = `{team}{lane}Inner`,
				team = team,
				kind = "Tower",
				tier = "Inner",
				lane = lane,
				x = sign * StructureLogic.InnerX,
				y = StructureLogic.TowerY,
				z = z,
				maxHealth = StructureLogic.InnerHealth,
			})
		end
		table.insert(list, {
			id = `{team}Nexus`,
			team = team,
			kind = "Nexus",
			tier = "Core",
			lane = "Base",
			x = sign * StructureLogic.NexusX,
			y = StructureLogic.NexusY,
			z = 0,
			maxHealth = StructureLogic.NexusHealth,
		})
	end
	cached = list
	return list
end

function StructureLogic.get(id: string): Def?
	for _, def in StructureLogic.defs() do
		if def.id == id then
			return def
		end
	end
	return nil
end

function StructureLogic.outerId(team: TeamId, lane: string): string
	return `{team}{lane}Outer`
end

function StructureLogic.towersPerTeam(): number
	local count = 0
	for _, def in StructureLogic.defs() do
		if def.team == "Blue" and def.kind == "Tower" then
			count += 1
		end
	end
	return count
end

function StructureLogic.rangeFor(kind: Kind, tier: Tier): number
	if kind == "Nexus" or tier == "Core" then
		return StructureLogic.NexusRange
	end
	if tier == "Inner" then
		return StructureLogic.InnerRange
	end
	return StructureLogic.OuterRange
end

function StructureLogic.damageFor(kind: Kind, tier: Tier): number
	if kind == "Nexus" or tier == "Core" then
		return StructureLogic.NexusDamage
	end
	if tier == "Inner" then
		return StructureLogic.InnerDamage
	end
	return StructureLogic.OuterDamage
end

-- alive[id] == false means that structure has fallen.
-- A missing id still counts as standing, so a partial map cannot open the core.
function StructureLogic.isVulnerable(def: Def, alive: { [string]: boolean }): boolean
	if def.kind == "Nexus" then
		for _, other in StructureLogic.defs() do
			if other.team == def.team and other.kind == "Tower" and alive[other.id] ~= false then
				return false
			end
		end
		return true
	end
	if def.tier == "Inner" then
		return alive[StructureLogic.outerId(def.team, def.lane)] == false
	end
	return true
end

function StructureLogic.billboard(def: Def, open: boolean): string
	if def.kind == "Nexus" then
		return if open then `{def.team} Nexus (OPEN)` else `{def.team} Nexus (gated)`
	end
	if def.tier == "Inner" then
		local gate = if open then "" else " (gated)"
		return `{def.team} Lantern Stall ({def.lane}){gate}`
	end
	return `{def.team} Tower ({def.lane})`
end

function StructureLogic.deathLine(who: string, def: Def): string
	if def.kind == "Nexus" then
		return `{who} unplugged the {def.team} yarn core`
	end
	if def.tier == "Inner" then
		return `{who} snuffed the {def.team} {def.lane} lantern stall`
	end
	return `{who} knocked over the {def.team} scratching post`
end

function StructureLogic.pingName(def: Def): string
	if def.kind == "Nexus" then
		return `{def.team} yarn core`
	end
	if def.tier == "Inner" then
		return `{def.team} {def.lane} lantern stall`
	end
	return `{def.team} {def.lane} scratching post`
end

function StructureLogic.fallLabel(tier: Tier, lane: string): string
	if tier == "Core" then
		return "yarn core"
	end
	if tier == "Inner" then
		return `{lane} stall`
	end
	return `{lane} post`
end

return StructureLogic
