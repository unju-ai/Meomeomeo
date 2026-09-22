--!strict

-- World countdown for a small camp that is already down.
-- The stamp comes from the vision frame (JungleService pending, fog-gated).
-- Canal Levi is not painted here. Clearing the rift does not puff.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CampRespawnJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CampRespawnJuice"))

local CampRespawnFx = {}

local FOLDER_NAME = "MeoCampRespawn"

type Live = {
	respawnAt: number,
	position: Vector3,
	part: BasePart,
	label: TextLabel,
}

local folder: Folder? = nil
local lives: { [string]: Live } = {}
local loopBound = false

local function rgb(triple: { number }): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

local function root(): Folder
	if folder and folder.Parent then
		return folder
	end
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = Workspace
	folder = created
	return created
end

local function destroyLive(id: string)
	local live = lives[id]
	if not live then
		return
	end
	if live.part.Parent then
		live.part:Destroy()
	end
	lives[id] = nil
end

local function puff(at: Vector3)
	local cream = rgb(CampRespawnJuice.Cream)
	local amber = rgb(CampRespawnJuice.Amber)
	local ground = Vector3.new(at.X, 1.15, at.Z)

	local ball = Instance.new("Part")
	ball.Name = "CampRespawnPuff"
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.ForceField
	ball.Color = cream
	ball.Size = Vector3.new(3.4, 2.2, 3.4)
	ball.Transparency = 0.38
	ball.CFrame = CFrame.new(ground + Vector3.new(0, 1.05, 0))
	ball.Parent = root()

	local ring = Instance.new("Part")
	ring.Name = "CampRespawnRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.ForceField
	ring.Color = amber
	ring.Size = Vector3.new(0.08, 5.2, 5.2)
	ring.Transparency = 0.42
	ring.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = root()

	task.delay(CampRespawnJuice.PuffSeconds, function()
		if ball.Parent then
			ball:Destroy()
		end
		if ring.Parent then
			ring:Destroy()
		end
	end)
end

local function paintText(live: Live, now: number)
	local remain = CampRespawnJuice.remaining(live.respawnAt, now)
	live.label.Text = CampRespawnJuice.chipRead(remain)
	local late = CampRespawnJuice.displaySeconds(remain) <= 5
	live.label.TextColor3 = rgb(if late then CampRespawnJuice.Amber else CampRespawnJuice.Cream)
end

local function ensure(row: CampRespawnJuice.Down): Live
	local existing = lives[row.id]
	local position = Vector3.new(row.x, row.y, row.z)
	if existing and existing.part.Parent then
		existing.respawnAt = row.respawnAt
		existing.position = position
		existing.part.CFrame = CFrame.new(position + Vector3.new(0, 2.2, 0))
		return existing
	end

	local anchor = Instance.new("Part")
	anchor.Name = `CampDown-{row.id}`
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position + Vector3.new(0, 2.2, 0))
	anchor.Parent = root()

	local gui = Instance.new("BillboardGui")
	gui.Name = "Countdown"
	gui.Size = UDim2.fromOffset(52, 20)
	gui.StudsOffset = Vector3.new(0, 1.5, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "Read"
	label.BackgroundColor3 = rgb(CampRespawnJuice.Ink)
	label.BackgroundTransparency = 0.32
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = rgb(CampRespawnJuice.Cream)
	label.Text = ""
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(CampRespawnJuice.Amber)
	stroke.Thickness = 1.25
	stroke.Transparency = 0.12
	stroke.Parent = label

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label

	local live: Live = {
		respawnAt = row.respawnAt,
		position = position,
		part = anchor,
		label = label,
	}
	lives[row.id] = live
	return live
end

local function bind()
	if loopBound then
		return
	end
	loopBound = true
	RunService.Heartbeat:Connect(function()
		if next(lives) == nil then
			return
		end
		local now = Workspace:GetServerTimeNow()
		for _, live in lives do
			paintText(live, now)
		end
	end)
end

function CampRespawnFx.clear()
	local ids: { string } = {}
	for id in lives do
		table.insert(ids, id)
	end
	for _, id in ids do
		destroyLive(id)
	end
end

-- `rows` are already fog-gated. `allowed` is the Cat Rift fight gate.
function CampRespawnFx.sync(rows: { CampRespawnJuice.Down }, now: number, allowed: boolean)
	if not allowed then
		CampRespawnFx.clear()
		return
	end
	bind()
	local painted: { [string]: number } = {}
	for id, live in lives do
		painted[id] = live.respawnAt
	end
	local keep: { [string]: boolean } = {}
	for _, row in rows do
		if typeof(row.id) == "string" then
			keep[row.id] = true
			local live = ensure(row)
			paintText(live, now)
		end
	end
	local returning = CampRespawnJuice.puffIds(painted, rows, now)
	local bursts: { [string]: Vector3 } = {}
	for _, id in returning do
		local live = lives[id]
		if live then
			bursts[id] = live.position
		end
	end
	local stale: { string } = {}
	for id in lives do
		if not keep[id] then
			table.insert(stale, id)
		end
	end
	for _, id in stale do
		destroyLive(id)
	end
	for _, at in bursts do
		puff(at)
	end
end

return CampRespawnFx
