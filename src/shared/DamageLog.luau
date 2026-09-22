--!strict

-- Last N damage hits per champion for the current match only.
-- CombatService records. The death recap reads a short aggregate.
-- Cleared on respawn and when the match ends. Not a DataStore.

local Types = require(script.Parent.Types)

local DamageLog = {}

DamageLog.Capacity = 24
DamageLog.Window = 12
DamageLog.MaxLines = 6
-- Hide the card this many seconds before the fountain timer.
DamageLog.HideLead = 2.5

local KIND_WORD: { [string]: string } = {
	champion = "Cat",
	tower = "Post",
	minion = "Kitten",
	jungle = "Camp",
	item = "Item",
}

local logs: { [number]: { Types.DamageHit } } = {}

function DamageLog.kindWord(kind: string): string
	return KIND_WORD[kind] or "Hit"
end

function DamageLog.record(victimUserId: number, hit: Types.DamageHit)
	local bag = logs[victimUserId]
	if not bag then
		bag = {}
		logs[victimUserId] = bag
	end
	if hit.killingBlow then
		for _, older in bag do
			older.killingBlow = false
		end
	end
	table.insert(bag, hit)
	while #bag > DamageLog.Capacity do
		table.remove(bag, 1)
	end
end

function DamageLog.count(victimUserId: number): number
	local bag = logs[victimUserId]
	return if bag then #bag else 0
end

function DamageLog.hits(victimUserId: number): { Types.DamageHit }
	local copy: { Types.DamageHit } = {}
	local bag = logs[victimUserId]
	if bag then
		for _, hit in bag do
			table.insert(copy, hit)
		end
	end
	return copy
end

function DamageLog.recap(victimUserId: number, diedAt: number): { Types.DamageLine }
	local bag = logs[victimUserId]
	local grouped: { [string]: Types.DamageLine } = {}
	local order: { string } = {}
	if bag then
		local oldest = diedAt - DamageLog.Window
		for _, hit in bag do
			if hit.at + 1e-4 >= oldest and hit.amount > 0 then
				local label = if hit.label and hit.label ~= "" then hit.label :: string else "Hit"
				local id = hit.sourceId or hit.sourceName
				local key = `{hit.sourceKind}|{id}|{hit.sourceName}|{label}`
				local existing = grouped[key]
				if existing then
					existing.amount += hit.amount
					if hit.at > existing.at then
						existing.at = hit.at
					end
					if hit.killingBlow then
						existing.killingBlow = true
					end
				else
					grouped[key] = {
						sourceKind = hit.sourceKind,
						sourceName = hit.sourceName,
						sourceId = hit.sourceId,
						label = label,
						amount = hit.amount,
						killingBlow = hit.killingBlow,
						at = hit.at,
					}
					table.insert(order, key)
				end
			end
		end
	end

	local lines: { Types.DamageLine } = {}
	for _, key in order do
		local line = grouped[key]
		local rounded = math.floor(line.amount + 0.5)
		if rounded <= 0 and line.amount > 0 then
			rounded = 1
		end
		if rounded > 0 then
			line.amount = rounded
			table.insert(lines, line)
		end
	end

	table.sort(lines, function(a, b)
		if a.killingBlow ~= b.killingBlow then
			return a.killingBlow
		end
		if a.amount ~= b.amount then
			return a.amount > b.amount
		end
		return a.at > b.at
	end)
	while #lines > DamageLog.MaxLines do
		table.remove(lines)
	end
	return lines
end

function DamageLog.clear(victimUserId: number)
	logs[victimUserId] = nil
end

function DamageLog.clearAll()
	table.clear(logs)
end

return DamageLog
