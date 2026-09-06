--!strict

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local EndScreen = {}

export type EndApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (snapshot: Types.MatchSnapshot, localUserId: number) -> (),
	onLobby: (() -> ()) -> (),
	onPractice: (() -> ()) -> (),
}

local function champName(matchPlayer: Types.MatchPlayer): string
	if matchPlayer.championId then
		local champ = ChampionCatalog.get(matchPlayer.championId)
		if champ then
			return champ.name
		end
	end
	return matchPlayer.displayName
end

function EndScreen.create(parent: Instance): EndApi
	local root = Instance.new("Frame")
	root.Name = "EndScreen"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.48)
	root.Size = UDim2.fromOffset(640, 460)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.ZIndex = 30
	root.Parent = parent
	Theme.corner(root, 20)
	Theme.stroke(root, Theme.amber, 3, 0.18)
	Theme.pad(root, 18)

	local banner = Theme.text(root, "Banner", "VICTORY", 36, Theme.amber, Theme.fontTitle)
	banner.Size = UDim2.new(1, 0, 0, 40)
	banner.TextXAlignment = Enum.TextXAlignment.Center
	banner.ZIndex = 31

	local sub = Theme.text(root, "Sub", "", 16, Theme.cream, Theme.fontBody)
	sub.Position = UDim2.fromOffset(0, 42)
	sub.Size = UDim2.new(1, 0, 0, 22)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.ZIndex = 31

	local mvp = Theme.text(root, "Mvp", "", 14, Theme.peach, Theme.fontBody)
	mvp.Position = UDim2.fromOffset(0, 68)
	mvp.Size = UDim2.new(1, 0, 0, 22)
	mvp.TextXAlignment = Enum.TextXAlignment.Center
	mvp.ZIndex = 31

	local totals = Theme.text(root, "Totals", "", 13, Theme.cream, Theme.fontMono)
	totals.Position = UDim2.fromOffset(0, 94)
	totals.Size = UDim2.new(1, 0, 0, 18)
	totals.ZIndex = 31

	local header = Theme.text(root, "Head", "Team   Cat                    K / D / A   CS    Gold   Dmg", 12, Theme.peach, Theme.fontMono)
	header.Position = UDim2.fromOffset(0, 116)
	header.Size = UDim2.new(1, 0, 0, 16)
	header.ZIndex = 31

	local list = Instance.new("ScrollingFrame")
	list.BackgroundColor3 = Theme.panelAlt
	list.Position = UDim2.fromOffset(0, 136)
	list.Size = UDim2.new(1, 0, 1, -196)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.ZIndex = 31
	list.Parent = root
	Theme.corner(list, 10)
	Theme.pad(list, 8)
	Theme.list(list, 4)

	local rows: { TextLabel } = {}

	local function rowAt(index: number): TextLabel
		local existing = rows[index]
		if existing then
			return existing
		end
		local row = Theme.text(list, `R{index}`, "", 13, Theme.cream, Theme.fontMono)
		row.Size = UDim2.new(1, -8, 0, 22)
		row.LayoutOrder = index
		row.ZIndex = 32
		rows[index] = row
		return row
	end

	local timer = Theme.text(root, "Timer", "", 13, Theme.muted, Theme.fontBody)
	timer.AnchorPoint = Vector2.new(0.5, 1)
	timer.Position = UDim2.new(0.5, 0, 1, -92)
	timer.Size = UDim2.new(1, 0, 0, 18)
	timer.TextXAlignment = Enum.TextXAlignment.Center
	timer.ZIndex = 31

	local lobbyBtn = Theme.button(root, "Lobby", "Back to lobby", Theme.peach)
	lobbyBtn.AnchorPoint = Vector2.new(0, 1)
	lobbyBtn.Position = UDim2.new(0, 0, 1, 0)
	lobbyBtn.Size = UDim2.new(0.48, 0, 0, 44)
	lobbyBtn.ZIndex = 31

	local practiceBtn = Theme.button(root, "Again", "Practice again", Theme.mint)
	practiceBtn.AnchorPoint = Vector2.new(1, 1)
	practiceBtn.Position = UDim2.new(1, 0, 1, 0)
	practiceBtn.Size = UDim2.new(0.48, 0, 0, 44)
	practiceBtn.ZIndex = 31

	local lobbyHandler: (() -> ())? = nil
	local practiceHandler: (() -> ())? = nil

	lobbyBtn.MouseButton1Click:Connect(function()
		if lobbyHandler then
			lobbyHandler()
		end
	end)
	practiceBtn.MouseButton1Click:Connect(function()
		if practiceHandler then
			practiceHandler()
		end
	end)

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
		end,
		update = function(snapshot: Types.MatchSnapshot, localUserId: number)
			local mine = snapshot.players[tostring(localUserId)]
			local winner = snapshot.winner
			if mine and winner then
				if mine.team == winner then
					banner.Text = "VICTORY"
					banner.TextColor3 = Theme.good
					sub.Text = `{winner} takes the yarn`
				else
					banner.Text = "DEFEAT"
					banner.TextColor3 = Theme.coral
					sub.Text = `{winner} scratched your nexus`
				end
			else
				banner.Text = `{winner or "??"} WINS`
				banner.TextColor3 = Theme.amber
				sub.Text = "Nexus down — match over"
			end

			local mvpPlayer: Types.MatchPlayer? = nil
			if snapshot.mvpUserId then
				mvpPlayer = snapshot.players[tostring(snapshot.mvpUserId)]
			end
			if mvpPlayer then
				mvp.Text = `MVP · {champName(mvpPlayer)} · {mvpPlayer.kills}/{mvpPlayer.deaths}/{mvpPlayer.assists} · {math.floor(mvpPlayer.damageDealt or 0)} dmg`
			else
				mvp.Text = "MVP · nobody clawed hard enough"
			end

			local ordered: { Types.MatchPlayer } = {}
			for _, matchPlayer in snapshot.players do
				table.insert(ordered, matchPlayer)
			end
			table.sort(ordered, function(a, b)
				if a.team ~= b.team then
					return a.team < b.team
				end
				return a.kills > b.kills
			end)

			local blueK, redK, blueD, redD, blueA, redA = 0, 0, 0, 0, 0, 0
			for _, matchPlayer in ordered do
				if matchPlayer.team == "Blue" then
					blueK += matchPlayer.kills
					blueD += matchPlayer.deaths
					blueA += matchPlayer.assists
				else
					redK += matchPlayer.kills
					redD += matchPlayer.deaths
					redA += matchPlayer.assists
				end
			end
			totals.Text = `Blue  {blueK}/{blueD}/{blueA}     Red  {redK}/{redD}/{redA}`

			for i, matchPlayer in ordered do
				local row = rowAt(i)
				row.Visible = true
				local you = if matchPlayer.userId == localUserId then " *" else ""
				local star = if snapshot.mvpUserId == matchPlayer.userId then "★ " else "  "
				row.TextColor3 = if matchPlayer.team == "Blue" then Theme.blue else Theme.red
				row.Text = string.format(
					"%s%-5s  %-20s  %d / %d / %d   %3d   %4dg   %d%s",
					star,
					matchPlayer.team,
					string.sub(champName(matchPlayer), 1, 20),
					matchPlayer.kills,
					matchPlayer.deaths,
					matchPlayer.assists,
					matchPlayer.cs or 0,
					matchPlayer.gold,
					math.floor(matchPlayer.damageDealt or 0),
					you
				)
			end
			for i = #ordered + 1, #rows do
				rows[i].Visible = false
			end

			if snapshot.phaseEndsAt then
				local left = math.max(0, math.floor(snapshot.phaseEndsAt - workspace:GetServerTimeNow()))
				timer.Text = `Returning to lobby in {left}s`
			else
				timer.Text = ""
			end
		end,
		onLobby = function(fn)
			lobbyHandler = fn
		end,
		onPractice = function(fn)
			practiceHandler = fn
		end,
	}
end

return EndScreen
