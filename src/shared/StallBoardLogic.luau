--!strict

-- Pure stall-board ranking (Koi daily catch, Arcade daily profit). No DataStore, no Player.

export type StoredEntry = {
	userId: number,
	name: string,
	score: number,
	detail: string,
	at: number,
	anon: boolean?,
}

local StallBoardLogic = {
	TopN = 10,
	RateLimit = 2.5,
	AnonName = "Anonymous Cat",
}

function StallBoardLogic.clipName(name: string): string
	local trimmed = string.gsub(name, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	if trimmed == "" then
		return "Cat"
	end
	if #trimmed > 18 then
		return string.sub(trimmed, 1, 18)
	end
	return trimmed
end

function StallBoardLogic.clipDetail(detail: string): string
	local trimmed = string.gsub(detail, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	if trimmed == "" then
		return "—"
	end
	if #trimmed > 40 then
		return string.sub(trimmed, 1, 40)
	end
	return trimmed
end

function StallBoardLogic.visibleName(name: string, hidden: boolean): string
	if hidden then
		return StallBoardLogic.AnonName
	end
	return StallBoardLogic.clipName(name)
end

local function better(a: StoredEntry, b: StoredEntry): boolean
	if a.score ~= b.score then
		return a.score > b.score
	end
	return a.at < b.at
end

function StallBoardLogic.sort(entries: { StoredEntry }): { StoredEntry }
	table.sort(entries, better)
	return entries
end

function StallBoardLogic.rankOf(entries: { StoredEntry }, userId: number): number?
	for i, row in entries do
		if row.userId == userId then
			return i
		end
	end
	return nil
end

function StallBoardLogic.submit(
	entries: { StoredEntry },
	incoming: StoredEntry
): {
	entries: { StoredEntry },
	rank: number?,
	improved: boolean,
}
	local nextList: { StoredEntry } = {}
	local prior: StoredEntry? = nil
	for _, row in entries do
		if row.userId == incoming.userId then
			prior = row
		else
			table.insert(nextList, row)
		end
	end
	local improved = prior == nil or incoming.score > prior.score
	if not improved then
		table.insert(nextList, prior :: StoredEntry)
		StallBoardLogic.sort(nextList)
		return {
			entries = nextList,
			rank = StallBoardLogic.rankOf(nextList, incoming.userId),
			improved = false,
		}
	end
	table.insert(nextList, incoming)
	StallBoardLogic.sort(nextList)
	while #nextList > StallBoardLogic.TopN do
		table.remove(nextList)
	end
	return {
		entries = nextList,
		rank = StallBoardLogic.rankOf(nextList, incoming.userId),
		improved = true,
	}
end

return StallBoardLogic
