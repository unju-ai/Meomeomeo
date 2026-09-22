--!strict

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local EndScreenCopy = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("EndScreenCopy"))
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local ScreenJuice = require(script.Parent.Parent.Juice.ScreenJuice)

local EndScreen = {}

export type EndApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (snapshot: Types.MatchSnapshot, localUserId: number) -> (),
	onLobby: (() -> ()) -> (),
	onPractice: (() -> ()) -> (),
	onHub: (() -> ()) -> (),
}

local function champName(matchPlayer: Types.MatchPlayer): string
	local name = matchPlayer.displayName
	if matchPlayer.championId then
		local champ = ChampionCatalog.get(matchPlayer.championId)
		if champ then
			name = champ.name
		end
	end
	if matchPlayer.isBot and not string.find(name, "%(Bot%)") then
		name = `{name} (Bot)`
	end
	return name
end

local function toneColor(tone: EndScreenCopy.OutcomeTone): Color3
	if tone == "win" then
		return Theme.mint
	elseif tone == "loss" then
		return Theme.coral
	end
	return Theme.amber
end

local function toneAccent(tone: EndScreenCopy.OutcomeTone): Color3
	if tone == "win" then
		return Theme.amber
	elseif tone == "loss" then
		return Theme.coral
	end
	return Theme.peach
end

