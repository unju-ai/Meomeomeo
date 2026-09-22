--!strict

-- Local Cat Rift AFK toast + teammate kill-feed whisper.
-- The server owns the stamp. This only paints, and only in a live fight.

local AfkLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("AfkLogic"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local AfkWatch = {}

local matchId = ""
local noticeId = 0
local whispers: { [string]: number } = {}

function AfkWatch.note(
	snapshot: Types.MatchSnapshot,
	localUserId: number,
	mode: string,
	mini: boolean,
	toast: (string) -> (),
	pushFeed: (Types.FeedEvent) -> ()
)
	if snapshot.id ~= matchId then
		matchId = snapshot.id
		noticeId = 0
		table.clear(whispers)
	end
	if not AfkLogic.wantsLocalToast(mode, snapshot.phase, mini) then
		return
	end
	local mine = snapshot.players[tostring(localUserId)]
	if not mine then
		return
	end
	local id = mine.afkNoticeId
	if typeof(id) == "number" and id ~= noticeId then
		noticeId = id
		if typeof(mine.afkNotice) == "string" and mine.afkNotice ~= "" then
			toast(mine.afkNotice)
		end
	end
	for key, other in snapshot.players do
		local whisperId = other.afkWhisperId
		if typeof(whisperId) ~= "number" or whispers[key] == whisperId then
			continue
		end
		whispers[key] = whisperId
		if AfkLogic.wantsWhisper(other.team == mine.team, other.userId == localUserId, other.isBot == true, other.afk == true) then
			pushFeed({
				kind = "announce",
				text = AfkLogic.whisper(other.displayName),
				at = os.clock(),
			})
		end
	end
end

return AfkWatch
