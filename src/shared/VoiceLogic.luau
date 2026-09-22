--!strict

-- Pure team-voice routing and HUD copy.
-- No VoiceChatService, no instances. The server applies the plan; the client
-- only displays it. Speaking amplitude is a client AudioAnalyzer reading —
-- this module never invents a speaking flag from a missing signal.

local VoiceLogic = {}

export type Seat = {
	userId: number,
	team: string,
	isBot: boolean,
}

export type AccessKind = "TeamAllow" | "Silent" | "Proximity"

export type AccessPlan = {
	kind: AccessKind,
	userIds: { number },
}

export type PlanInput = {
	mode: string,
	outsideMatch: string?,
	selfUserId: number,
	selfTeam: string?,
	seats: { Seat }?,
}

export type PresentInput = {
	mode: string,
	availability: string,
	outsideMatch: string?,
	localEnabled: boolean?,
	muted: boolean,
	selfUserId: number,
	selfTeam: string?,
	seats: { Seat }?,
	deviceReady: boolean,
	signalAvailable: boolean,
	speaking: boolean,
	serverDetail: string?,
}

export type PresentTone = "ready" | "warn" | "muted"

export type PresentView = {
	title: string,
	detail: string,
	youLine: string,
	micLine: string?,
	footer: string,
	pulse: boolean,
	tone: PresentTone,
	peerCount: number,
	plan: AccessPlan,
}

-- Seconds after a team change, death, or respawn to rewrite access lists.
-- AudioDeviceInput can show up a moment after the character does.
VoiceLogic.ReapplyDelays = { 0, 0.25, 1, 2.5 }

-- RmsLevel / PeakLevel are 0–1 on the client. The server always reads 0.
VoiceLogic.SpeakingRms = 0.05

local function outsideOf(value: string?): string
	if value == "Proximity" then
		return "Proximity"
	end
	return "Off"
end

function VoiceLogic.peerUserIds(selfUserId: number, selfTeam: string?, seats: { Seat }?): { number }
	local ids = {}
	if selfTeam == nil or selfTeam == "" or seats == nil then
		return ids
	end
	local seen: { [number]: boolean } = {}
	for _, seat in seats do
		if
			seat.isBot ~= true
			and seat.userId > 0
			and seat.userId ~= selfUserId
			and seat.team == selfTeam
			and seen[seat.userId] ~= true
		then
			seen[seat.userId] = true
			table.insert(ids, seat.userId)
		end
	end
	table.sort(ids)
	return ids
end

function VoiceLogic.accessPlan(input: PlanInput): AccessPlan
	local peers = VoiceLogic.peerUserIds(input.selfUserId, input.selfTeam, input.seats)
	if input.mode ~= "Team" then
		return { kind = "Proximity", userIds = {} }
	end
	if input.selfTeam == nil or input.selfTeam == "" then
		if outsideOf(input.outsideMatch) == "Proximity" then
			return { kind = "Proximity", userIds = {} }
		end
		return { kind = "Silent", userIds = {} }
	end
	return { kind = "TeamAllow", userIds = peers }
end

function VoiceLogic.shouldWatchUser(selfUserId: number, selfTeam: string?, otherUserId: number, otherTeam: string?, otherIsBot: boolean): boolean
	if otherIsBot or otherUserId <= 0 or otherUserId == selfUserId then
		return false
	end
	if selfTeam == nil or selfTeam == "" or otherTeam ~= selfTeam then
		return false
	end
	return true
end

function VoiceLogic.isSpeaking(rms: number, peak: number): boolean
	if rms ~= rms or peak ~= peak then
		return false
	end
	return rms >= VoiceLogic.SpeakingRms or peak >= VoiceLogic.SpeakingRms
end

local function anyBot(seats: { Seat }?): boolean
	if seats == nil then
		return false
	end
	for _, seat in seats do
		if seat.isBot == true then
			return true
		end
	end
	return false
end

local function youLine(availability: string, localEnabled: boolean?, muted: boolean): string
	if localEnabled == false or availability == "StudioBlocked" or availability == "Unavailable" or availability == "PlayerIneligible" then
		return "You: not eligible"
	end
	if muted then
		return "You: muted"
	end
	if localEnabled == true then
		return "You: live"
	end
	return "You: checking"
end

function VoiceLogic.present(input: PresentInput): PresentView
	local plan = VoiceLogic.accessPlan({
		mode = input.mode,
		outsideMatch = input.outsideMatch,
		selfUserId = input.selfUserId,
		selfTeam = input.selfTeam,
		seats = input.seats,
	})
	local availability = input.availability
	local you = youLine(availability, input.localEnabled, input.muted)
	local tone: PresentTone = "ready"
	if availability ~= "Ready" or input.localEnabled == false then
		tone = "warn"
	elseif input.muted then
		tone = "muted"
	end

	local label = "Team"
	local detail = "Teammates only. Enemy cats cannot hear you."
	if availability == "StudioBlocked" then
		label = "Studio"
		detail = "Studio blocks voice. Publish, enable Voice Chat, and use two eligible clients."
	elseif availability == "Unavailable" or availability == "PlayerIneligible" then
		label = "Unavailable"
		local server = input.serverDetail
		if server ~= nil and server ~= "" then
			detail = server
		else
			detail = "Voice chat is unavailable on this server."
		end
	elseif plan.kind == "Proximity" then
		label = "Proximity"
		detail = "Nearby cats can hear you."
	elseif plan.kind == "Silent" then
		label = "Off"
		detail = "Quiet in the hub and stalls. Team voice starts when a match assigns your side."
	else
		label = "Team"
		local peers = #plan.userIds
		local bots = anyBot(input.seats)
		if peers == 0 and bots then
			detail = "No voice teammates. Bots are silent, and enemy cats cannot hear you."
		elseif peers == 0 then
			detail = "Teammates only. Nobody else is on your side yet."
		elseif bots then
			detail = "Teammates only. Enemy cats cannot hear you. Bots are not on voice."
		else
			detail = "Teammates only. Enemy cats cannot hear you."
		end
	end

	local mic: string? = nil
	local canArm = availability == "Ready"
		and input.localEnabled ~= false
		and not input.muted
		and plan.kind ~= "Silent"
		and input.deviceReady
	if canArm then
		-- Speaking requires a real analyzer reading. A bare loud flag is "Mic armed".
		if input.signalAvailable and input.speaking then
			mic = "Speaking"
		else
			mic = "Mic armed"
		end
	end

	local pulse = mic == "Speaking"
	local icon = if tone == "ready" then "🎙️" else "🔇"
	local footer = you
	if mic ~= nil then
		footer = `{you} · {mic}`
	end

	return {
		title = `{icon} Voice · {label}`,
		detail = detail,
		youLine = you,
		micLine = mic,
		footer = footer,
		pulse = pulse,
		tone = tone,
		peerCount = #plan.userIds,
		plan = plan,
	}
end

return VoiceLogic
