--!strict

-- Pure helpers for Cat Rift structure-take juice.
-- HP, gold, and which gate opens stay in StructureLogic / CombatService.
-- The client only paints the existing structureDeath event.
-- Hub / Yarn Run / Koi / Party / Arcade stay quiet.

local StructureLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("StructureLogic"))

local StructureDeathJuice = {}

export type Look = "post" | "stall" | "core"
export type Rgb = { number }

-- Night-market wood, cream collapse, warmer lantern, pink yarn, calm mint gate.
StructureDeathJuice.Wood = { 176, 122, 72 }
StructureDeathJuice.Cream = { 255, 243, 224 }
StructureDeathJuice.Lantern = { 255, 154, 42 }
StructureDeathJuice.Yarn = { 255, 92, 196 }
StructureDeathJuice.Mint = { 120, 196, 150 }
StructureDeathJuice.GateWood = { 196, 154, 98 }

-- Display only. These do not change structure HP or gate timing.
StructureDeathJuice.GateSeconds = 0.34
StructureDeathJuice.ThumpRadius = 72
StructureDeathJuice.ThumpSeconds = 0.18
StructureDeathJuice.GroundY = 1.15

-- Cat Rift fight, including the yarn-core blow that flips the match to Ended.
function StructureDeathJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress" or phase == "Ended"
end

function StructureDeathJuice.look(kind: string?, tier: string?): Look
	if kind == "Nexus" or tier == "Core" then
		return "core"
	end
	if tier == "Inner" then
		return "stall"
	end
	return "post"
end

-- Ally-side takes always paint (same as ally structure bars through fog).
-- Enemy takes paint only when the site is in vision now, or was on the previous mask.
function StructureDeathJuice.shouldPaint(allySide: boolean, siteLit: boolean, siteWasLit: boolean?): boolean
	if allySide then
		return true
	end
	if siteLit then
		return true
	end
	return siteWasLit == true
end

function StructureDeathJuice.palette(look: Look): { Rgb }
	if look == "stall" then
		return { StructureDeathJuice.Lantern, StructureDeathJuice.GateWood }
	end
	if look == "core" then
		return { StructureDeathJuice.Yarn, StructureDeathJuice.Cream }
	end
	return { StructureDeathJuice.Wood, StructureDeathJuice.Cream, StructureDeathJuice.Lantern }
end

function StructureDeathJuice.gatePalette(): { Rgb }
	return { StructureDeathJuice.Mint, StructureDeathJuice.GateWood }
end

-- Distinct shard counts so a post, stall, and core are not the same puff.
function StructureDeathJuice.pieceCount(look: Look): number
	if look == "core" then
		return 8
	end
	if look == "stall" then
		return 6
	end
	return 7
end

function StructureDeathJuice.life(look: Look): number
	if look == "core" then
		return 0.55
	end
	if look == "stall" then
		return 0.4
	end
	return 0.42
end

-- aliveAfter[id] == false means that structure has already fallen.
-- A missing id still counts as standing (StructureLogic.isVulnerable).
-- Returns structures that were gated before this fall and are open after, still standing.
function StructureDeathJuice.openedIds(fallenId: string, aliveAfter: { [string]: boolean }): { string }
	local fallen = StructureLogic.get(fallenId)
	if not fallen then
		return {}
	end
	local before: { [string]: boolean } = {}
	for id, up in aliveAfter do
		before[id] = up
	end
	before[fallenId] = true
	local opened: { string } = {}
	for _, def in StructureLogic.defs() do
		if def.team == fallen.team and def.id ~= fallen.id and aliveAfter[def.id] ~= false then
			local wasOpen = StructureLogic.isVulnerable(def, before)
			local nowOpen = StructureLogic.isVulnerable(def, aliveAfter)
			if not wasOpen and nowOpen then
				table.insert(opened, def.id)
			end
		end
	end
	return opened
end

-- Soft extra thump for a viewer already next to a take they can see.
-- The kill-feed shake stays as it was. This one is client-local.
function StructureDeathJuice.wantsThump(painted: boolean, distance: number?): boolean
	if not painted or distance == nil then
		return false
	end
	return distance <= StructureDeathJuice.ThumpRadius
end

function StructureDeathJuice.thumpAmp(look: Look): number
	if look == "core" then
		return 0.34
	end
	return 0.2
end

function StructureDeathJuice.thumpIsLocal(): boolean
	return true
end

return StructureDeathJuice
