--!strict

-- Same-server Cat Rift party stub. Invite, accept, decline, expire, and leave.
-- MatchmakingService applies queue, Practice, and replication.
-- Not Roblox friends and not cross-server.

local CatRiftParty = {
	InviteSeconds = 20,
}

type SeatGroup = {
	ids: { number },
	order: number,
}

local function byPartySize(a: SeatGroup, b: SeatGroup): boolean
	if #a.ids ~= #b.ids then
		return #a.ids > #b.ids
	end
	return a.order < b.order
end

export type Invite = {
	fromUserId: number,
	toUserId: number,
	expiresAt: number,
}

export type Notice = {
	id: number,
	text: string,
	at: number,
}

export type State = {
	parties: { [number]: { number } },
	invites: { Invite },
	notices: { [number]: Notice },
	nextNotice: number,
}

export type Result = {
	ok: boolean,
	error: string?,
}

export type Options = {
	ttl: number,
	maxSize: number,
	names: { [number]: string },
	now: number,
}

export type Role = "solo" | "leader" | "member"

local function clone(state: State): State
	local parties: { [number]: { number } } = {}
	for leader, members in state.parties do
		local copy = {}
		for _, member in members do
			table.insert(copy, member)
		end
		parties[leader] = copy
	end
	local invites: { Invite } = {}
	for _, invite in state.invites do
		table.insert(invites, {
			fromUserId = invite.fromUserId,
			toUserId = invite.toUserId,
			expiresAt = invite.expiresAt,
		})
	end
	local notices: { [number]: Notice } = {}
	for userId, notice in state.notices do
		notices[userId] = {
			id = notice.id,
			text = notice.text,
			at = notice.at,
		}
	end
	return {
		parties = parties,
		invites = invites,
		notices = notices,
		nextNotice = state.nextNotice,
	}
end

local function who(names: { [number]: string }, userId: number): string
	local name = names[userId]
	if name and name ~= "" then
		return name
	end
	return "Cat"
end

local function note(state: State, userId: number, text: string, at: number)
	state.nextNotice += 1
	state.notices[userId] = {
		id = state.nextNotice,
		text = text,
		at = at,
	}
end

function CatRiftParty.empty(): State
	return {
		parties = {},
		invites = {},
		notices = {},
		nextNotice = 0,
	}
end

function CatRiftParty.leaderOf(state: State, userId: number): number?
	if state.parties[userId] then
		return userId
	end
	for leader, members in state.parties do
		if table.find(members, userId) then
			return leader
		end
	end
	return nil
end

function CatRiftParty.role(state: State, userId: number): Role
	local leader = CatRiftParty.leaderOf(state, userId)
	if not leader then
		return "solo"
	end
	if leader == userId then
		return "leader"
	end
	return "member"
end

function CatRiftParty.membersOf(state: State, userId: number): { number }
	local leader = CatRiftParty.leaderOf(state, userId)
	if not leader then
		return { userId }
	end
	local all = { leader }
	local bag = state.parties[leader]
	if bag then
		for _, member in bag do
			table.insert(all, member)
		end
	end
	return all
end

function CatRiftParty.sameParty(state: State, a: number, b: number): boolean
	if a == b then
		return true
	end
	local leader = CatRiftParty.leaderOf(state, a)
	if not leader then
		return false
	end
	if leader == b then
		return true
	end
	local bag = state.parties[leader]
	return bag ~= nil and table.find(bag, b) ~= nil
end

function CatRiftParty.incoming(state: State, userId: number, now: number): Invite?
	for _, invite in state.invites do
		if invite.toUserId == userId and invite.expiresAt > now then
			return invite
		end
	end
	return nil
end

function CatRiftParty.outgoing(state: State, userId: number, now: number): Invite?
	for _, invite in state.invites do
		if invite.fromUserId == userId and invite.expiresAt > now then
			return invite
		end
	end
	return nil
end

function CatRiftParty.pendingCount(state: State, now: number): number
	local count = 0
	for _, invite in state.invites do
		if invite.expiresAt > now then
			count += 1
		end
	end
	return count
end

function CatRiftParty.tell(state: State, userId: number, text: string, at: number): State
	local nextState = clone(state)
	note(nextState, userId, text, at)
	return nextState
end

function CatRiftParty.sweep(state: State, options: Options): (State, boolean)
	local nextState = clone(state)
	local kept: { Invite } = {}
	local changed = false
	for _, invite in nextState.invites do
		if invite.expiresAt > options.now then
			table.insert(kept, invite)
		else
			changed = true
			note(nextState, invite.fromUserId, `Invite to {who(options.names, invite.toUserId)} expired.`, options.now)
			note(nextState, invite.toUserId, `{who(options.names, invite.fromUserId)}'s invite expired.`, options.now)
		end
	end
	nextState.invites = kept
	return nextState, changed
end

