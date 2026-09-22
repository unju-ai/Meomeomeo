--!strict

-- Smart-ping rules. The server resolves what the ray hit, then asks here
-- whether the team line may name it.
--
-- Fog: Attention cannot mark a fogged enemy body (same refuse as an auto-attack,
-- "No vision."). A ground click or a minimap click into fog is still a legal
-- Attention or Enemy Missing ping, and it stays unnamed. Caution, Attack, and
-- the other wheel kinds on a hidden body stay unnamed too — they do not attach
-- to that cat. Kitty Caster's soft cues are untouched; this only spaces pings.

local PingLogic = {}

-- Short per-player gap so ping lines and PingSoft / PingWarn do not pile onto
-- a Kitty Caster callout. Config.Pings.CooldownSeconds mirrors this.
PingLogic.CooldownSeconds = 2

export type HitKind = "ground" | "enemy" | "ally" | "structure" | "ward" | "camp"

export type Query = {
	kind: string,
	source: string,
	hit: HitKind,
	visible: boolean,
	tier: string?,
	alive: boolean?,
}

export type Decision = {
	ok: boolean,
	error: string?,
	named: boolean,
	marker: string,
}

function PingLogic.cooling(elapsed: number): boolean
	return elapsed < PingLogic.CooldownSeconds
end

function PingLogic.markerFor(tier: string?): string
	if tier == "Inner" then
		return "stall"
	end
	if tier == "Core" then
		return "core"
	end
	if tier == "Outer" then
		return "post"
	end
	return "dot"
end

-- Named: "⚠ Caution · Nyan Rocket". Ground: "⚠ Caution".
function PingLogic.compose(emoji: string, label: string, line: string, targetName: string?): string
	if typeof(targetName) == "string" and targetName ~= "" then
		return `{emoji} {label} · {targetName}`
	end
	return `{emoji} {line}`
end

function PingLogic.ticker(who: string, emoji: string, label: string, line: string, targetName: string?): string
	return `{who}: {PingLogic.compose(emoji, label, line, targetName)}`
end

local function accept(named: boolean, marker: string): Decision
	return {
		ok = true,
		named = named,
		marker = marker,
	}
end

local function refuse(): Decision
	return {
		ok = false,
		error = "No vision.",
		named = false,
		marker = "dot",
	}
end

function PingLogic.resolve(query: Query): Decision
	-- Minimap clicks and empty ground never attach, including into fog.
	if query.source == "minimap" or query.hit == "ground" then
		return accept(false, "dot")
	end
	if query.hit == "enemy" and query.visible ~= true then
		if query.kind == "Attention" then
			return refuse()
		end
		return accept(false, "dot")
	end
	if query.hit == "ally" or query.hit == "enemy" then
		return accept(true, "dot")
	end
	if query.hit == "structure" then
		if query.alive == false then
			return accept(false, "dot")
		end
		return accept(true, PingLogic.markerFor(query.tier))
	end
	if query.hit == "ward" or query.hit == "camp" then
		if query.visible ~= true then
			return accept(false, "dot")
		end
		return accept(true, "dot")
	end
	return accept(false, "dot")
end

return PingLogic
