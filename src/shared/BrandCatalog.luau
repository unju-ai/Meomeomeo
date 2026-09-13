--!strict

-- Shared character identity for the channel, lobby hosts and collectible studies.
-- Hosts are not playable champions and never grant combat or financial benefits.

export type HostDef = {
	id: string,
	name: string,
	title: string,
	greeting: string,
	personality: string,
	color: Color3,
	lines: { string },
}

local BrandCatalog = {
	Name = "meo meo meo",
	Tagline = "Three cats. One shared braincell.",
	GameLine = "Three lanes. One shared braincell.",
	Signature = "404: thought not found.",
	BraincellColor = Color3.fromRGB(49, 84, 213),
	PaperColor = Color3.fromRGB(243, 239, 229),
	InkColor = Color3.fromRGB(37, 39, 37),
}

local HOSTS: { HostDef } = {
	{
		id = "HostMeo",
		name = "MEO",
		title = "Confidently wrong",
		greeting = "I called this meeting. Nobody knows why. Especially me.",
		personality = "An orange loaf cat with enormous confidence and one shared braincell. Treats small match problems as world events. The joke is his own misplaced certainty; actual controls and objectives must stay accurate.",
		color = Color3.fromRGB(232, 136, 69),
		lines = {
			"I have a flawless plan, {name}: three towers, then the nexus. The flaw is my execution.",
			"I requested a gank. Apparently that requires telling my team where I am.",
			"{champ} has entered the meeting. The agenda is tower damage.",
		},
	},
	{
		id = "HostMe",
		name = "ME",
		title = "Tired of this",
		greeting = "Three lanes. One braincell. Ask before MEO uses it.",
		personality = "An ivory loaf cat with a level stare. Quiet, practical and tired of MEO's theories. One useful fact followed by a short deadpan observation. Never humiliates the player.",
		color = Color3.fromRGB(243, 239, 229),
		lines = {
			"F recalls. B opens Pawmart at the fountain. We had a meeting about this.",
			"Press 4 to place a ward when it is ready. The fog is not going to explain itself.",
			"Take all three enemy towers before their nexus. Yes, all three.",
			"Hold G to choose a team ping. MEO's thoughts are not automatically broadcast.",
		},
	},
	{
		id = "HostMo",
		name = "MO",
		title = "Signal lost",
		greeting = "I was told to welcome you. Welcome you.",
		personality = "A charcoal loaf cat with a slightly misaligned gaze. Soft, solemn and slow to respond. Offers a brief absurd conclusion about cat life. Never invents game rewards, controls or investment advice.",
		color = Color3.fromRGB(37, 39, 37),
		lines = {
			"We requested options. Champion select appears to have taken that literally.",
			"The braincell is on cooldown. Nobody remembers who cast it.",
			"404: thought not found. The nexus is still there, though.",
		},
	},
}

function BrandCatalog.hosts(): { HostDef }
	return HOSTS
end

function BrandCatalog.host(id: string): HostDef?
	for _, host in HOSTS do
		if host.id == id then
			return host
		end
	end
	return nil
end

return BrandCatalog
