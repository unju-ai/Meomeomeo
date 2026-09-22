--!strict

-- Pure rules for Cat Rift last-seen ghosts.
-- The client paints the silhouette. This module only decides when a ghost
-- exists and which pose it is stuck to. It is not vision and it is not replicated.

local LastSeenGhostLogic = {}

-- Short enough to read as "just left sight", long enough to track in a lane.
LastSeenGhostLogic.FadeSeconds = 1.8
-- Fully opaque parts start here, then ease toward invisible (t^2: hold, then drop).
LastSeenGhostLogic.StartTransparency = 0.45

export type Pose = {
	x: number,
	y: number,
	z: number,
	r00: number,
	r01: number,
	r02: number,
	r10: number,
	r11: number,
	r12: number,
	r20: number,
	r21: number,
	r22: number,
}

export type Row = {
	pose: Pose,
	ghost: Pose?,
	born: number?,
}

export type State = { [string]: Row }

local function copyPose(pose: Pose): Pose
	return {
		x = pose.x,
		y = pose.y,
		z = pose.z,
		r00 = pose.r00,
		r01 = pose.r01,
		r02 = pose.r02,
		r10 = pose.r10,
		r11 = pose.r11,
		r12 = pose.r12,
		r20 = pose.r20,
		r21 = pose.r21,
		r22 = pose.r22,
	}
end

function LastSeenGhostLogic.pose(
	x: number,
	y: number,
	z: number,
	r00: number,
	r01: number,
	r02: number,
	r10: number,
	r11: number,
	r12: number,
	r20: number,
	r21: number,
	r22: number
): Pose
	return {
		x = x,
		y = y,
		z = z,
		r00 = r00,
		r01 = r01,
		r02 = r02,
		r10 = r10,
		r11 = r11,
		r12 = r12,
		r20 = r20,
		r21 = r21,
		r22 = r22,
	}
end

function LastSeenGhostLogic.newState(): State
	return {}
end

-- Unit is in vision. Drop any ghost immediately and remember this pose.
function LastSeenGhostLogic.seen(state: State, key: string, pose: Pose)
	local frozen = copyPose(pose)
	local row = state[key]
	if row then
		row.pose = frozen
		row.ghost = nil
		row.born = nil
	else
		state[key] = {
			pose = frozen,
			ghost = nil,
			born = nil,
		}
	end
end

-- Visible again but we could not read a pose. Still clear the ghost.
function LastSeenGhostLogic.recall(state: State, key: string)
	local row = state[key]
	if not row then
		return
	end
	row.ghost = nil
	row.born = nil
end

-- Unit left vision. Spawns once, frozen at the last seen() pose.
-- Later calls do not take a new position — the live body must not move the ghost.
function LastSeenGhostLogic.lost(state: State, key: string, now: number): Pose?
	local row = state[key]
	if not row or row.born ~= nil then
		return nil
	end
	local frozen = copyPose(row.pose)
	row.ghost = frozen
	row.born = now
	return frozen
end

function LastSeenGhostLogic.ghostOf(state: State, key: string): Pose?
	local row = state[key]
	if not row then
		return nil
	end
	return row.ghost
end

function LastSeenGhostLogic.bornAt(state: State, key: string): number?
	local row = state[key]
	if not row then
		return nil
	end
	return row.born
end

function LastSeenGhostLogic.expireDue(state: State, now: number): { string }
	local due = {}
	for key, row in state do
		if row.ghost and row.born ~= nil and now - row.born >= LastSeenGhostLogic.FadeSeconds then
			row.ghost = nil
			table.insert(due, key)
		end
	end
	return due
end

function LastSeenGhostLogic.partTransparency(base: number, age: number): number
	local duration = LastSeenGhostLogic.FadeSeconds
	local t = 0
	if duration > 0 then
		t = math.clamp(age / duration, 0, 1)
	end
	local eased = t * t
	local start = math.max(base, LastSeenGhostLogic.StartTransparency)
	return start + (1 - start) * eased
end

function LastSeenGhostLogic.clear(state: State)
	table.clear(state)
end

return LastSeenGhostLogic
