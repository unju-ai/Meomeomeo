--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local ShopService = require(script.Parent.ShopService)

export type Ward = {
	id: string,
	team: Types.TeamId,
	ownerUserId: number,
	kind: "trinket",
	health: number,
	maxHealth: number,
	expiresAt: number,
	revealedUntil: number,
	part: BasePart,
}

local WardService = {}

local wards: { [string]: Ward } = {}
local trinketReady: { [number]: number } = {}
local lensReady: { [number]: number } = {}
local nextId = 0
local running = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function folder(): Folder
	local map = MapBuilder.get()
	local existing = map:FindFirstChild("Wards")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "Wards"
	created.Parent = map
	return created
end

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function destroyWard(id: string)
	local ward = wards[id]
	if not ward then
		return
	end
	if ward.part.Parent then
		ward.part:Destroy()
	end
	wards[id] = nil
end

local function paint(ward: Ward)
	local label = ward.part:FindFirstChild("Label")
	if label and label:IsA("BillboardGui") then
		local text = label:FindFirstChildOfClass("TextLabel")
		if text then
			text.Text = `ward {math.floor(ward.health)}`
		end
	end
end

function WardService.trinketReadyAt(userId: number): number
	return trinketReady[userId] or 0
end

function WardService.lensReadyAt(userId: number): number
	return lensReady[userId] or 0
end

function WardService.list(): { Ward }
	local list = {}
	for _, ward in wards do
		table.insert(list, ward)
	end
	return list
end

function WardService.get(id: string): Ward?
	return wards[id]
end

function WardService.visibleToTeam(team: Types.TeamId, viewerPosition: Vector3?): { string }
	local t = now()
	local ids = {}
	for _, ward in wards do
		local show = ward.team == team
		if not show and ward.revealedUntil > t then
			show = true
		end
		if not show and viewerPosition then
			if (ward.part.Position - viewerPosition).Magnitude <= Config.Vision.ProximityReveal then
				show = true
			end
		end
		if show then
			table.insert(ids, ward.id)
		end
	end
	return ids
end

function WardService.canSee(viewerTeam: Types.TeamId, wardId: string, viewerPosition: Vector3?): boolean
	local ward = wards[wardId]
	if not ward then
		return false
	end
	if ward.team == viewerTeam then
		return true
	end
	if ward.revealedUntil > now() then
		return true
	end
	if viewerPosition and (ward.part.Position - viewerPosition).Magnitude <= Config.Vision.ProximityReveal then
		return true
	end
	return false
end

function WardService.sources(team: Types.TeamId): { Vector3 }
	local points = {}
	for _, ward in wards do
		if ward.team == team then
			table.insert(points, ward.part.Position)
		end
	end
	return points
end

function WardService.applyDamage(attacker: Player?, wardId: string, amount: number): boolean
	local ward = wards[wardId]
	if not ward or amount <= 0 then
		return false
	end
	ward.health = math.max(0, ward.health - amount)
	paint(ward)
	if ward.health <= 0 then
		destroyWard(wardId)
		return true
	end
	return false
end

function WardService.damageWhere(attacker: Player, attackerTeam: Types.TeamId, hits: (Vector3) -> boolean, amount: number)
	for id, ward in wards do
		if ward.team ~= attackerTeam and hits(ward.part.Position) then
			WardService.applyDamage(attacker, id, amount)
		end
	end
end

local function popOwnerTrinket(userId: number)
	for id, ward in wards do
		if ward.ownerUserId == userId and ward.kind == "trinket" then
			destroyWard(id)
		end
	end
end

function WardService.placeTrinket(player: Player, team: Types.TeamId, position: Vector3): Types.AbilityResult
	local t = now()
	if (trinketReady[player.UserId] or 0) > t then
		return { ok = false, error = "Trinket on cooldown." }
	end
	local root = characterRoot(player)
	if not root then
		return { ok = false, error = "No character." }
	end
	local dest = Vector3.new(
		math.clamp(position.X, Constants.MapBounds.MinX, Constants.MapBounds.MaxX),
		3,
		math.clamp(position.Z, Constants.MapBounds.MinZ, Constants.MapBounds.MaxZ)
	)
	if (Vector3.new(dest.X, 0, dest.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude > Config.Vision.WardPlaceRange + 4 then
		return { ok = false, error = "Ward out of range." }
	end

	popOwnerTrinket(player.UserId)
	nextId += 1
	local id = `ward-{nextId}`
	local part = Instance.new("Part")
	part.Name = id
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Size = Vector3.new(1.6, 3.4, 1.6)
	part.CFrame = CFrame.new(dest)
	part.Color = if team == "Blue" then Color3.fromRGB(90, 160, 230) else Color3.fromRGB(230, 90, 100)
	part:SetAttribute(Constants.Attributes.WardId, id)
	part:SetAttribute(Constants.Attributes.Team, team)
	part.Parent = folder()

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(80, 22)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 243, 224)
	text.Text = `ward {Config.Vision.WardHealth}`
	text.Parent = gui

	wards[id] = {
		id = id,
		team = team,
		ownerUserId = player.UserId,
		kind = "trinket",
		health = Config.Vision.WardHealth,
		maxHealth = Config.Vision.WardHealth,
		expiresAt = t + Config.Vision.TrinketDuration,
		revealedUntil = 0,
		part = part,
	}
	trinketReady[player.UserId] = t + Config.Vision.TrinketCooldown
	return { ok = true }
end

function WardService.useLens(player: Player, team: Types.TeamId): Types.AbilityResult
	if not ShopService.has(player.UserId, "WhiskerLens") then
		return { ok = false, error = "Buy Whisker Lens at Pawmart (B)." }
	end
	local t = now()
	if (lensReady[player.UserId] or 0) > t then
		return { ok = false, error = "Lens on cooldown." }
	end
	local root = characterRoot(player)
	if not root then
		return { ok = false, error = "No character." }
	end
	lensReady[player.UserId] = t + Config.Vision.LensCooldown
	local radius = Config.Vision.LensRadius
	local hit: { string } = {}
	for id, ward in wards do
		if ward.team ~= team and (ward.part.Position - root.Position).Magnitude <= radius then
			ward.revealedUntil = t + Config.Vision.RevealSeconds
			table.insert(hit, id)
		end
	end
	for _, id in hit do
		WardService.applyDamage(player, id, Config.Vision.LensDamage)
	end
	return { ok = true }
end

function WardService.clearAll()
	for id in wards do
		destroyWard(id)
	end
	table.clear(trinketReady)
	table.clear(lensReady)
end

function WardService.stop()
	running = false
	WardService.clearAll()
end

function WardService.start()
	WardService.clearAll()
	running = true
	folder()
	task.spawn(function()
		while running do
			task.wait(0.4)
			local t = now()
			local expired: { string } = {}
			for id, ward in wards do
				if not ward.part.Parent or t >= ward.expiresAt then
					table.insert(expired, id)
				end
			end
			for _, id in expired do
				destroyWard(id)
			end
		end
	end)
end

return WardService
