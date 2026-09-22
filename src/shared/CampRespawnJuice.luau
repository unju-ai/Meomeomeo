--!strict

-- Pure rules for Cat Rift small-camp respawn juice.
-- JungleService still owns the pending stamp (pigeon 32s, golem 45s, crab 50s).
-- This module only decides whether the client may paint that stamp.
-- Canal Levi stays on RiverEpic and the match clock. Gold is not here.
-- Hub / Yarn Run / Koi / Party / Arcade stay quiet.

local RiverEpic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RiverEpic"))
local VisionLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("VisionLogic"))

local CampRespawnJuice = {}

-- Night-market cream chip, amber stroke. Display only.
CampRespawnJuice.Cream = { 255, 243, 224 }
CampRespawnJuice.Amber = { 255, 196, 74 }
CampRespawnJuice.Ink = { 52, 36, 32 }

-- Soft puff when the existing stamp is reached. Does not delay the spawn.
CampRespawnJuice.PuffSeconds = 0.42
-- Vision can drop the row a fraction before this client's clock catches the stamp.
CampRespawnJuice.PuffGrace = 0.5

export type Down = {
	id: string,
	name: string,
	x: number,
	y: number,
	z: number,
	respawnAt: number,
}

-- Cat Rift fight only. A pit chip during draft or the hub does not play.
function CampRespawnJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

-- The six route camps. Canal Levi already has its own timer.
function CampRespawnJuice.isSmallCamp(id: string): boolean
	return id ~= RiverEpic.Id
end

-- A future server stamp means the body is still waiting. The number is not chosen here.
function CampRespawnJuice.waiting(respawnAt: number?, now: number): boolean
	return typeof(respawnAt) == "number" and (respawnAt :: number) > now
end

function CampRespawnJuice.remaining(respawnAt: number?, now: number): number
	if typeof(respawnAt) ~= "number" then
		return 0
	end
	return math.max(0, (respawnAt :: number) - now)
end

-- Ceil so the chip hits 0 only as the server deadline arrives.
function CampRespawnJuice.displaySeconds(seconds: number): number
	return math.max(0, math.ceil(seconds - 1e-6))
end

function CampRespawnJuice.chipRead(seconds: number): string
	return `{CampRespawnJuice.displaySeconds(seconds)}s`
end

-- Match fog memory. Lit now, or already explored this match. Unexplored stays dark.
function CampRespawnJuice.pitKnown(fogBits: { number }?, exploredBits: { number }?, x: number, z: number): boolean
	local index = VisionLogic.indexOf(x, z)
	if typeof(fogBits) == "table" and VisionLogic.bitOn(fogBits, index) then
		return true
	end
	if typeof(exploredBits) == "table" and VisionLogic.bitOn(exploredBits, index) then
		return true
	end
	return false
end

function CampRespawnJuice.shouldPaint(id: string, respawnAt: number?, now: number, known: boolean): boolean
	if not CampRespawnJuice.isSmallCamp(id) then
		return false
	end
	if not known then
		return false
	end
	return CampRespawnJuice.waiting(respawnAt, now)
end

-- Rows the viewer is allowed to know are down. Levi and unexplored pits drop out.
function CampRespawnJuice.select(downs: { Down }?, fogBits: { number }?, exploredBits: { number }?, now: number): { Down }
	local out: { Down } = {}
	if typeof(downs) ~= "table" then
		return out
	end
	for _, row in downs do
		if typeof(row) == "table" and typeof(row.id) == "string" and typeof(row.x) == "number" and typeof(row.z) == "number" then
			local known = CampRespawnJuice.pitKnown(fogBits, exploredBits, row.x, row.z)
			if CampRespawnJuice.shouldPaint(row.id, row.respawnAt, now, known) then
				table.insert(out, row)
			end
		end
	end
	return out
end

-- We were painting a future stamp, and that id is gone because the deadline passed.
-- A row that vanishes while the stamp is still well in the future does not puff.
-- A sliver before the stamp still counts: the server may have already spawned.
function CampRespawnJuice.justReturned(wasWaiting: boolean, respawnAt: number?, now: number): boolean
	if not wasWaiting then
		return false
	end
	if not CampRespawnJuice.waiting(respawnAt, now) then
		return true
	end
	if typeof(respawnAt) ~= "number" then
		return false
	end
	return (respawnAt :: number) - now <= CampRespawnJuice.PuffGrace
end

function CampRespawnJuice.puffIds(painted: { [string]: number }, nextRows: { Down }, now: number): { string }
	local still: { [string]: boolean } = {}
	for _, row in nextRows do
		if typeof(row) == "table" and typeof(row.id) == "string" then
			still[row.id] = true
		end
	end
	local ids: { string } = {}
	for id, respawnAt in painted do
		if not still[id] and CampRespawnJuice.justReturned(true, respawnAt, now) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

return CampRespawnJuice
