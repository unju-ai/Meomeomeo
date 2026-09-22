--!strict

-- Yarn Party seat table. Humans reclaim a bot seat (or an empty seat) only
-- while the phase is Lobby. Mid-round Play waits; it does not enter combat.
-- YarnPartyService applies models, countdowns, and replication.

local YarnPartyCatalog = require(script.Parent.YarnPartyCatalog)

export type Phase = "Lobby" | "Intro" | "Playing" | "Recap" | "Podium"
export type SeatKind = "human" | "bot" | "empty"

export type Seat = {
	index: number,
	kind: SeatKind,
	userId: number?,
	name: string,
	botSlot: number?,
	championId: string,
	alive: boolean,
	score: number,
}

export type JoinAction = "seated" | "already" | "wait" | "full"

export type JoinDecision = {
	action: JoinAction,
	error: string?,
	seat: number?,
	replacedBot: boolean?,
	countdown: number?,
}

export type ReleaseDecision = {
	found: boolean,
	seat: number,
	refilledBot: boolean,
	partyEmpty: boolean,
}

local BOT_SLOTS = 3
local HUMAN_CHAMPION = "NyanRocket"

local YarnPartyLobby = {
	JoinGraceSeconds = 1.25,
	HumanChampion = HUMAN_CHAMPION,
}

local function cloneSeats(seats: { Seat }): { Seat }
	local out = {}
	for i, seat in seats do
		out[i] = {
			index = seat.index,
			kind = seat.kind,
			userId = seat.userId,
			name = seat.name,
			botSlot = seat.botSlot,
			championId = seat.championId,
			alive = seat.alive,
			score = seat.score,
		}
	end
	return out
end

local function freeBotSlot(seats: { Seat }): number?
	local used: { [number]: boolean } = {}
	for _, seat in seats do
		if seat.kind == "bot" and seat.botSlot then
			used[seat.botSlot] = true
		end
	end
	for slot = 1, BOT_SLOTS do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

local function assignBot(seat: Seat, botSlot: number)
	seat.kind = "bot"
	seat.userId = nil
	seat.name = YarnPartyCatalog.botName(botSlot)
	seat.botSlot = botSlot
	seat.championId = YarnPartyCatalog.botChampion(botSlot)
	seat.alive = true
	seat.score = 0
end

local function assignHuman(seat: Seat, userId: number, name: string)
	seat.kind = "human"
	seat.userId = userId
	seat.name = name
	seat.botSlot = nil
	seat.championId = HUMAN_CHAMPION
	seat.alive = true
	seat.score = 0
end

local function assignEmpty(seat: Seat)
	seat.kind = "empty"
	seat.userId = nil
	seat.name = ""
	seat.botSlot = nil
	seat.championId = ""
	seat.alive = false
	seat.score = 0
end

function YarnPartyLobby.humanCount(seats: { Seat }): number
	local n = 0
	for _, seat in seats do
		if seat.kind == "human" then
			n += 1
		end
	end
	return n
end

function YarnPartyLobby.botCount(seats: { Seat }): number
	local n = 0
	for _, seat in seats do
		if seat.kind == "bot" then
			n += 1
		end
	end
	return n
end

function YarnPartyLobby.waitCopy(phase: string): string
	if phase == "Podium" then
		return "Wait for the next party — the crown is up."
	end
	return "Wait for the next party — this round already started."
end

-- A late hop-in must not restart the lobby count. Under a second left, hold
-- briefly so the new cat is on a spawn before GO. The count still reaches zero.
function YarnPartyLobby.countdownAfterJoin(remaining: number): number
	if remaining ~= remaining or remaining < YarnPartyLobby.JoinGraceSeconds then
		return YarnPartyLobby.JoinGraceSeconds
	end
	return remaining
end

function YarnPartyLobby.open(hostUserId: number, hostName: string): { Seat }
	local seats: { Seat } = {}
	for index = 1, YarnPartyCatalog.SeatCount do
		seats[index] = {
			index = index,
			kind = "empty",
			userId = nil,
			name = "",
			botSlot = nil,
			championId = "",
			alive = false,
			score = 0,
		}
	end
	assignHuman(seats[1], hostUserId, hostName)
	for index = 2, YarnPartyCatalog.SeatCount do
		local slot = freeBotSlot(seats)
		if slot then
			assignBot(seats[index], slot)
		end
	end
	return seats
end

function YarnPartyLobby.ensureBots(seats: { Seat }): { Seat }
	local nextSeats = cloneSeats(seats)
	for _, seat in nextSeats do
		if seat.kind == "empty" then
			local slot = freeBotSlot(nextSeats)
			if slot then
				assignBot(seat, slot)
			end
		end
	end
	return nextSeats
end

function YarnPartyLobby.claim(
	seats: { Seat },
	phase: string,
	userId: number,
	name: string,
	remaining: number
): ({ Seat }, JoinDecision)
	if phase ~= "Lobby" then
		return seats, {
			action = "wait",
			error = YarnPartyLobby.waitCopy(phase),
		}
	end
	for _, seat in seats do
		if seat.kind == "human" and seat.userId == userId then
			return seats, {
				action = "already",
				error = "Already at the party.",
				seat = seat.index,
			}
		end
	end
	-- First open seat in order. A bot there is removed; an empty seat is used as-is.
	local target: Seat? = nil
	for _, seat in seats do
		if seat.kind == "bot" or seat.kind == "empty" then
			target = seat
			break
		end
	end
	if not target then
		return seats, {
			action = "full",
			error = "This party is full — wait for the next one.",
		}
	end
	local replacedBot = target.kind == "bot"
	local nextSeats = cloneSeats(seats)
	assignHuman(nextSeats[target.index], userId, name)
	return nextSeats, {
		action = "seated",
		seat = target.index,
		replacedBot = replacedBot,
		countdown = YarnPartyLobby.countdownAfterJoin(remaining),
	}
end

function YarnPartyLobby.release(seats: { Seat }, phase: string, userId: number): ({ Seat }, ReleaseDecision)
	local index = 0
	for _, seat in seats do
		if seat.kind == "human" and seat.userId == userId then
			index = seat.index
			break
		end
	end
	if index == 0 then
		return seats, {
			found = false,
			seat = 0,
			refilledBot = false,
			partyEmpty = YarnPartyLobby.humanCount(seats) == 0,
		}
	end
	local nextSeats = cloneSeats(seats)
	local seat = nextSeats[index]
	if phase == "Lobby" then
		local slot = freeBotSlot(nextSeats)
		if slot then
			assignBot(seat, slot)
		else
			assignEmpty(seat)
		end
	else
		assignEmpty(seat)
	end
	local refilled = nextSeats[index].kind == "bot"
	return nextSeats, {
		found = true,
		seat = index,
		refilledBot = refilled,
		partyEmpty = YarnPartyLobby.humanCount(nextSeats) == 0,
	}
end

return YarnPartyLobby
