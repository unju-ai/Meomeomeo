--!strict

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local BrandCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrandCatalog"))

export type ChatContext = {
	npc: Types.NpcDef,
	playerName: string,
	championName: string?,
	phase: string,
	scoreline: string,
}

local LINES: { [string]: { string } } = {
	PawmartBlue = {
		"Blue-side special: one health pot, extra judgment. Don't die on my floor, {name}.",
		"If you're browsing, you're losing gold. Buy, fight, or both. Meow.",
		"{champ} looks under-itemized. That's a you problem, but I have solutions on aisle 2.",
	},
	PawmartRed = {
		"Red Pawmart: everything is 20% off if you take the tower first.",
		"I don't do refunds, {name}. I do remounts. Get back out there.",
		"{champ} + leftover tuna = certified mid gap. Next.",
	},
	OldTom = {
		"Kitten {name}, wards are love letters to your future corpse. Place them.",
		"The river is a suggestion, not a grave. Usually.",
		"{champ} in {phase}? Fine. Watch the fog. Fog watches back.",
	},
	KittyCaster = {
		"WE'RE LIVE — {score} — and {name} just walked into frame like they pay rent here.",
		"Breaking: {champ} still hasn't used ult. Chat is in shambles.",
		"Meme-stock update later. First, somebody please hit that nexus. {phase} energy.",
	},
}

local FALLBACK = {
	"*stares in cat* {name}, I heard you. I just refuse to be helpful until you farm.",
	"Mrrp. Translation: go hit a tower. {phase} won't last forever.",
	"The council of cats has reviewed your draft. It says 'meow' (mixed).",
}

local MockAiProvider = {}

function MockAiProvider.complete(message: string, context: ChatContext): string
	local host = BrandCatalog.host(context.npc.id)
	local pool = if host then host.lines else LINES[context.npc.id] or FALLBACK
	local template = pool[(string.len(message) % #pool) + 1] or FALLBACK[1]
	local reply = template
		:gsub("{name}", function() return context.playerName end)
		:gsub("{champ}", function() return context.championName or "a mystery cat" end)
		:gsub("{phase}", function() return context.phase end)
		:gsub("{score}", function() return context.scoreline end)

	-- Hosts deliver authored lines without repeating arbitrary player input.
	if host then
		return reply
	end

	local clipped = string.sub(message, 1, 42)
	return `{reply} (re: "{clipped}{if string.len(message) > 42 then "…" else ""}")`
end

return MockAiProvider
