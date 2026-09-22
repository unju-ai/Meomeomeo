--!strict

-- Pure paint helpers for the Cat Rift kill feed.
-- Scoring / announcer copy stay on the server; this only styles plates.
-- RGB tables stay Color3-free so smokes can assert without Theme / Instance.

local KillFeedPaint = {}

KillFeedPaint.MaxRows = 4
KillFeedPaint.HoldSeconds = 5.5
-- Kitty Caster already holds the shout on the banner; announce chips expire sooner.
KillFeedPaint.AnnounceHoldSeconds = 3.2
KillFeedPaint.RowHeight = 20
KillFeedPaint.RowGap = 3

KillFeedPaint.Cream = { 255, 243, 224 }
KillFeedPaint.Ink = { 52, 36, 32 }
KillFeedPaint.Peach = { 255, 184, 140 }
KillFeedPaint.Amber = { 255, 196, 74 }
KillFeedPaint.Coral = { 255, 122, 98 }
KillFeedPaint.Mint = { 120, 196, 150 }
KillFeedPaint.Lantern = { 255, 176, 72 }
KillFeedPaint.Wood = { 122, 74, 46 }
KillFeedPaint.Pink = { 255, 92, 196 }
KillFeedPaint.Yarn = { 255, 196, 90 }
KillFeedPaint.Blue = { 86, 148, 230 }
KillFeedPaint.Panel = { 44, 30, 28 }

export type PlateKind = "kill" | "tower" | "stall" | "nexus" | "level" | "announce" | "ping"

export type Involvement = "none" | "selfKill" | "selfDeath"

export type Plate = {
	kind: PlateKind,
	fill: { number },
	stroke: { number },
	text: { number },
	-- BackgroundTransparency / UIStroke.Transparency (0 = solid).
	fillAlpha: number,
	strokeAlpha: number,
	textAlpha: number,
	bold: boolean,
}

local function startsWithName(text: string, name: string): boolean
	if name == "" or #text < #name then
		return false
	end
	if string.sub(text, 1, #name) ~= name then
		return false
	end
	local nextChar = string.sub(text, #name + 1, #name + 1)
	return nextChar == " " or nextChar == ""
end

-- Map FeedKind (+ stall sniff for older tower lines) to a plate kind.
function KillFeedPaint.resolveKind(kind: string, text: string): PlateKind
	if kind == "stall" then
		return "stall"
	end
	if kind == "tower" then
		local lower = string.lower(text)
		if string.find(lower, "lantern stall", 1, true) or string.find(lower, " snuffed ", 1, true) then
			return "stall"
		end
		return "tower"
	end
	if kind == "kill" or kind == "nexus" or kind == "level" or kind == "announce" or kind == "ping" then
		return kind
	end
	return "level"
end

-- Light personal read from existing cat copy — no extra remote fields.
function KillFeedPaint.involvement(kind: string, text: string, localNames: { string }): Involvement
	if kind ~= "kill" and kind ~= "tower" and kind ~= "stall" and kind ~= "nexus" and kind ~= "level" then
		return "none"
	end
	for _, name in localNames do
		if typeof(name) ~= "string" or name == "" then
			continue
		end
		if kind == "kill" then
			if startsWithName(text, name) and string.find(text, " scratched ", 1, true) then
				return "selfKill"
			end
			if string.find(text, ` scratched {name} into `, 1, true) then
				return "selfDeath"
			end
			if startsWithName(text, name) and string.find(text, " got batted ", 1, true) then
				return "selfDeath"
			end
		elseif startsWithName(text, name) then
			-- Your structure take or your level-up line.
			return "selfKill"
		end
	end
	return "none"
end

-- Older rows fade so the newest chip and Kitty Caster banner stay readable.
function KillFeedPaint.ageFade(index: number): number
	if index <= 1 then
		return 0
	end
	if index == 2 then
		return 0.12
	end
	if index == 3 then
		return 0.28
	end
	return 0.42
end

function KillFeedPaint.holdSeconds(kind: PlateKind): number
	if kind == "announce" then
		return KillFeedPaint.AnnounceHoldSeconds
	end
	return KillFeedPaint.HoldSeconds
end

function KillFeedPaint.plate(kind: PlateKind, involvement: Involvement, index: number): Plate
	local age = KillFeedPaint.ageFade(index)
	local fill = KillFeedPaint.Panel
	local stroke = KillFeedPaint.Cream
	local text = KillFeedPaint.Cream
	local fillAlpha = 0.55
	local strokeAlpha = 0.4
	local textAlpha = 0
	local bold = false

	if kind == "kill" then
		fill = { 72, 42, 36 }
		stroke = KillFeedPaint.Peach
		text = KillFeedPaint.Peach
		fillAlpha = 0.42
		strokeAlpha = 0.28
	elseif kind == "tower" then
		fill = { 62, 44, 28 }
		stroke = KillFeedPaint.Lantern
		text = KillFeedPaint.Amber
		fillAlpha = 0.4
		strokeAlpha = 0.25
	elseif kind == "stall" then
		fill = { 58, 40, 28 }
		stroke = KillFeedPaint.Wood
		text = KillFeedPaint.Lantern
		fillAlpha = 0.38
		strokeAlpha = 0.22
	elseif kind == "nexus" then
		fill = { 68, 28, 48 }
		stroke = KillFeedPaint.Pink
		text = KillFeedPaint.Coral
		fillAlpha = 0.35
		strokeAlpha = 0.2
	elseif kind == "announce" then
		-- Quieter plate so the banner owns first blood / multi-kill.
		fill = { 48, 36, 28 }
		stroke = KillFeedPaint.Amber
		text = KillFeedPaint.Amber
		fillAlpha = 0.72
		strokeAlpha = 0.55
		textAlpha = 0.08
	elseif kind == "ping" then
		fill = { 40, 48, 58 }
		stroke = KillFeedPaint.Blue
		text = KillFeedPaint.Cream
		fillAlpha = 0.48
		strokeAlpha = 0.35
	else
		-- level
		fill = { 36, 52, 44 }
		stroke = KillFeedPaint.Mint
		text = KillFeedPaint.Mint
		fillAlpha = 0.5
		strokeAlpha = 0.35
	end

	if involvement == "selfKill" then
		stroke = KillFeedPaint.Cream
		strokeAlpha = math.max(0, strokeAlpha - 0.12)
		fillAlpha = math.max(0.22, fillAlpha - 0.08)
		bold = true
	elseif involvement == "selfDeath" then
		stroke = KillFeedPaint.Coral
		text = KillFeedPaint.Coral
		strokeAlpha = math.max(0, strokeAlpha - 0.1)
		fillAlpha = math.max(0.24, fillAlpha - 0.06)
		bold = true
	end

	fillAlpha = math.clamp(fillAlpha + age * 0.55, 0, 0.92)
	strokeAlpha = math.clamp(strokeAlpha + age * 0.45, 0, 0.9)
	textAlpha = math.clamp(textAlpha + age * 0.55, 0, 0.75)

	return {
		kind = kind,
		fill = fill,
		stroke = stroke,
		text = text,
		fillAlpha = fillAlpha,
		strokeAlpha = strokeAlpha,
		textAlpha = textAlpha,
		bold = bold,
	}
end

function KillFeedPaint.rgb(rgb: { number }): (number, number, number)
	return rgb[1], rgb[2], rgb[3]
end

return KillFeedPaint
