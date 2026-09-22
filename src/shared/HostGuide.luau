--!strict

local BrandCatalog = require(script.Parent.BrandCatalog)
local ModeCatalog = require(script.Parent.ModeCatalog)

-- Authored hub answers stay consistent whether the AI provider is mock or HTTP.
local HostGuide = {}
local ALIASES: { [string]: { string } } = {
	CatRift = { "cat rift", "catrift", "rift", "moba" },
	YarnRun = { "yarn run", "yarnrun", "runner" },
	KoiPond = { "koi pond", "koipond", "koi", "fishing" },
	YarnParty = { "yarn party", "yarnparty", "party" },
	MemeArcade = { "meme arcade", "memearcade", "arcade" },
}
local ASIDES: { [string]: { [string]: string } } = {
	HostMeo = {
		CatRift = "My strategy is flawless until the other team arrives.",
		YarnRun = "I am not fleeing. I am leading in the opposite direction.",
		KoiPond = "I have scheduled a meeting with a fish.",
		YarnParty = "Four cats. I have already lost the vote.",
		MemeArcade = "My forecast is that I will stare at the chart.",
	},
	HostMe = {
		CatRift = "Scratching posts, then lantern stalls, then the nexus. We wrote it down.",
		YarnRun = "The dog is not a shortcut.",
		KoiPond = "Patience. A concept MEO is still testing.",
		YarnParty = "Read the round instruction before the chaos.",
		MemeArcade = "The yarn is pretend. MEO's confusion is real.",
	},
	HostMo = {
		CatRift = "Three lanes. I brought one thought.",
		YarnRun = "The floor keeps leaving. I respect its decision.",
		KoiPond = "The fish has seen my thoughts. It declined to comment.",
		YarnParty = "I attended the party emotionally. My paws are catching up.",
		MemeArcade = "The candle moved. I remained.",
	},
}

local function contains(text: string, phrase: string): boolean
	return string.find(text, "%f[%w]" .. phrase .. "%f[%W]") ~= nil
end

function HostGuide.reply(hostId: string, message: string): string?
	if not BrandCatalog.host(hostId) then return nil end
	local text = string.lower(message):gsub("[%s%-_]+", " ")
	local chosen = nil
	local matches = 0
	for _, mode in ModeCatalog.all() do
		for _, alias in ALIASES[mode.id] or {} do
			if contains(text, alias) then
				chosen = mode
				matches += 1
				break
			end
		end
	end
	if matches == 1 and chosen then
		local description = if chosen.id == "MemeArcade"
			then "Trade a simulated tape with play yarn, not real money."
			else chosen.blurb
		local entry = if chosen.playable then "Choose its Play button in the hub." else "This stall is not open yet."
		return `{chosen.title}: {description} {entry} {ASIDES[hostId][chosen.id]}`
	end
	if matches > 1 or contains(text, "help") or contains(text, "games") or contains(text, "stalls") or contains(text, "what can i play") then
		local names = {}
		for _, mode in ModeCatalog.all() do
			if mode.playable then table.insert(names, mode.title) end
		end
		local ending = if hostId == "HostMeo" then "Ask me about one. I have prepared at least one thought."
			elseif hostId == "HostMe" then "Ask about a game by name. One question at a time."
			else "Ask about one. The braincell cannot split screen."
		return `Open stalls: {table.concat(names, ", ")}. {ending}`
	end
	return nil
end

return HostGuide