function EndScreen.create(parent: Instance): EndApi
	local root = Instance.new("Frame")
	root.Name = "EndScreen"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.48)
	root.Size = UDim2.fromOffset(720, 580)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.ZIndex = 30
	root.Parent = parent
	Theme.corner(root, 20)
	local rootStroke = Theme.stroke(root, Theme.amber, 3, 0.18)
	Theme.pad(root, 18)

	local bannerPlate = Instance.new("Frame")
	bannerPlate.Name = "BannerPlate"
	bannerPlate.Size = UDim2.new(1, 0, 0, 72)
	bannerPlate.BackgroundColor3 = Theme.mint
	bannerPlate.BackgroundTransparency = 0.72
	bannerPlate.BorderSizePixel = 0
	bannerPlate.ZIndex = 31
	bannerPlate.Parent = root
	Theme.corner(bannerPlate, 14)
	local bannerStroke = Theme.stroke(bannerPlate, Theme.amber, 2, 0.35)

	local banner = Theme.text(bannerPlate, "Banner", "VICTORY", 42, Theme.mint, Theme.fontTitle)
	banner.Size = UDim2.new(1, 0, 0, 44)
	banner.Position = UDim2.fromOffset(0, 4)
	banner.TextXAlignment = Enum.TextXAlignment.Center
	banner.TextStrokeTransparency = 0.35
	banner.TextStrokeColor3 = Theme.ink
	banner.ZIndex = 32

	local sub = Theme.text(bannerPlate, "Sub", "", 15, Theme.cream, Theme.fontBody)
	sub.Position = UDim2.fromOffset(0, 44)
	sub.Size = UDim2.new(1, 0, 0, 22)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.ZIndex = 32

	local mvpChip = Instance.new("Frame")
	mvpChip.Name = "MvpChip"
	mvpChip.Position = UDim2.fromOffset(0, 82)
	mvpChip.Size = UDim2.new(1, 0, 0, 28)
	mvpChip.BackgroundColor3 = Theme.amber
	mvpChip.BackgroundTransparency = 0.78
	mvpChip.BorderSizePixel = 0
	mvpChip.ZIndex = 31
	mvpChip.Parent = root
	Theme.corner(mvpChip, 10)
	Theme.stroke(mvpChip, Theme.amber, 1, 0.45)

	local mvpCrown = Theme.text(mvpChip, "Crown", "CROWN", 12, Theme.ink, Theme.fontTitle)
	mvpCrown.Size = UDim2.fromOffset(58, 22)
	mvpCrown.Position = UDim2.fromOffset(4, 3)
	mvpCrown.BackgroundColor3 = Theme.amber
	mvpCrown.BackgroundTransparency = 0.08
	mvpCrown.TextXAlignment = Enum.TextXAlignment.Center
	mvpCrown.ZIndex = 32
	Theme.corner(mvpCrown, 8)

	local mvp = Theme.text(mvpChip, "Mvp", "", 14, Theme.cream, Theme.fontBody)
	mvp.Position = UDim2.fromOffset(68, 0)
	mvp.Size = UDim2.new(1, -72, 1, 0)
	mvp.TextXAlignment = Enum.TextXAlignment.Left
	mvp.ZIndex = 32

	local structures = Theme.text(root, "Structures", "", 13, Theme.cream, Theme.fontMono)
	structures.Position = UDim2.fromOffset(0, 116)
	structures.Size = UDim2.new(1, 0, 0, 20)
	structures.TextXAlignment = Enum.TextXAlignment.Center
	structures.ZIndex = 31

	local timeline = Theme.text(root, "Timeline", "", 13, Theme.peach, Theme.fontMono)
	timeline.Position = UDim2.fromOffset(0, 138)
	timeline.Size = UDim2.new(1, 0, 0, 56)
	timeline.TextXAlignment = Enum.TextXAlignment.Left
	timeline.TextYAlignment = Enum.TextYAlignment.Top
	timeline.ZIndex = 31

	local totals = Theme.text(root, "Totals", "", 13, Theme.cream, Theme.fontMono)
	totals.Position = UDim2.fromOffset(0, 198)
	totals.Size = UDim2.new(1, 0, 0, 18)
	totals.ZIndex = 31

	local header = Theme.text(root, "Head", "     Team   Cat                    K / D / A   CS    Gold   Dmg", 12, Theme.peach, Theme.fontMono)
	header.Position = UDim2.fromOffset(0, 218)
	header.Size = UDim2.new(1, 0, 0, 16)
	header.ZIndex = 31

	local list = Instance.new("ScrollingFrame")
	list.BackgroundColor3 = Theme.panelAlt
	list.Position = UDim2.fromOffset(0, 238)
	list.Size = UDim2.new(1, 0, 1, -312)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.ZIndex = 31
	list.Parent = root
	Theme.corner(list, 10)
	Theme.pad(list, 8)
	Theme.list(list, 4)

	type RowBits = {
		frame: Frame,
		label: TextLabel,
		stroke: UIStroke,
	}
	local rows: { RowBits } = {}

	local function rowAt(index: number): RowBits
		local existing = rows[index]
		if existing then
			return existing
		end
		local frame = Instance.new("Frame")
		frame.Name = `R{index}`
		frame.Size = UDim2.new(1, -8, 0, 26)
		frame.BackgroundColor3 = Theme.panel
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.LayoutOrder = index
		frame.ZIndex = 32
		frame.Parent = list
		Theme.corner(frame, 8)
		local stroke = Theme.stroke(frame, Theme.amber, 1, 1)
		local label = Theme.text(frame, "Line", "", 13, Theme.cream, Theme.fontMono)
		label.Size = UDim2.new(1, -8, 1, 0)
		label.Position = UDim2.fromOffset(4, 0)
		label.ZIndex = 33
		local bits = { frame = frame, label = label, stroke = stroke }
		rows[index] = bits
		return bits
	end

	local timer = Theme.text(root, "Timer", "", 13, Theme.muted, Theme.fontBody)
	timer.AnchorPoint = Vector2.new(0.5, 1)
	timer.Position = UDim2.new(0.5, 0, 1, -58)
	timer.Size = UDim2.new(1, 0, 0, 18)
	timer.TextXAlignment = Enum.TextXAlignment.Center
	timer.ZIndex = 31

	local practiceBtn = Theme.button(root, "Again", "Practice again", Theme.mint)
	practiceBtn.AnchorPoint = Vector2.new(0, 1)
	practiceBtn.Position = UDim2.fromScale(0, 1)
	practiceBtn.Size = UDim2.new(0.32, -4, 0, 44)
	practiceBtn.ZIndex = 31
	Theme.stroke(practiceBtn, Theme.foam, 2, 0.25)

	local lobbyBtn = Theme.button(root, "Lobby", "Back to lobby", Theme.peach)
	lobbyBtn.AnchorPoint = Vector2.new(0.5, 1)
	lobbyBtn.Position = UDim2.fromScale(0.5, 1)
	lobbyBtn.Size = UDim2.new(0.32, -4, 0, 44)
	lobbyBtn.ZIndex = 31

	local hubBtn = Theme.button(root, "Hub", "Hub", Theme.amber)
	hubBtn.AnchorPoint = Vector2.new(1, 1)
	hubBtn.Position = UDim2.fromScale(1, 1)
	hubBtn.Size = UDim2.new(0.32, -4, 0, 44)
	hubBtn.ZIndex = 31
	Theme.stroke(hubBtn, Theme.foam, 2, 0.3)

	local lobbyHandler: (() -> ())? = nil
	local practiceHandler: (() -> ())? = nil
	local hubHandler: (() -> ())? = nil
	local stungKey: string? = nil

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
	hubBtn.MouseButton1Click:Connect(function()
		if hubHandler then
			hubHandler()
		end
	end)

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if not visible then
				stungKey = nil
			end
		end,
		update = function(snapshot: Types.MatchSnapshot, localUserId: number)
			local mine = snapshot.players[tostring(localUserId)]
			local winner = snapshot.winner
			local won: boolean? = nil
			if mine and winner then
				won = mine.team == winner
			end
			local tone = EndScreenCopy.outcomeTone(won)
			local accent = toneAccent(tone)
			local color = toneColor(tone)
			banner.Text = EndScreenCopy.outcomeTitle(won)
			banner.TextColor3 = if tone == "win" then Theme.cream else color
			sub.Text = EndScreenCopy.subLine(won, winner)
			bannerPlate.BackgroundColor3 = color
			bannerPlate.BackgroundTransparency = if tone == "win" then 0.55 else 0.62
			bannerStroke.Color = accent
			bannerStroke.Transparency = 0.2
			rootStroke.Color = accent
			rootStroke.Transparency = 0.12

			local stingId = `{snapshot.id}:{winner or "?"}:{if won == true then "W" elseif won == false then "L" else "N"}`
			if root.Visible and stungKey ~= stingId then
				stungKey = stingId
				ScreenJuice.matchEnd(won == true)
			end

			local function structureTally(team: Types.TeamId): string
				local posts, stalls, postN, stallN = 0, 0, 0, 0
				local core = "up"
				for _, objective in snapshot.objectives do
					if objective.team ~= team then
						continue
					end
					if objective.kind == "Nexus" then
						if not objective.alive then
							core = "down"
						elseif objective.vulnerable then
							core = "OPEN"
						else
							core = "gated"
						end
					elseif objective.tier == "Inner" then
						stallN += 1
						if not objective.alive then
							stalls += 1
						end
					else
						postN += 1
						if not objective.alive then
							posts += 1
						end
					end
				end
				return `{team} posts {posts}/{postN}  stalls {stalls}/{stallN}  core {core}`
			end
			structures.Text = `{structureTally("Blue")}    {structureTally("Red")}`

			local epic = snapshot.riverEpic
			local levi = if epic then EndScreenCopy.leviLine(epic.blueBuff, epic.redBuff) else nil
			local falls: { EndScreenCopy.FallBit } = {}
			for _, fall in snapshot.structureFalls or {} do
				table.insert(falls, {
					team = fall.team,
					tier = fall.tier,
					lane = fall.lane,
				})
			end
			timeline.Text = EndScreenCopy.timelineLines(falls, levi)

			local mvpPlayer: Types.MatchPlayer? = nil
			if snapshot.mvpUserId then
				mvpPlayer = snapshot.players[tostring(snapshot.mvpUserId)]
			end
			if mvpPlayer then
				mvp.Text = EndScreenCopy.mvpLine(
					champName(mvpPlayer),
					mvpPlayer.kills,
					mvpPlayer.deaths,
					mvpPlayer.assists,
					mvpPlayer.damageDealt
				)
				mvpCrown.Visible = true
				mvpChip.BackgroundTransparency = 0.55
			else
				mvp.Text = EndScreenCopy.mvpLine(nil)
				mvpCrown.Visible = false
				mvpChip.BackgroundTransparency = 0.82
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
				local bits = rowAt(i)
				bits.frame.Visible = true
				local isYou = matchPlayer.userId == localUserId
				local isMvp = snapshot.mvpUserId == matchPlayer.userId
				local mark = EndScreenCopy.rowMark(isYou, isMvp)
				bits.label.TextColor3 = if matchPlayer.team == "Blue" then Theme.blue else Theme.red
				bits.label.Text = string.format(
					"%s %-5s  %-18s  %d / %d / %d   %3d   %4dg   %d",
					mark,
					matchPlayer.team,
					string.sub(champName(matchPlayer), 1, 18),
					matchPlayer.kills,
					matchPlayer.deaths,
					matchPlayer.assists,
					matchPlayer.cs or 0,
					matchPlayer.gold,
					math.floor(matchPlayer.damageDealt or 0)
				)
				if isYou then
					bits.frame.BackgroundColor3 = Theme.amber
					bits.frame.BackgroundTransparency = 0.72
					bits.stroke.Color = Theme.amber
					bits.stroke.Transparency = 0.25
				elseif isMvp then
					bits.frame.BackgroundColor3 = Theme.peach
					bits.frame.BackgroundTransparency = 0.78
					bits.stroke.Color = Theme.amber
					bits.stroke.Transparency = 0.45
				else
					bits.frame.BackgroundTransparency = 1
					bits.stroke.Transparency = 1
				end
			end
			for i = #ordered + 1, #rows do
				rows[i].frame.Visible = false
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
		onHub = function(fn)
			hubHandler = fn
		end,
	}
end

return EndScreen
