--!strict

-- Cat Rift remake chip + night-market vote panel.
-- F7 and the chip start (or agree). Yes / No cast on the open ballot.
-- Hidden once the match clock hits 3:00, unless a ballot is still open.
-- Hub stalls never show it.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local RemakeLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RemakeLogic"))
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local RemakePanel = {}

export type RemakeApi = {
	chip: TextButton,
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (snapshot: Types.MatchSnapshot, localUserId: number) -> (),
	press: (action: string) -> (),
	note: (snapshot: Types.MatchSnapshot, localUserId: number) -> (),
	onToast: ((text: string) -> ()) -> (),
}

function RemakePanel.create(parent: Instance): RemakeApi
	local toastHandler: ((text: string) -> ())? = nil
	local lastNoticeId = 0

	local function send(action: string)
		task.spawn(function()
			local result = Remotes.function_("RemakeVote"):InvokeServer(action)
			if result and result.ok == false and typeof(result.error) == "string" and toastHandler then
				toastHandler(result.error)
			end
		end)
	end

	-- Sits just left of the Fold chip (Fold's right edge is -128, width 104).
	local chip = Theme.button(parent, "RemakeChip", "F7 Remake", Theme.peach)
	chip.AnchorPoint = Vector2.new(1, 0)
	chip.Position = UDim2.new(1, -238, 0, 96)
	chip.Size = UDim2.fromOffset(118, 40)
	chip.TextSize = 13
	chip.Visible = false
	chip.ZIndex = 30

	local root = Instance.new("Frame")
	root.Name = "RemakePanel"
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.new(1, -238, 0, 142)
	root.Size = UDim2.fromOffset(232, 138)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.ZIndex = 34
	root.Parent = parent
	Theme.corner(root, 14)
	Theme.stroke(root, Theme.peach, 2, 0.2)
	Theme.pad(root, 10)

	local title = Theme.text(root, "Title", "CALL IT EARLY", 16, Theme.peach, Theme.fontTitle)
	title.Size = UDim2.new(1, 0, 0, 20)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 35

	local counts = Theme.text(root, "Counts", "", 14, Theme.cream, Theme.fontMono)
	counts.Position = UDim2.fromOffset(0, 24)
	counts.Size = UDim2.new(1, 0, 0, 18)
	counts.TextXAlignment = Enum.TextXAlignment.Center
	counts.TextWrapped = false
	counts.ZIndex = 35

	local timer = Theme.text(root, "Timer", "", 13, Theme.amber, Theme.fontMono)
	timer.Position = UDim2.fromOffset(0, 44)
	timer.Size = UDim2.new(1, 0, 0, 16)
	timer.TextXAlignment = Enum.TextXAlignment.Center
	timer.ZIndex = 35

	local yes = Theme.button(root, "Yes", "Yes", Theme.mint)
	yes.Position = UDim2.fromOffset(0, 66)
	yes.Size = UDim2.fromOffset(102, 32)
	yes.TextSize = 16
	yes.ZIndex = 35

	local no = Theme.button(root, "No", "No", Theme.coral)
	no.Position = UDim2.fromOffset(110, 66)
	no.Size = UDim2.fromOffset(102, 32)
	no.TextSize = 16
	no.ZIndex = 35

	local cast = Theme.text(root, "Cast", "", 13, Theme.cream, Theme.fontBody)
	cast.Position = UDim2.fromOffset(0, 66)
	cast.Size = UDim2.new(1, 0, 0, 32)
	cast.TextXAlignment = Enum.TextXAlignment.Center
	cast.Visible = false
	cast.ZIndex = 35

	local hint = Theme.text(root, "Hint", "Living humans · bots sit out", 11, Theme.peach, Theme.fontBody)
	hint.Position = UDim2.fromOffset(0, 102)
	hint.Size = UDim2.new(1, 0, 0, 14)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.ZIndex = 35

	local inFight = false
	local startedAt: number? = nil
	local endsAt: number? = nil
	local voteOpen = false
	local mySide: string? = nil
	local paintedChip = ""
	local paintedLeft = -1

	local function paintChip()
		if not inFight then
			return
		end
		local elapsed = RemakeLogic.elapsed(Workspace:GetServerTimeNow(), startedAt)
		local window = RemakeLogic.open(elapsed)
		local show = voteOpen or window
		chip.Visible = show
		if not show then
			root.Visible = false
			paintedChip = ""
			return
		end
		local mode = if voteOpen then "open" else "ready"
		if mode == paintedChip then
			return
		end
		paintedChip = mode
		if mode == "open" then
			chip.Text = "Voting"
			chip.BackgroundColor3 = Theme.coral
			chip.TextColor3 = Theme.foam
		else
			chip.Text = "F7 Remake"
			chip.BackgroundColor3 = Theme.peach
			chip.TextColor3 = Theme.ink
		end
	end

	local function paintTimer()
		if not root.Visible or endsAt == nil then
			return
		end
		local left = math.max(0, math.ceil((endsAt :: number) - Workspace:GetServerTimeNow() - 1e-6))
		if left == paintedLeft then
			return
		end
		paintedLeft = left
		timer.Text = `{left}s left`
	end

	RunService.Heartbeat:Connect(function()
		paintChip()
		paintTimer()
	end)

	chip.MouseButton1Click:Connect(function()
		if voteOpen then
			if mySide == nil then
				send("yes")
			end
			return
		end
		send("start")
	end)
	yes.MouseButton1Click:Connect(function()
		send("yes")
	end)
	no.MouseButton1Click:Connect(function()
		send("no")
	end)

	local function seatsOf(players: { [string]: Types.MatchPlayer }): { RemakeLogic.Seat }
		local seats: { RemakeLogic.Seat } = {}
		for _, matchPlayer in players do
			table.insert(seats, RemakeLogic.seat(
				matchPlayer.userId,
				matchPlayer.team,
				matchPlayer.isBot,
				matchPlayer.respawnAt,
				matchPlayer.connected
			))
		end
		return seats
	end

	return {
		chip = chip,
		root = root,
		setVisible = function(visible: boolean)
			if not visible then
				inFight = false
				chip.Visible = false
				root.Visible = false
				voteOpen = false
				paintedChip = ""
			end
		end,
		update = function(snapshot: Types.MatchSnapshot, localUserId: number)
			local mine = snapshot.players[tostring(localUserId)]
			local show = snapshot.phase == "InProgress" and mine ~= nil and mine.isBot ~= true
			inFight = show
			if not show or not mine then
				chip.Visible = false
				root.Visible = false
				voteOpen = false
				startedAt = nil
				endsAt = nil
				paintedChip = ""
				return
			end
			startedAt = snapshot.startedAt
			local ballots = if snapshot.remake then snapshot.remake.ballots else nil
			local ballot = RemakeLogic.ballotForTeam(ballots, mine.team)
			voteOpen = ballot ~= nil
			mySide = if ballot then RemakeLogic.mySide(ballot, localUserId) else nil
			root.Visible = ballot ~= nil
			if not ballot then
				endsAt = nil
				paintedLeft = -1
				paintChip()
				return
			end
			endsAt = ballot.endsAt
			local result = RemakeLogic.tally(seatsOf(snapshot.players), ballot)
			counts.Text = RemakeLogic.countLine(result.yes, result.no, result.needed)
			local side = mySide
			local voted = side == "yes" or side == "no"
			yes.Visible = not voted
			no.Visible = not voted
			cast.Visible = voted
			if side == "yes" then
				cast.Text = "You voted Yes"
			elseif side == "no" then
				cast.Text = "You voted No"
			end
			paintedChip = ""
			paintedLeft = -1
			paintChip()
			paintTimer()
		end,
		press = function(action: string)
			send(action)
		end,
		note = function(snapshot: Types.MatchSnapshot, localUserId: number)
			local view = snapshot.remake
			if not view then
				return
			end
			local id = view.noticeId
			if typeof(id) ~= "number" or id == lastNoticeId then
				return
			end
			lastNoticeId = id
			local mine = snapshot.players[tostring(localUserId)]
			if not mine or mine.team ~= view.noticeTeam then
				return
			end
			if typeof(view.notice) == "string" and view.notice ~= "" and toastHandler then
				toastHandler(view.notice)
			end
		end,
		onToast = function(fn: (text: string) -> ())
			toastHandler = fn
		end,
	}
end

return RemakePanel
