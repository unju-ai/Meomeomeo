--!strict

-- Pure publish checklist. The server passes booleans from Config and probes.
-- This module never reads Config, never edits it, and never invents PlaceIds
-- or Developer Product ids. Studio zeros stay playable: the report is informational.

local PublishChecklist = {}

export type Status = "Ready" | "Stub" | "Blocked"

export type Facts = {
	matchPlaceSet: boolean,
	lobbyPlaceSet: boolean,
	developerProductSet: boolean,
	voiceServicePresent: boolean,
	dataStoreReachable: boolean,
	economyEnabled: boolean,
}

export type Row = {
	id: string,
	label: string,
	status: Status,
	statusLabel: string,
	fix: string,
}

export type Report = {
	rows: { Row },
	summary: string,
	informational: boolean,
}

local STATUS_LABEL: { [Status]: string } = {
	Ready = "Ready",
	Stub = "Still Studio stub",
	Blocked = "Blocked",
}

local function row(id: string, label: string, status: Status, fix: string): Row
	return {
		id = id,
		label = label,
		status = status,
		statusLabel = STATUS_LABEL[status],
		fix = fix,
	}
end

function PublishChecklist.rows(facts: Facts): { Row }
	return {
		row(
			"MatchPlace",
			"Match place",
			if facts.matchPlaceSet then "Ready" else "Stub",
			if facts.matchPlaceSet
				then "Config.Match.MatchPlaceId is set. Queue can try a reserved server. See PLAYTEST §7."
				else "Reserved teleport needs a published PlaceId in Config.Match.MatchPlaceId. 0 stays in-place. See PLAYTEST §7."
		),
		row(
			"LobbyPlace",
			"Lobby place",
			if facts.lobbyPlaceSet then "Ready" else "Stub",
			if facts.lobbyPlaceSet
				then "Config.Match.LobbyPlaceId is set for an explicit Back to lobby. See PLAYTEST §7."
				else "Config.Match.LobbyPlaceId is still 0, so Back to lobby remembers the queue origin. See PLAYTEST §7."
		),
		row(
			"DeveloperProduct",
			"Developer product",
			if facts.developerProductSet then "Ready" else "Stub",
			if facts.developerProductSet
				then "Config.Nft404.DeveloperProductId is set. Live mint can prompt that product. See PLAYTEST §7."
				else "Config.Nft404.DeveloperProductId is still 0, so Studio keeps the mock grant. See PLAYTEST §7."
		),
		row(
			"VoiceService",
			"Voice service",
			if facts.voiceServicePresent then "Ready" else "Blocked",
			if facts.voiceServicePresent
				then "VoiceChatService is in this place. Live mics still need Experience Settings and two eligible clients. See PLAYTEST §7."
				else "VoiceChatService is missing. The Rojo tree declares it. Enable Voice Chat under Experience Settings. See PLAYTEST §7."
		),
		row(
			"DataStore",
			"DataStore API",
			if facts.dataStoreReachable then "Ready" else "Stub",
			if facts.dataStoreReachable
				then "DataStore GetAsync answered, so saves can persist. See PLAYTEST §7."
				else "DataStore API did not answer. Studio without API Services stays on memory. Play still works. See PLAYTEST §7."
		),
		row(
			"Economy",
			"Economy",
			if facts.economyEnabled then "Ready" else "Blocked",
			if facts.economyEnabled
				then "Config.Economy.Enabled is on, so meme cheers can run. See PLAYTEST §7."
				else "Config.Economy.Enabled is off. Turn it on before a live market. Studio Play is not gated. See PLAYTEST §7."
		),
	}
end

function PublishChecklist.summary(rows: { Row }): string
	local ready = 0
	local stub = 0
	local blocked = 0
	for _, item in rows do
		if item.status == "Ready" then
			ready += 1
		elseif item.status == "Blocked" then
			blocked += 1
		else
			stub += 1
		end
	end
	return `Ready {ready} · Still Studio stub {stub} · Blocked {blocked}`
end

function PublishChecklist.report(facts: Facts): Report
	local rows = PublishChecklist.rows(facts)
	return {
		rows = rows,
		summary = PublishChecklist.summary(rows),
		informational = true,
	}
end

-- Solo Play with the committed defaults: ids unset, Rojo voice service present,
-- API Services off, economy left on. Not a hard gate.
function PublishChecklist.studioSoloFacts(): Facts
	return {
		matchPlaceSet = false,
		lobbyPlaceSet = false,
		developerProductSet = false,
		voiceServicePresent = true,
		dataStoreReachable = false,
		economyEnabled = true,
	}
end

return PublishChecklist