local function takeIncoming(state: State, userId: number, now: number): (Invite?, number?)
	local found: Invite? = nil
	local expiredFrom: number? = nil
	local kept: { Invite } = {}
	for _, invite in state.invites do
		if invite.toUserId == userId then
			if invite.expiresAt > now and found == nil then
				found = invite
			else
				expiredFrom = invite.fromUserId
			end
		else
			table.insert(kept, invite)
		end
	end
	state.invites = kept
	return found, expiredFrom
end

function CatRiftParty.invite(state: State, fromId: number, toId: number, options: Options): (State, Result)
	local nextState = clone(state)
	if fromId == toId then
		return nextState, { ok = false, error = "You are already in your party." }
	end
	if CatRiftParty.sameParty(nextState, fromId, toId) then
		return nextState, { ok = false, error = "They are already in your party." }
	end
	if CatRiftParty.leaderOf(nextState, toId) then
		return nextState, { ok = false, error = "They are already in another party." }
	end
	if #CatRiftParty.membersOf(nextState, fromId) >= options.maxSize then
		return nextState, { ok = false, error = "Party is full." }
	end

	local kept: { Invite } = {}
	for _, invite in nextState.invites do
		local mine = invite.fromUserId == fromId
		local theirs = invite.toUserId == toId
		if mine or theirs then
			if invite.expiresAt > options.now and not mine and invite.fromUserId ~= fromId then
				note(
					nextState,
					invite.fromUserId,
					`{who(options.names, toId)} got another invite.`,
					options.now
				)
			end
		else
			table.insert(kept, invite)
		end
	end
	nextState.invites = kept
	table.insert(nextState.invites, {
		fromUserId = fromId,
		toUserId = toId,
		expiresAt = options.now + options.ttl,
	})
	note(
		nextState,
		fromId,
		`Invite sent to {who(options.names, toId)}. They have {options.ttl}s to accept.`,
		options.now
	)
	note(nextState, toId, `{who(options.names, fromId)} invited you to Cat Rift.`, options.now)
	return nextState, { ok = true }
end

function CatRiftParty.accept(state: State, userId: number, options: Options): (State, Result)
	local nextState = clone(state)
	local invite, expiredFrom = takeIncoming(nextState, userId, options.now)
	if not invite then
		if expiredFrom then
			note(nextState, expiredFrom, `Invite to {who(options.names, userId)} expired.`, options.now)
		end
		local reason = if expiredFrom then "That invite expired." else "No invite to accept."
		return nextState, { ok = false, error = reason }
	end
	if CatRiftParty.leaderOf(nextState, userId) then
		note(nextState, invite.fromUserId, `{who(options.names, userId)} is already in a party.`, options.now)
		return nextState, { ok = false, error = "Leave your party first." }
	end

	local leader = CatRiftParty.leaderOf(nextState, invite.fromUserId) or invite.fromUserId
	if #CatRiftParty.membersOf(nextState, leader) >= options.maxSize then
		note(nextState, userId, "That party is full.", options.now)
		note(nextState, invite.fromUserId, "Party is full.", options.now)
		return nextState, { ok = false, error = "Party is full." }
	end
	local bag = nextState.parties[leader]
	if not bag then
		bag = {}
		nextState.parties[leader] = bag
	end
	if leader ~= userId and not table.find(bag, userId) then
		table.insert(bag, userId)
	end

	note(nextState, userId, `You joined {who(options.names, leader)}'s party.`, options.now)
	note(nextState, leader, `{who(options.names, userId)} joined your party.`, options.now)
	for _, member in bag do
		if member ~= userId then
			note(nextState, member, `{who(options.names, userId)} joined the party.`, options.now)
		end
	end
	if invite.fromUserId ~= leader and invite.fromUserId ~= userId then
		note(nextState, invite.fromUserId, `{who(options.names, userId)} joined the party.`, options.now)
	end
	return nextState, { ok = true }
end

function CatRiftParty.decline(state: State, userId: number, options: Options): (State, Result)
	local nextState = clone(state)
	local invite, expiredFrom = takeIncoming(nextState, userId, options.now)
	if not invite then
		if expiredFrom then
			note(nextState, expiredFrom, `Invite to {who(options.names, userId)} expired.`, options.now)
		end
		local reason = if expiredFrom then "That invite expired." else "No invite to decline."
		return nextState, { ok = false, error = reason }
	end
	note(nextState, invite.fromUserId, `{who(options.names, userId)} declined.`, options.now)
	note(nextState, userId, "Invite declined.", options.now)
	return nextState, { ok = true }
end

