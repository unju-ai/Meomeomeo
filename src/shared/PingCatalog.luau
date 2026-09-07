--!strict

export type PingKind =
	"Attention"
	| "Caution"
	| "OnMyWay"
	| "Assist"
	| "EnemyMissing"
	| "AllClear"
	| "AttackHere"

export type PingCue = "PingSoft" | "PingWarn"

export type PingDef = {
	id: PingKind,
	label: string,
	emoji: string,
	line: string,
	cue: PingCue,
	color: Color3,
	wheel: boolean,
}

local ORDER: { PingKind } = {
	"Caution",
	"OnMyWay",
	"Assist",
	"EnemyMissing",
	"AllClear",
	"AttackHere",
}

local BY_ID: { [PingKind]: PingDef } = {
	Attention = {
		id = "Attention",
		label = "Attention",
		emoji = "📍",
		line = "Attention",
		cue = "PingSoft",
		color = Color3.fromRGB(255, 196, 74),
		wheel = false,
	},
	Caution = {
		id = "Caution",
		label = "Caution",
		emoji = "⚠",
		line = "Caution",
		cue = "PingWarn",
		color = Color3.fromRGB(230, 170, 70),
		wheel = true,
	},
	OnMyWay = {
		id = "OnMyWay",
		label = "On my way",
		emoji = "➤",
		line = "On my way",
		cue = "PingSoft",
		color = Color3.fromRGB(86, 148, 230),
		wheel = true,
	},
	Assist = {
		id = "Assist",
		label = "Assist",
		emoji = "✚",
		line = "Need assist",
		cue = "PingSoft",
		color = Color3.fromRGB(120, 196, 150),
		wheel = true,
	},
	EnemyMissing = {
		id = "EnemyMissing",
		label = "Missing",
		emoji = "?",
		line = "Enemy missing",
		cue = "PingWarn",
		color = Color3.fromRGB(230, 86, 96),
		wheel = true,
	},
	AllClear = {
		id = "AllClear",
		label = "All clear",
		emoji = "✓",
		line = "All clear",
		cue = "PingSoft",
		color = Color3.fromRGB(120, 196, 150),
		wheel = true,
	},
	AttackHere = {
		id = "AttackHere",
		label = "Attack",
		emoji = "⚔",
		line = "Attack here",
		cue = "PingWarn",
		color = Color3.fromRGB(230, 86, 96),
		wheel = true,
	},
}

local PingCatalog = {}

function PingCatalog.wheel(): { PingDef }
	local out = {}
	for _, id in ORDER do
		table.insert(out, BY_ID[id])
	end
	return out
end

function PingCatalog.get(id: unknown): PingDef?
	if typeof(id) ~= "string" then
		return nil
	end
	return BY_ID[id :: PingKind]
end

return PingCatalog
