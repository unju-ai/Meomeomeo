--!strict

local ChampionCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ChampionCatalog"))
local ScoreboardPaint = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ScoreboardPaint"))
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Scoreboard = {}

export type BoardApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (snapshot: Types.MatchSnapshot, localUserId: number) -> (),
}

-- Fixed columns so CS and gold stay readable. Gotham is not monospace.
local COLS = {
	{ name = "Team", width = 48 },
	{ name = "Cat", width = 168 },
	{ name = "Lv", width = 28 },
	{ name = "KDA", width = 76 },
	{ name = "CS", width = 48 },
	{ name = "Gold", width = 64 },
	{ name = "Items", width = 228 },
}

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function champBase(matchPlayer: Types.MatchPlayer): string
	if matchPlayer.championId then
		local champ = ChampionCatalog.get(matchPlayer.championId)
		if champ then
			return champ.name
		end
	end
	return matchPlayer.displayName
end

type RowBits = {
	frame: Frame,
	stroke: UIStroke,
	cells: { TextLabel },
	kind: "player" | "section" | "head",
}

local function makeRow(parent: Instance, name: string, order: number, kind: "player" | "section" | "head"): RowBits
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BackgroundColor3 = Theme.panel
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(1, 0, 0, 24)
	frame.LayoutOrder = order
	frame.ZIndex = 22
	frame.Parent = parent
	Theme.corner(frame, if kind == "player" then 8 else 6)
	local stroke = Theme.stroke(frame, Theme.amber, 1, 1)

	local cells = {}
	if kind == "section" then
		local cell = Theme.text(frame, "Section", "", 12, Theme.cream, Theme.fontMono)
		cell.Size = UDim2.new(1, -8, 1, 0)
		cell.Position = UDim2.fromOffset(6, 0)
		cell.TextWrapped = false
		cell.TextTruncate = Enum.TextTruncate.AtEnd
		cell.ZIndex = 23
		table.insert(cells, cell)
	else
		Theme.list(frame, 4, Enum.FillDirection.Horizontal)
		for index, col in COLS do
			local cell = Theme.text(frame, col.name, "", 13, Theme.cream, Theme.fontMono)
			cell.Size = UDim2.fromOffset(col.width, 22)
			cell.LayoutOrder = index
			cell.TextWrapped = false
			cell.TextTruncate = Enum.TextTruncate.AtEnd
			cell.ZIndex = 23
			table.insert(cells, cell)
		end
	end
	return { frame = frame, stroke = stroke, cells = cells, kind = kind }
end