function CatRiftParty.leave(state: State, userId: number, options: Options): (State, Result)
	local leader = CatRiftParty.leaderOf(state, userId)
	if not leader then
		return state, { ok = false, error = "You are not in a party." }
	end
	local nextState = clone(state)
	local bag = nextState.parties[leader]
	local members = {}
	if bag then
		for _, member in bag do
			table.insert(members, member)
		end
	end

	if userId == leader then
		nextState.parties[leader] = nil
		note(nextState, userId, "You left the party.", options.now)
		if #members <= 1 then
			local other = members[1]
			if other then
				note(nextState, other, `{who(options.names, userId)} left. You are solo.`, options.now)
			end
		else
			local newLeader = members[1]
			local rest = {}
			for index = 2, #members do
				table.insert(rest, members[index])
			end
			nextState.parties[newLeader] = rest
			note(nextState, newLeader, `{who(options.names, userId)} left. You lead the party.`, options.now)
			for _, member in rest do
				note(
					nextState,
					member,
					`{who(options.names, userId)} left. {who(options.names, newLeader)} leads.`,
					options.now
				)
			end
		end
	else
		local index = table.find(members, userId)
		if index then
			table.remove(members, index)
		end
		if #members == 0 then
			nextState.parties[leader] = nil
			note(nextState, leader, `{who(options.names, userId)} left. You are solo.`, options.now)
		else
			nextState.parties[leader] = members
			note(nextState, leader, `{who(options.names, userId)} left the party.`, options.now)
			for _, member in members do
				note(nextState, member, `{who(options.names, userId)} left the party.`, options.now)
			end
		end
		note(nextState, userId, "You left the party.", options.now)
	end
	return nextState, { ok = true }
end

function CatRiftParty.disconnect(state: State, userId: number, options: Options): State
	local nextState = clone(state)
	if CatRiftParty.role(nextState, userId) ~= "solo" then
		local left, result = CatRiftParty.leave(nextState, userId, options)
		if result.ok then
			nextState = left
		end
	end
	local kept: { Invite } = {}
	for _, invite in nextState.invites do
		if invite.fromUserId == userId then
			note(nextState, invite.toUserId, `{who(options.names, userId)}'s invite was cancelled.`, options.now)
		elseif invite.toUserId == userId then
			note(nextState, invite.fromUserId, `{who(options.names, userId)} left before accepting.`, options.now)
		else
			table.insert(kept, invite)
		end
	end
	nextState.invites = kept
	return nextState
end

function CatRiftParty.queueRoster(state: State, userId: number, names: { [number]: string }): ({ number }?, string?)
	if CatRiftParty.role(state, userId) == "member" then
		local leader = CatRiftParty.leaderOf(state, userId)
		local name = if leader then who(names, leader) else "Your leader"
		return nil, `{name} leads this party — they start the queue.`
	end
	return CatRiftParty.membersOf(state, userId), nil
end

function CatRiftParty.leaveQueueRoster(state: State, userId: number): { number }
	if CatRiftParty.role(state, userId) == "leader" then
		return CatRiftParty.membersOf(state, userId)
	end
	return { userId }
end

function CatRiftParty.practiceRoster(
	state: State,
	userId: number,
	names: { [number]: string },
	anyMember: boolean
): ({ number }?, string?)
	if CatRiftParty.role(state, userId) == "member" and not anyMember then
		local leader = CatRiftParty.leaderOf(state, userId)
		local name = if leader then who(names, leader) else "Your leader"
		return nil, `{name} leads this party — they start Practice.`
	end
	return CatRiftParty.membersOf(state, userId), nil
end

function CatRiftParty.selectForMatch(state: State, queuedIds: { number }, maxPlayers: number): { number }
	local seen: { [number]: boolean } = {}
	local groups: { SeatGroup } = {}
	local function queued(id: number): boolean
		return table.find(queuedIds, id) ~= nil
	end
	for index, id in queuedIds do
		if not seen[id] then
			local ids: { number } = {}
			for _, member in CatRiftParty.membersOf(state, id) do
				if queued(member) and not seen[member] then
					seen[member] = true
					table.insert(ids, member)
				end
			end
			local group: SeatGroup = { ids = ids, order = index }
			table.insert(groups, group)
		end
	end
	table.sort(groups, byPartySize)
	local selected = {}
	for _, group in groups do
		if #selected + #group.ids <= maxPlayers then
			for _, member in group.ids do
				table.insert(selected, member)
			end
		end
	end
	return selected
end

function CatRiftParty.assignTeams(state: State, userIds: { number }, teamSize: number): { [number]: "Blue" | "Red" }
	local seen: { [number]: boolean } = {}
	local groups: { SeatGroup } = {}
	local function listed(id: number): boolean
		return table.find(userIds, id) ~= nil
	end
	for index, id in userIds do
		if not seen[id] then
			local ids: { number } = {}
			for _, member in CatRiftParty.membersOf(state, id) do
				if listed(member) and not seen[member] then
					seen[member] = true
					table.insert(ids, member)
				end
			end
			local group: SeatGroup = { ids = ids, order = index }
			table.insert(groups, group)
		end
	end
	table.sort(groups, byPartySize)

	local blue = 0
	local red = 0
	local assigned: { [number]: "Blue" | "Red" } = {}
	for _, group in groups do
		local team: "Blue" | "Red"
		local size = #group.ids
		if blue + size <= teamSize and (blue <= red or red + size > teamSize) then
			team = "Blue"
			blue += size
		elseif red + size <= teamSize then
			team = "Red"
			red += size
		else
			team = "Blue"
			blue += size
		end
		for _, id in group.ids do
			assigned[id] = team
		end
	end
	return assigned
end

return CatRiftParty
