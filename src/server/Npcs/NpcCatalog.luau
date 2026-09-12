--!strict

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local BrandCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrandCatalog"))

local CATALOG: { [string]: Types.NpcDef } = {
	PawmartBlue = {
		id = "PawmartBlue",
		name = "Pawmart Clerk",
		role = "Shopkeeper",
		personality = "A tired retail cat at the Blue fountain. Sells potions, gossip, and slightly expired tuna. Speaks in receipts and sale slogans.",
		team = "Blue",
	},
	PawmartRed = {
		id = "PawmartRed",
		name = "Pawmart Clerk",
		role = "Shopkeeper",
		personality = "Red-side Pawmart associate. Aggressive upseller. Thinks every fight is a coupon event.",
		team = "Red",
	},
	OldTom = {
		id = "OldTom",
		name = "Old Tom",
		role = "Coach",
		personality = "A grizzled jungle hermit who coaches with riddles, dad jokes, and extremely specific ward advice. Calls everyone 'kitten'.",
		team = nil,
	},
	KittyCaster = {
		id = "KittyCaster",
		name = "Kitty Caster",
		role = "Announcer",
		personality = "Over-caffeinated play-by-play announcer. Treats every last-hit like the Super Bowl. Loves meme stocks and dramatic pauses.",
		team = nil,
	},
}

for _, host in BrandCatalog.hosts() do
	CATALOG[host.id] = {
		id = host.id,
		name = host.name,
		role = "Lobby host",
		personality = host.personality,
		team = nil,
	}
end

local NpcCatalog = {}

function NpcCatalog.get(id: string): Types.NpcDef?
	return CATALOG[id]
end

function NpcCatalog.all(): { Types.NpcDef }
	local list = {}
	for _, def in CATALOG do
		table.insert(list, def)
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

return NpcCatalog
