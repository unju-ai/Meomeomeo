--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CampRespawnJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CampRespawnJuice"))
local WaveJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WaveJuice"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local MinimapPaint = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("MinimapPaint"))
local WardJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WardJuice"))
local RiverEpic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RiverEpic"))
local PingCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PingCatalog"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local VisionLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("VisionLogic"))
local CampRespawnFx = require(script.Parent.Parent.Juice.CampRespawnFx)
local WaveFx = require(script.Parent.Parent.Juice.WaveFx)
local Theme = require(script.Parent.Parent.Theme)

local Minimap = {}

export type MinimapApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (snapshot: Types.MatchSnapshot, vision: Types.VisionFrame, localUserId: number) -> (),
	showPing: (payload: Types.PingPayload) -> (),
	onPing: ((position: Vector3) -> ()) -> (),
	contains: (screenX: number, screenY: number) -> boolean,
}

local function worldToScale(position: Vector3): (number, number)
	local bounds = Constants.MapBounds
	local x = (position.X - bounds.MinX) / (bounds.MaxX - bounds.MinX)
	local z = (position.Z - bounds.MinZ) / (bounds.MaxZ - bounds.MinZ)
	return math.clamp(x, 0, 1), math.clamp(z, 0, 1)
end

local function scaleToWorld(x: number, z: number): Vector3
	local bounds = Constants.MapBounds
	return Vector3.new(
		bounds.MinX + math.clamp(x, 0, 1) * (bounds.MaxX - bounds.MinX),
		4,
		bounds.MinZ + math.clamp(z, 0, 1) * (bounds.MaxZ - bounds.MinZ)
	)
end

local function mark(parent: Instance, name: string, size: number, color: Color3): Frame
	local dot = Instance.new("Frame")
	dot.Name = name
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(size, size)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.ZIndex = 3
	dot.Parent = parent
	Theme.corner(dot, 99)
	return dot
end

local function applyPaint(frame: Frame, paint: MinimapPaint.Paint)
	frame.BackgroundColor3 = MinimapPaint.rgb(paint.fill)
	frame.BackgroundTransparency = paint.transparency
	frame.Size = UDim2.fromOffset(paint.size, paint.size)
	local cornerInst = frame:FindFirstChildOfClass("UICorner")
	local corner = if cornerInst and cornerInst:IsA("UICorner") then cornerInst else Theme.corner(frame, paint.corner)
	corner.CornerRadius = UDim.new(0, paint.corner)
	local strokeInst = frame:FindFirstChildOfClass("UIStroke")
	local stroke = if strokeInst and strokeInst:IsA("UIStroke")
		then strokeInst
		else Theme.stroke(frame, Theme.cream, 1, 0.1)
	stroke.Color = MinimapPaint.rgb(paint.stroke)
	stroke.Thickness = paint.strokeThickness
	stroke.Transparency = if paint.strokeThickness <= 0 then 1 else math.clamp(paint.transparency * 0.5, 0, 0.6)
	stroke.Enabled = paint.strokeThickness > 0
end