function Scoreboard.create(parent: Instance): BoardApi
	local root = Instance.new("Frame")
	root.Name = "Scoreboard"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.46)
	root.Size = UDim2.fromOffset(780, 400)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.Active = false
	root.ZIndex = 20
	root.Parent = parent
	Theme.corner(root, 16)
	Theme.stroke(root, Theme.amber, 2, 0.2)
	Theme.pad(root, 12)

	local title = Theme.text(root, "Title", "Scoreboard  ·  hold Tab", 18, Theme.amber, Theme.fontTitle)
	title.Size = UDim2.new(1, 0, 0, 22)
	title.ZIndex = 21

	local totals = Theme.text(root, "Totals", "", 13, Theme.cream, Theme.fontMono)
	totals.Position = UDim2.fromOffset(0, 24)
	totals.Size = UDim2.new(1, 0, 0, 18)
	totals.TextWrapped = false
	totals.ZIndex = 21

	local list = Instance.new("ScrollingFrame")
	list.BackgroundColor3 = Theme.panelAlt
	list.Position = UDim2.fromOffset(0, 46)
	list.Size = UDim2.new(1, 0, 1, -46)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Active = false
	list.ScrollingEnabled = true
	list.ZIndex = 21
	list.Parent = root
	Theme.corner(list, 10)
	Theme.pad(list, 8)
	Theme.list(list, 4)

	local head = makeRow(list, "Head", 0, "head")
	for index, col in COLS do
		head.cells[index].Text = col.name
		head.cells[index].TextColor3 = Theme.peach
		head.cells[index].TextSize = 12
	end

	local rows: { RowBits } = {}

	local function rowAt(index: number, kind: "player" | "section"): RowBits
		local existing = rows[index]
		if existing and existing.kind == kind then
			existing.frame.Visible = true
			return existing
		end
		if existing then
			existing.frame:Destroy()
		end
		local bits = makeRow(list, `R{index}`, index, kind)
		rows[index] = bits
		return bits
	end

	local function paintCells(bits: RowBits, paint: ScoreboardPaint.RowPaint, values: { string })
		bits.frame.BackgroundColor3 = rgb(paint.fill)
		bits.frame.BackgroundTransparency = paint.fillAlpha
		bits.stroke.Color = rgb(paint.stroke)
		bits.stroke.Transparency = paint.strokeAlpha
		for index, cell in bits.cells do
			cell.Text = values[index] or ""
			cell.TextColor3 = rgb(paint.text)
			cell.TextTransparency = paint.textAlpha
			cell.Visible = true
		end
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
		end,
		update = function(snapshot: Types.MatchSnapshot, localUserId: number)
			local now = workspace:GetServerTimeNow()
			local ordered: { Types.MatchPlayer } = {}
			for _, matchPlayer in snapshot.players do
				table.insert(ordered, matchPlayer)
			end
			table.sort(ordered, function(a, b)
				if a.team ~= b.team then
					return a.team < b.team
				end
				return a.gold > b.gold
			end)

			local leadBits: { ScoreboardPaint.LeadPlayer } = {}
			local blueK, redK, blueG, redG, blueCs, redCs = 0, 0, 0, 0, 0, 0
			for _, matchPlayer in ordered do
				table.insert(leadBits, {
					userId = matchPlayer.userId,
					kills = matchPlayer.kills,
					damageDealt = matchPlayer.damageDealt,
					gold = matchPlayer.gold,
					respawnAt = matchPlayer.respawnAt,
				})
				if matchPlayer.team == "Blue" then
					blueK += matchPlayer.kills
					blueG += matchPlayer.gold
					blueCs += matchPlayer.cs or 0
				else
					redK += matchPlayer.kills
					redG += matchPlayer.gold
					redCs += matchPlayer.cs or 0
				end
			end
			totals.Text = ScoreboardPaint.totalsLine(blueK, blueCs, blueG, redK, redCs, redG)
			local crownId = ScoreboardPaint.crownUserId(leadBits, now, snapshot.mvpUserId)

			-- Flatten Blue section → Blue rows → Red section → Red rows.
			local slots: { { kind: "section" | "player", player: Types.MatchPlayer? } } = {}
			local lastTeam: string? = nil
			for _, matchPlayer in ordered do
				if matchPlayer.team ~= lastTeam then
					table.insert(slots, { kind = "section", player = matchPlayer })
					lastTeam = matchPlayer.team
				end
				table.insert(slots, { kind = "player", player = matchPlayer })
			end

			for i, slot in slots do
				local matchPlayer = slot.player :: Types.MatchPlayer
				if slot.kind == "section" then
					local bits = rowAt(i, "section")
					local teamColor = rgb(ScoreboardPaint.teamRgb(matchPlayer.team))
					bits.frame.BackgroundColor3 = teamColor
					bits.frame.BackgroundTransparency = 0.82
					bits.stroke.Color = teamColor
					bits.stroke.Transparency = 0.35
					local cell = bits.cells[1]
					cell.Text = ScoreboardPaint.sectionTitle(matchPlayer.team)
					cell.TextColor3 = teamColor
					cell.TextTransparency = 0
				else
					local bits = rowAt(i, "player")
					local isYou = matchPlayer.userId == localUserId
					local isDead = ScoreboardPaint.isDead(matchPlayer.respawnAt, now)
					local isCrown = crownId == matchPlayer.userId
					local paint = ScoreboardPaint.rowPaint(matchPlayer.team, isYou, isDead, isCrown)
					local name = ScoreboardPaint.catLabel(champBase(matchPlayer), matchPlayer.isBot, isYou, isCrown)
					local values = {
						matchPlayer.team,
						name,
						tostring(matchPlayer.level or 1),
						`{matchPlayer.kills}/{matchPlayer.deaths}/{matchPlayer.assists}`,
						tostring(matchPlayer.cs or 0),
						`{matchPlayer.gold}g`,
						ScoreboardPaint.itemsLine(matchPlayer.items),
					}
					paintCells(bits, paint, values)
					-- YOU keeps cream text for scan; team tint on Team column only.
					if isYou and not isDead then
						bits.cells[1].TextColor3 = rgb(ScoreboardPaint.teamRgb(matchPlayer.team))
						bits.cells[2].TextColor3 = Theme.amber
					end
				end
			end
			for i = #slots + 1, #rows do
				rows[i].frame.Visible = false
			end
		end,
	}
end

return Scoreboard
