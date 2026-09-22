--!strict

-- Pure paint helpers for the Cat Rift minimap.
-- Vision mask math stays on VisionService / VisionLogic; this only styles dots.
-- RGB tables stay Color3-free so smokes can assert without Theme / Instance.

local MinimapPaint = {}

MinimapPaint.Blue = { 86, 148, 230 }
MinimapPaint.Red = { 230, 86, 96 }
MinimapPaint.Cream = { 255, 243, 224 }
MinimapPaint.Ink = { 52, 36, 32 }
MinimapPaint.Coral = { 255, 122, 98 }
MinimapPaint.Mint = { 120, 196, 150 }
MinimapPaint.Lantern = { 255, 176, 72 }
MinimapPaint.Wood = { 122, 74, 46 }
MinimapPaint.Yarn = { 255, 196, 90 }
MinimapPaint.Pink = { 255, 92, 196 }
MinimapPaint.Amber = { 255, 196, 74 }
MinimapPaint.Dead = { 50, 50, 50 }
MinimapPaint.FogUnexplored = { 8, 10, 16 }
MinimapPaint.FogExplored = { 22, 34, 42 }
-- BackgroundTransparency: lower = more opaque. Explored stays lighter than black.
MinimapPaint.FogUnexploredAlpha = 0.08
MinimapPaint.FogExploredAlpha = 0.38
MinimapPaint.ClickFlashSeconds = 0.35

export type Rgb = { number }

export type Paint = {
	fill: Rgb,
	stroke: Rgb,
	strokeThickness: number,
	size: number,
	-- UICorner pixel radius. 2 = square-ish post / pit; 99 = round.
	corner: number,
	shape: string,
	transparency: number,
}

local function paint(
	fill: Rgb,
	stroke: Rgb,
	strokeThickness: number,
	size: number,
	corner: number,
	shape: string,
	transparency: number?
): Paint
	return {
		fill = fill,
		stroke = stroke,
		strokeThickness = strokeThickness,
		size = size,
		corner = corner,
		shape = shape,
		transparency = transparency or 0,
	}
end

local function teamFill(team: string?): Rgb
	if team == "Blue" then
		return MinimapPaint.Blue
	end
	if team == "Red" then
		return MinimapPaint.Red
	end
	return MinimapPaint.Lantern
end

-- You: cream pip with ink ring. Allies: team fill + cream stroke.
-- Enemies: team fill + coral stroke so sides read in a fight.
function MinimapPaint.champ(isSelf: boolean, isAlly: boolean, team: string?, isBot: boolean): Paint
	if isSelf then
		return paint(MinimapPaint.Cream, MinimapPaint.Ink, 2.5, 10, 99, "self", 0)
	end
	local fill = teamFill(team)
	if isAlly then
		return paint(fill, MinimapPaint.Cream, 1.5, if isBot then 6 else 8, 99, "ally", 0)
	end
	return paint(fill, MinimapPaint.Coral, 1.75, if isBot then 6 else 8, 99, "enemy", 0)
end

-- Match smart-ping shapes: posts square + lantern stroke, open stalls amber + wood,
-- gated stalls dim wood body, yarn core pink + yarn stroke.
function MinimapPaint.structure(tier: string?, team: string?, alive: boolean, vulnerable: boolean): Paint
	local shape = if tier == "Inner" then "stall" elseif tier == "Core" then "core" else "post"
	if not alive then
		local corner = if shape == "post" then 2 else 99
		return paint(MinimapPaint.Dead, MinimapPaint.Dead, 1, 6, corner, shape, 0.15)
	end
	if shape == "post" then
		return paint(teamFill(team), MinimapPaint.Lantern, 2, 7, 2, "post", 0)
	end
	if shape == "stall" then
		if vulnerable then
			return paint(MinimapPaint.Lantern, MinimapPaint.Wood, 2, 8, 99, "stall", 0)
		end
		-- Gated: closed lantern — dark wood body, muted amber ring.
		return paint({ 58, 48, 40 }, { 140, 100, 60 }, 2, 7, 99, "stall", 0.2)
	end
	return paint(MinimapPaint.Pink, MinimapPaint.Yarn, 2, 10, 99, "core", 0)
end

-- Canal Levi: bright round body in vision; amber square pit while UP in fog;
-- muted square while returning; faint gray square after taken.
function MinimapPaint.levi(mark: string): Paint?
	if mark == "body" then
		return paint({ 255, 120, 48 }, MinimapPaint.Cream, 2, 10, 99, "body", 0)
	end
	if mark == "pit" then
		return paint({ 255, 160, 48 }, { 255, 220, 140 }, 2.5, 9, 2, "pit", 0)
	end
	if mark == "down" then
		return paint({ 72, 56, 48 }, { 180, 120, 70 }, 1.5, 7, 2, "down", 0.18)
	end
	if mark == "spent" then
		return paint({ 40, 40, 44 }, { 96, 96, 104 }, 1, 5, 2, "spent", 0.42)
	end
	return nil
end

function MinimapPaint.ward(kind: string?, team: string?): Paint
	if kind == "control" then
		return paint(MinimapPaint.Pink, MinimapPaint.Cream, 1.25, 5, 2, "ward", 0)
	end
	local fill = if team == "Blue" then { 140, 210, 255 } else { 255, 150, 170 }
	return paint(fill, MinimapPaint.Cream, 1, 4, 2, "ward", 0)
end

function MinimapPaint.minion(team: string?): Paint
	local fill = if team == "Blue" then { 160, 200, 255 } else { 255, 170, 170 }
	return paint(fill, fill, 0, 4, 99, "minion", 0)
end

function MinimapPaint.camp(isEpicBody: boolean): Paint
	if isEpicBody then
		local body = MinimapPaint.levi("body")
		assert(body ~= nil)
		return body
	end
	return paint(MinimapPaint.Amber, MinimapPaint.Ink, 1, 5, 99, "camp", 0)
end

-- Small camp waiting on its existing stamp. Dim square, not the living amber pip
-- and not Canal Levi's pit mark.
function MinimapPaint.campDown(): Paint
	return paint({ 120, 92, 58 }, MinimapPaint.Amber, 1, 6, 2, "campDown", 0.4)
end

-- Ping flash shapes share structure markers when a post / stall / core is named.
function MinimapPaint.ping(marker: string?, team: string?, pingRgb: Rgb, size: number): Paint
	local shape = marker or "dot"
	if shape == "post" then
		return paint(teamFill(team), MinimapPaint.Lantern, 2, size, 2, "post", 0)
	end
	if shape == "stall" then
		return paint(MinimapPaint.Lantern, MinimapPaint.Wood, 2, size, 99, "stall", 0)
	end
	if shape == "core" then
		return paint(MinimapPaint.Pink, MinimapPaint.Yarn, 2, size, 99, "core", 0)
	end
	return paint(pingRgb, MinimapPaint.Cream, 1, size, 99, "dot", 0)
end

function MinimapPaint.fogCell(explored: boolean): (Rgb, number)
	if explored then
		return MinimapPaint.FogExplored, MinimapPaint.FogExploredAlpha
	end
	return MinimapPaint.FogUnexplored, MinimapPaint.FogUnexploredAlpha
end

-- 1 at click, 0 after ClickFlashSeconds. Drive a local Attention flash fill.
function MinimapPaint.clickFlash(elapsed: number): number
	if elapsed < 0 then
		return 0
	end
	local span = MinimapPaint.ClickFlashSeconds
	if elapsed >= span then
		return 0
	end
	return 1 - (elapsed / span)
end

function MinimapPaint.rgb(c: Rgb): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

return MinimapPaint