function Minimap.create(parent: Instance): MinimapApi
	local root = Instance.new("TextButton")
	root.Name = "Minimap"
	root.AutoButtonColor = false
	root.Text = ""
	root.AnchorPoint = Vector2.new(1, 1)
	root.Position = UDim2.new(1, -16, 1, -16)
	root.Size = UDim2.fromOffset(200, 136)
	root.BackgroundColor3 = Color3.fromRGB(48, 64, 46)
	root.Visible = false
	root.Parent = parent
	Theme.corner(root, 12)
	local rootStroke = Theme.stroke(root, Theme.amber, 2, 0.25)

	local river = Instance.new("Frame")
	river.Name = "River"
	river.AnchorPoint = Vector2.new(0.5, 0)
	river.Position = UDim2.fromScale(0.5, 0)
	river.Size = UDim2.fromScale(0.07, 1)
	river.BackgroundColor3 = Color3.fromRGB(48, 92, 148)
	river.BackgroundTransparency = 0.12
	river.BorderSizePixel = 0
	river.ZIndex = 1
	river.Parent = root

	for index, z in { -80, 0, 80 } do
		local sx, sy = worldToScale(Vector3.new(0, 0, z))
		local lane = Instance.new("Frame")
		lane.Name = `Lane{index}`
		lane.AnchorPoint = Vector2.new(0, 0.5)
		lane.Position = UDim2.fromScale(0.04, sy)
		lane.Size = UDim2.fromScale(0.92, 0.03)
		lane.BackgroundColor3 = Color3.fromRGB(214, 176, 110)
		lane.BackgroundTransparency = 0.08
		lane.BorderSizePixel = 0
		lane.ZIndex = 1
		lane.Parent = root
	end

	for _, pocket in {
		{ name = "JungleNW", pos = Vector3.new(-70, 0, -90), w = 0.2, h = 0.16 },
		{ name = "JungleSE", pos = Vector3.new(70, 0, 90), w = 0.2, h = 0.16 },
	} do
		local sx, sy = worldToScale(pocket.pos)
		local patch = Instance.new("Frame")
		patch.Name = pocket.name
		patch.AnchorPoint = Vector2.new(0.5, 0.5)
		patch.Position = UDim2.fromScale(sx, sy)
		patch.Size = UDim2.fromScale(pocket.w, pocket.h)
		patch.BackgroundColor3 = Color3.fromRGB(36, 58, 40)
		patch.BackgroundTransparency = 0.15
		patch.BorderSizePixel = 0
		patch.ZIndex = 1
		patch.Parent = root
		Theme.corner(patch, 6)
	end

	local title = Theme.text(root, "Title", "Rift  ·  fog  ·  click ping", 11, Theme.cream, Theme.fontMono)
	title.Position = UDim2.fromOffset(8, 4)
	title.Size = UDim2.new(1, -16, 0, 14)
	title.ZIndex = 4

	local fogFolder = Instance.new("Folder")
	fogFolder.Name = "Fog"
	fogFolder.Parent = root
	local fogCells: { Frame } = {}
	local explored = table.create(VisionLogic.CellCount, false)
	local fogBuilt = false

	local function buildFog()
		if fogBuilt then
			return
		end
		local w = 1 / VisionLogic.Cols
		local h = 1 / VisionLogic.Rows
		for index = 1, VisionLogic.CellCount do
			local i = index - 1
			local col = i % VisionLogic.Cols
			local row = math.floor(i / VisionLogic.Cols)
			local cell = Instance.new("Frame")
			cell.Name = `f{index}`
			cell.BorderSizePixel = 0
			cell.BackgroundColor3 = MinimapPaint.rgb(MinimapPaint.FogUnexplored)
			cell.BackgroundTransparency = MinimapPaint.FogUnexploredAlpha
			cell.Position = UDim2.fromScale(col * w, row * h)
			cell.Size = UDim2.fromScale(w + 0.002, h + 0.002)
			cell.ZIndex = 2
			cell.Visible = false
			cell.Parent = fogFolder
			fogCells[index] = cell
		end
		fogBuilt = true
	end

	local function paintFog(vision: Types.VisionFrame)
		local bits = vision.fogBits
		if typeof(bits) ~= "table" or #bits < 1 then
			for _, cell in fogCells do
				cell.Visible = false
			end
			return
		end
		buildFog()
		local memory = vision.exploredBits
		local hasMemory = typeof(memory) == "table" and #memory > 0
		for index = 1, VisionLogic.CellCount do
			local cell = fogCells[index]
			if cell then
				if hasMemory and memory then
					explored[index] = VisionLogic.bitOn(memory, index)
				end
				local lit = VisionLogic.bitOn(bits, index)
				if lit then
					explored[index] = true
					cell.Visible = false
				else
					cell.Visible = true
					local rgb, alpha = MinimapPaint.fogCell(explored[index] == true)
					cell.BackgroundColor3 = MinimapPaint.rgb(rgb)
					cell.BackgroundTransparency = alpha
				end
			end
		end
	end

	local dots = Instance.new("Folder")
	dots.Name = "Dots"
	dots.Parent = root

	local pingDot = mark(root, "Ping", 14, Theme.amber)
	pingDot.Visible = false
	pingDot.ZIndex = 6

	local clickFlash = mark(root, "ClickFlash", 12, Theme.amber)
	clickFlash.Visible = false
	clickFlash.ZIndex = 5
	clickFlash.BackgroundTransparency = 0.35
	Theme.stroke(clickFlash, Theme.cream, 2, 0.15)

	local history = Instance.new("Folder")
	history.Name = "PingHistory"
	history.Parent = root

	local function paintMarker(frame: Frame, marker: string?, team: string?, pingColor: Color3, size: number)
		local rgb = { math.floor(pingColor.R * 255 + 0.5), math.floor(pingColor.G * 255 + 0.5), math.floor(pingColor.B * 255 + 0.5) }
		applyPaint(frame, MinimapPaint.ping(marker, team, rgb, size))
	end

	local pingHandler: ((Vector3) -> ())? = nil
	local clickToken = 0

	local function flashClick(sx: number, sy: number)
		clickToken += 1
		local token = clickToken
		clickFlash.Position = UDim2.fromScale(sx, sy)
		clickFlash.Visible = true
		clickFlash.Size = UDim2.fromOffset(14, 14)
		clickFlash.BackgroundTransparency = 0.2
		rootStroke.Color = Theme.amber
		rootStroke.Transparency = 0.05
		local started = os.clock()
		task.spawn(function()
			while token == clickToken do
				local elapsed = os.clock() - started
				local flash = MinimapPaint.clickFlash(elapsed)
				if flash <= 0 then
					break
				end
				clickFlash.BackgroundTransparency = 0.2 + (1 - flash) * 0.75
				local grow = 14 + math.floor((1 - flash) * 8)
				clickFlash.Size = UDim2.fromOffset(grow, grow)
				rootStroke.Transparency = 0.05 + (1 - flash) * 0.2
				task.wait()
			end
			if token == clickToken then
				clickFlash.Visible = false
				rootStroke.Transparency = 0.25
			end
		end)
	end

	root.MouseButton1Click:Connect(function()
		if not pingHandler then
			return
		end
		local mouse = Players.LocalPlayer:GetMouse()
		local abs = root.AbsolutePosition
		local size = root.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local x = (mouse.X - abs.X) / size.X
		local y = (mouse.Y - abs.Y) / size.Y
		flashClick(x, y)
		pingHandler(scaleToWorld(x, y))
	end)

	local function stampDown(dot: Frame, text: string)
		local existing = dot:FindFirstChild("Timer")
		local label = if existing and existing:IsA("TextLabel") then existing else nil
		if not label then
			local created = Instance.new("TextLabel")
			created.Name = "Timer"
			created.BackgroundTransparency = 1
			created.AnchorPoint = Vector2.new(0.5, 1)
			created.Position = UDim2.new(0.5, 0, 0, -1)
			created.Size = UDim2.fromOffset(36, 12)
			created.Font = Enum.Font.GothamBold
			created.TextSize = 10
			created.TextColor3 = Theme.cream
			created.TextStrokeColor3 = Theme.ink
			created.TextStrokeTransparency = 0.35
			created.ZIndex = 4
			created.Parent = dot
			label = created
		end
		label.Text = text
	end

	local function placePaint(name: string, position: Vector3, paint: MinimapPaint.Paint, zIndex: number?)
		local existing = dots:FindFirstChild(name)
		local dot = if existing and existing:IsA("Frame") then existing else mark(dots, name, paint.size, MinimapPaint.rgb(paint.fill))
		applyPaint(dot, paint)
		local sx, sy = worldToScale(position)
		dot.Position = UDim2.fromScale(sx, sy)
		dot.ZIndex = zIndex or 3
		dot.Visible = true
		return dot
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if not visible then
				pingDot.Visible = false
				clickFlash.Visible = false
				for _, cell in fogCells do
					cell.Visible = false
				end
				CampRespawnFx.clear()
				WaveFx.clear()
			end
		end,
		update = function(snapshot: Types.MatchSnapshot, vision: Types.VisionFrame, localUserId: number)
			paintFog(vision)
			local seen: { [string]: boolean } = {}
			local visiblePlayers: { [number]: boolean } = {}
			for _, userId in vision.players do
				visiblePlayers[userId] = true
			end
			visiblePlayers[localUserId] = true
			local visibleMinions: { [string]: boolean } = {}
			for _, id in vision.minions do
				visibleMinions[id] = true
			end
			local map = Workspace:FindFirstChild(Constants.MapFolderName)

			for id, objective in snapshot.objectives do
				local part = nil
				local folder = if map then map:FindFirstChild("Objectives") else nil
				if folder then
					local child = folder:FindFirstChild(id)
					if child and child:IsA("BasePart") then
						part = child
					end
				end
				local pos = if part then part.Position else Vector3.zero
				if part then
					local style = MinimapPaint.structure(objective.tier, objective.team, objective.alive, objective.vulnerable)
					placePaint(`obj-{id}`, pos, style, 3)
					seen[`obj-{id}`] = true
				end
			end

			local function placeChampion(userId: number, rootPart: BasePart, matchPlayer: Types.MatchPlayer)
				local mine = snapshot.players[tostring(localUserId)]
				local ally = mine ~= nil and matchPlayer.team == mine.team
				if not (ally or visiblePlayers[userId]) then
					return
				end
				local style = MinimapPaint.champ(userId == localUserId, ally, matchPlayer.team, matchPlayer.isBot == true)
				-- You sit above other pips so the cream ring stays readable in a pile-up.
				placePaint(`p-{userId}`, rootPart.Position, style, if userId == localUserId then 5 else 4)
				seen[`p-{userId}`] = true
			end

			for _, other in Players:GetPlayers() do
				local matchPlayer = snapshot.players[tostring(other.UserId)]
				local character = other.Character
				local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
				if matchPlayer and rootPart and rootPart:IsA("BasePart") then
					placeChampion(other.UserId, rootPart, matchPlayer)
				end
			end

			local bots = if map then map:FindFirstChild("Bots") else nil
			if bots then
				for _, child in bots:GetChildren() do
					if child:IsA("Model") then
						local userId = child:GetAttribute(Constants.Attributes.UserId)
						local rootPart = child:FindFirstChild("HumanoidRootPart")
						if typeof(userId) == "number" and rootPart and rootPart:IsA("BasePart") then
							local matchPlayer = snapshot.players[tostring(userId)]
							if matchPlayer then
								placeChampion(userId, rootPart, matchPlayer)
							end
						end
					end
				end
			end

			local minions = if map then map:FindFirstChild("Minions") else nil
			local mine = snapshot.players[tostring(localUserId)]
			if minions then
				for _, child in minions:GetChildren() do
					if child:IsA("BasePart") then
						local team = child:GetAttribute(Constants.Attributes.Team)
						local ally = mine ~= nil and team == mine.team
						if ally or visibleMinions[child.Name] then
							local teamId = if typeof(team) == "string" then team else nil
							placePaint(`m-{child.Name}`, child.Position, MinimapPaint.minion(teamId), 3)
							seen[`m-{child.Name}`] = true
						end
					end
				end
			end

			local visibleJungle: { [string]: boolean } = {}
			for _, id in (vision.jungle or {}) do
				visibleJungle[id] = true
			end
			local jungle = if map then map:FindFirstChild("Jungle") else nil
			if jungle then
				for _, child in jungle:GetChildren() do
					if child:IsA("BasePart") and visibleJungle[child.Name] then
						local epicBody = child.Name == RiverEpic.Id
						placePaint(`j-{child.Name}`, child.Position, MinimapPaint.camp(epicBody), if epicBody then 4 else 3)
						seen[`j-{child.Name}`] = true
					end
				end
			end

			-- Small camps waiting on the existing stamp. Same fog/explored gate as the world chip.
			-- Canal Levi keeps the pit marker below.
			local campNow = Workspace:GetServerTimeNow()
			local campAllowed = CampRespawnJuice.modeAllows("Moba", snapshot.phase)
			local campRows = if campAllowed
				then CampRespawnJuice.select(vision.campDowns, vision.fogBits, vision.exploredBits, campNow)
				else {}
			for _, row in campRows do
				local dot = placePaint(`j-down-{row.id}`, Vector3.new(row.x, 0, row.z), MinimapPaint.campDown(), 3)
				local remain = CampRespawnJuice.remaining(row.respawnAt, campNow)
				stampDown(dot, CampRespawnJuice.chipRead(remain))
				seen[`j-down-{row.id}`] = true
			end
			CampRespawnFx.sync(campRows, campNow, campAllowed)

			-- Lane mouths the viewer can already see, for the same lead the world glow uses.
			-- Camp chips above are unchanged. No seconds — a blink only.
			local waveRows = WaveFx.sync(WaveJuice.modeAllows("Moba", snapshot.phase), vision.fogBits, vision.exploredBits)
			for _, cue in waveRows do
				if cue.kind == "telegraph" then
					local wavePaint = MinimapPaint.waveMouth()
					wavePaint.transparency = WaveJuice.blinkTransparency(cue.kind, cue.alpha)
					placePaint(`wave-{cue.id}`, Vector3.new(cue.x, 0, cue.z), wavePaint, 4)
					seen[`wave-{cue.id}`] = true
				end
			end

			-- Pit is the known canal, not the leashed body. Fog still hides the living part.
			local epicView = snapshot.riverEpic
			local epicPhase = if epicView then epicView.phase else "waiting"
			local epicMark = RiverEpic.marker(epicPhase, visibleJungle[RiverEpic.Id] == true)
			local leviPaint = MinimapPaint.levi(epicMark)
			if leviPaint and epicMark ~= "body" then
				-- Body already painted from the Jungle part when in vision.
				placePaint("j-epic-pit", Vector3.new(RiverEpic.X, 0, RiverEpic.Z), leviPaint, 3)
				seen["j-epic-pit"] = true
			end

			local visibleWards: { [string]: boolean } = {}
			for _, id in (vision.wards or {}) do
				visibleWards[id] = true
			end
			local wards = if map then map:FindFirstChild("Wards") else nil
			if wards then
				for _, child in wards:GetChildren() do
					if child:IsA("BasePart") and visibleWards[child.Name] then
						local team = child:GetAttribute(Constants.Attributes.Team)
						local kind = child:GetAttribute(Constants.Attributes.WardKind)
						local teamId = if typeof(team) == "string" then team else nil
						local kindId = if typeof(kind) == "string" then kind else nil
						local style = MinimapPaint.ward(kindId, teamId)
						local expiresAt = child:GetAttribute(Constants.Attributes.ExpiresAt)
						if typeof(expiresAt) == "number" then
							style.transparency = WardJuice.minimapTransparency(style.transparency, expiresAt, Workspace:GetServerTimeNow())
						end
						placePaint(`w-{child.Name}`, child.Position, style, 3)
						seen[`w-{child.Name}`] = true
					end
				end
			end

			for _, child in dots:GetChildren() do
				if child:IsA("Frame") and not seen[child.Name] then
					child:Destroy()
				end
			end
		end,
		showPing = function(payload: Types.PingPayload)
			local def = PingCatalog.get(payload.kind)
			local color = if def then def.color else Theme.amber
			local sx, sy = worldToScale(payload.position)
			local marker = payload.marker
			local team = payload.markerTeam
			local activeSize = if marker == "core" then 16 else 14
			paintMarker(pingDot, marker, team, color, activeSize)
			pingDot.Position = UDim2.fromScale(sx, sy)
			pingDot.Visible = true
			pingDot.BackgroundTransparency = 0

			local kids = history:GetChildren()
			while #kids >= 4 do
				kids[1]:Destroy()
				kids = history:GetChildren()
			end
			local ghost = mark(history, `H{os.clock()}`, 9, color)
			paintMarker(ghost, marker, team, color, if marker == "core" then 12 elseif marker == "post" or marker == "stall" then 11 else 9)
			ghost.Position = UDim2.fromScale(sx, sy)
			ghost.BackgroundTransparency = 0.15
			ghost.ZIndex = 5
			task.delay(4.5, function()
				if ghost.Parent then
					ghost:Destroy()
				end
			end)

			task.delay(2.4, function()
				if pingDot.Parent then
					pingDot.Visible = false
				end
			end)
		end,
		onPing = function(fn)
			pingHandler = fn
		end,
		contains = function(screenX: number, screenY: number)
			if not root.Visible then
				return false
			end
			local abs = root.AbsolutePosition
			local size = root.AbsoluteSize
			return screenX >= abs.X and screenX <= abs.X + size.X and screenY >= abs.Y and screenY <= abs.Y + size.Y
		end,
	}
end

return Minimap
