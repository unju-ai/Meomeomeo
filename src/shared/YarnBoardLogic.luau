--!strict

-- Pure daily-board ranking. No DataStore, no Player — easy to smoke-test.

export type StoredEntry = {
	userId: number,
	name: string,
	score: number,
	meters: number,
	championId: string,
	at: number,
}

local YarnBoardLogic = {
	TopN = 10,
	RateLimit = 2.5,
}

function YarnBoardLogic.clipName(name: string): string
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

function YarnBoardLogic.podiumTitle(rank: number): string?
	if rank == 1 then
		return "#1 YARN LORD"
	elseif rank == 2 then
		return "#2 YARN ACE"
	elseif rank == 3 then
		return "#3 YARN CREW"
	end
	return nil
end

local function better(a: StoredEntry, b: StoredEntry): boolean
	if a.score ~= b.score then
		return a.score > b.score
	end
	if a.meters ~= b.meters then
		return a.meters > b.meters
	end
	return a.at < b.at
end

function YarnBoardLogic.sort(entries: { StoredEntry }): { StoredEntry }
	table.sort(entries, better)
	return entries
end

function YarnBoardLogic.rankOf(entries: { StoredEntry }, userId: number): number?
	for i, row in entries do
		if row.userId == userId then
			return i
		end
	end
	return nil
end

function YarnBoardLogic.submit(
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
		YarnBoardLogic.sort(nextList)
		return {
			entries = nextList,
			rank = YarnBoardLogic.rankOf(nextList, incoming.userId),
			improved = false,
		}
	end
	table.insert(nextList, incoming)
	YarnBoardLogic.sort(nextList)
	while #nextList > YarnBoardLogic.TopN do
		table.remove(nextList)
	end
	return {
		entries = nextList,
		rank = YarnBoardLogic.rankOf(nextList, incoming.userId),
		improved = true,
	}
end

return YarnBoardLogic
