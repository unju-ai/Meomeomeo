--!strict

-- Pure rules for Cat Rift brush enter / stay / leave juice.
-- VisionLogic.brushAt still owns the pockets that hide a body. MapBuilder
-- paints those same AABBs. This module only decides whether the client
-- should wash a night-market cue. It does not change radius, stealth, or fog.
-- Hub / Yarn Run / Koi / Party / Arcade stay quiet.
-- Enemies in brush are never painted. Last-seen ghosts are not this module.

local VisionLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("VisionLogic"))

local BrushJuice = {}

-- Night-market mint leaf, cream exit. Shade is the brief enter darken.
BrushJuice.Mint = { 120, 196, 150 }
BrushJuice.Leaf = { 86, 148, 112 }
BrushJuice.Cream = { 255, 243, 224 }
BrushJuice.Shade = { 22, 40, 32 }

-- Display only. These do not change brush size or who can see you.
BrushJuice.EnterSeconds = 0.42
BrushJuice.LeaveSeconds = 0.36
BrushJuice.StayRefresh = 0.9
BrushJuice.EdgeGap = 0.32
BrushJuice.LeafCount = 3

export type Edge = "enter" | "leave" | "stay" | "none"
export type CueKind = "local" | "ally" | "none"
export type Rgb = { number }

export type Watch = {
	matchId: string?,
	pocket: string?,
	burstAt: number,
}

function BrushJuice.blank(): Watch
	return {
		matchId = nil,
		pocket = nil,
		burstAt = -100,
	}
end

-- Cat Rift fight only. A brush wash during draft or the hub does not play.
function BrushJuice.modeAllows(gameMode: string, phase: string?): boolean
	if gameMode ~= "Moba" then
		return false
	end
	return phase == "InProgress"
end

-- Same AABB the server uses to hide a body. Lane corridors stay open.
function BrushJuice.pocket(x: number, z: number): string?
	return VisionLogic.brushAt(x, z)
end

function BrushJuice.edge(prev: string?, nextName: string?): Edge
	if prev == nextName then
		if nextName ~= nil then
			return "stay"
		end
		return "none"
	end
	if nextName ~= nil then
		return "enter"
	end
	return "leave"
end

-- Local always. A visible ally may get a faint hush.
-- Enemies never, even when they share the pocket — a mark would reveal them.
function BrushJuice.cueKind(localUserId: number, targetUserId: number, sameTeam: boolean, inVision: boolean): CueKind
	if localUserId == targetUserId then
		return "local"
	end
	if sameTeam and inVision then
		return "ally"
	end
	return "none"
end

function BrushJuice.shouldPaint(cue: CueKind): boolean
	return cue == "local" or cue == "ally"
end

function BrushJuice.wantsVignette(cue: CueKind, edge: Edge): boolean
	return cue == "local" and (edge == "enter" or edge == "leave" or edge == "stay")
end

-- Quiet foot hush on the local enter only. Leave is a visual fade.
function BrushJuice.wantsHush(cue: CueKind, edge: Edge): boolean
	return cue == "local" and edge == "enter"
end

function BrushJuice.wantsLeaves(cue: CueKind, edge: Edge): boolean
	return cue == "local" and edge == "enter"
end

-- Flutter across the edge does not replay the burst. Stay is not a burst.
function BrushJuice.wantsBurst(edge: Edge, burstAt: number, now: number): boolean
	if edge ~= "enter" and edge ~= "leave" then
		return false
	end
	return now - burstAt >= BrushJuice.EdgeGap
end

function BrushJuice.tint(edge: Edge): Rgb
	if edge == "leave" then
		return BrushJuice.Cream
	end
	if edge == "stay" then
		return BrushJuice.Leaf
	end
	return BrushJuice.Mint
end

function BrushJuice.vignetteRgb(edge: Edge): Rgb
	if edge == "leave" then
		return BrushJuice.Cream
	end
	if edge == "stay" then
		return BrushJuice.Leaf
	end
	return BrushJuice.Shade
end

function BrushJuice.life(edge: Edge): number
	if edge == "leave" then
		return BrushJuice.LeaveSeconds
	end
	if edge == "stay" then
		return BrushJuice.StayRefresh
	end
	return BrushJuice.EnterSeconds
end

-- Higher = quieter. Stay is a hint. Ally is fainter than local.
function BrushJuice.washTransparency(cue: CueKind, edge: Edge): number
	if cue == "ally" then
		if edge == "stay" then
			return 0.93
		end
		return 0.86
	end
	if edge == "stay" then
		return 0.84
	end
	if edge == "leave" then
		return 0.62
	end
	return 0.55
end

function BrushJuice.discSpan(cue: CueKind): number
	if cue == "ally" then
		return 4.2
	end
	return 6.2
end

-- 1 = invisible. Enter darkens a little; stay is barely there.
function BrushJuice.vignettePeak(edge: Edge): number
	if edge == "enter" then
		return 0.88
	end
	if edge == "stay" then
		return 0.945
	end
	if edge == "leave" then
		return 0.9
	end
	return 1
end

-- Step one body. A new match drops the old pocket without a false leave.
-- When the mode goes quiet, a held pocket becomes one leave so the wash clears.
-- Does not mutate `watch`.
function BrushJuice.observe(
	watch: Watch,
	matchId: string?,
	x: number,
	z: number,
	allowed: boolean,
	now: number
): (Watch, Edge, string?, boolean)
	if not allowed then
		if watch.pocket ~= nil then
			return {
				matchId = matchId,
				pocket = nil,
				burstAt = now,
			}, "leave", nil, true
		end
		return {
			matchId = matchId,
			pocket = nil,
			burstAt = watch.burstAt,
		}, "none", nil, false
	end
	if watch.matchId ~= matchId then
		local pocket = BrushJuice.pocket(x, z)
		local edge: Edge = if pocket ~= nil then "enter" else "none"
		return {
			matchId = matchId,
			pocket = pocket,
			burstAt = if edge == "enter" then now else -100,
		}, edge, pocket, edge == "enter"
	end
	local pocket = BrushJuice.pocket(x, z)
	local edge = BrushJuice.edge(watch.pocket, pocket)
	local burst = BrushJuice.wantsBurst(edge, watch.burstAt, now)
	return {
		matchId = matchId,
		pocket = pocket,
		burstAt = if burst then now else watch.burstAt,
	}, edge, pocket, burst
end

return BrushJuice
