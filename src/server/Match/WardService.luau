--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local ItemCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local ShopService = require(script.Parent.ShopService)

export type WardKind = "trinket" | "control"

export type Ward = {
	id: string,
	team: Types.TeamId,
	ownerUserId: number,
	kind: WardKind,
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

local CONTROL_COLOR = Color3.fromRGB(255, 92, 196)

local function tint(ward: Ward)
	if ward.kind == "control" then
		ward.part.Color = CONTROL_COLOR
	else
		ward.part.Color = if ward.team == "Blue" then Color3.fromRGB(90, 160, 230) else Color3.fromRGB(230, 90, 100)
	end
	local label = ward.part:FindFirstChild("Label")
	if label and label:IsA("BillboardGui") then
		local text = label:FindFirstChildOfClass("TextLabel")
		if text then
			local tag = if ward.kind == "control" then "pink" else "ward"
			text.Text = `{tag} {math.floor(ward.health)}`
			if ward.kind == "control" then
				text.TextColor3 = CONTROL_COLOR
			end
		end
	end
end

local function paint(ward: Ward)
	tint(ward)
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
		-- Control yarn is a visible totem (not stealthed). Trinkets stay team-only unless revealed.
		local show = ward.team == team or ward.kind == "control"
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
	if ward.team == viewerTeam or ward.kind == "control" then
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

function WardService.sources(team: Types.TeamId): { { position: Vector3, control: boolean } }
	local points = {}
	for _, ward in wards do
		if ward.team == team then
			table.insert(points, { position = ward.part.Position, control = ward.kind == "control" })
		end
	end
	return points
end

function WardService.slowMul(team: Types.TeamId, position: Vector3): number
	local radius = Config.Vision.ControlSlowRadius
	for _, ward in wards do
		if ward.kind == "control" and ward.team ~= team then
			if (ward.part.Position - position).Magnitude <= radius then
				return Config.Vision.ControlSlowMul
			end
		end
	end
	return 1
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

function WardService.damageWhere(attacker: Player?, attackerTeam: Types.TeamId, hits: (Vector3) -> boolean, amount: number)
	for id, ward in wards do
		if ward.team ~= attackerTeam and hits(ward.part.Position) then
			WardService.applyDamage(attacker, id, amount)
		end
	end
end

local function popOwnerKind(userId: number, kind: WardKind)
	for id, ward in wards do
		if ward.ownerUserId == userId and ward.kind == kind then
			destroyWard(id)
		end
	end
end

local function placeWardFor(userId: number, team: Types.TeamId, position: Vector3, root: BasePart, kind: WardKind): Types.AbilityResult
	local t = now()
	if kind == "trinket" and (trinketReady[userId] or 0) > t then
		return { ok = false, error = "Trinket on cooldown." }
	end
	local dest = Vector3.new(
		math.clamp(position.X, Constants.MapBounds.MinX, Constants.MapBounds.MaxX),
		3,
		math.clamp(position.Z, Constants.MapBounds.MinZ, Constants.MapBounds.MaxZ)
	)
	if (Vector3.new(dest.X, 0, dest.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude > Config.Vision.WardPlaceRange + 4 then
		return { ok = false, error = "Ward out of range." }
	end

	popOwnerKind(userId, kind)
	nextId += 1
	local id = `ward-{nextId}`
	local part = Instance.new("Part")
	part.Name = id
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	if kind == "control" then
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(2.2, 2.2, 2.2)
	else
		part.Size = Vector3.new(1.6, 3.4, 1.6)
	end
	part.CFrame = CFrame.new(dest)
	part:SetAttribute(Constants.Attributes.WardId, id)
	part:SetAttribute(Constants.Attributes.Team, team)
	part:SetAttribute(Constants.Attributes.WardKind, kind)
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
	text.Text = if kind == "control" then `pink {Config.Vision.ControlHealth}` else `ward {Config.Vision.WardHealth}`
	text.Parent = gui

	local hp = if kind == "control" then Config.Vision.ControlHealth else Config.Vision.WardHealth
	local life = if kind == "control" then Config.Vision.ControlDuration else Config.Vision.TrinketDuration
	local ward: Ward = {
		id = id,
		team = team,
		ownerUserId = userId,
		kind = kind,
		health = hp,
		maxHealth = hp,
		expiresAt = t + life,
		revealedUntil = 0,
		part = part,
	}
	wards[id] = ward
	tint(ward)
	if kind == "trinket" then
		trinketReady[userId] = t + Config.Vision.TrinketCooldown
	end
	return { ok = true }
end

function WardService.placeTrinketFor(userId: number, team: Types.TeamId, position: Vector3, root: BasePart): Types.AbilityResult
	return placeWardFor(userId, team, position, root, "trinket")
end

function WardService.placeControlFor(userId: number, team: Types.TeamId, position: Vector3, root: BasePart): Types.AbilityResult
	return placeWardFor(userId, team, position, root, "control")
end

function WardService.placeTrinket(player: Player, team: Types.TeamId, position: Vector3): Types.AbilityResult
	local root = characterRoot(player)
	if not root then
		return { ok = false, error = "No character." }
	end
	return WardService.placeTrinketFor(player.UserId, team, position, root)
end

function WardService.placeControl(player: Player, team: Types.TeamId, position: Vector3): Types.AbilityResult
	if ShopService.count(player.UserId, ItemCatalog.ControlYarnId) < 1 then
		return { ok = false, error = "Buy Control Yarn at Pawmart (B). Press 6 to plant." }
	end
	local root = characterRoot(player)
	if not root then
		return { ok = false, error = "No character." }
	end
	local result = WardService.placeControlFor(player.UserId, team, position, root)
	if result.ok then
		ShopService.consume(player.UserId, ItemCatalog.ControlYarnId)
	end
	return result
end

function WardService.useLensFor(userId: number, team: Types.TeamId, root: BasePart): Types.AbilityResult
	if not ShopService.has(userId, "WhiskerLens") then
		return { ok = false, error = "Buy Whisker Lens at Pawmart (B)." }
	end
	local t = now()
	if (lensReady[userId] or 0) > t then
		return { ok = false, error = "Lens on cooldown." }
	end
	lensReady[userId] = t + Config.Vision.LensCooldown
	local radius = Config.Vision.LensRadius
	local hit: { string } = {}
	for id, ward in wards do
		if ward.team ~= team and (ward.part.Position - root.Position).Magnitude <= radius then
			ward.revealedUntil = t + Config.Vision.RevealSeconds
			table.insert(hit, id)
		end
	end
	for _, id in hit do
		WardService.applyDamage(nil, id, Config.Vision.LensDamage)
	end
	return { ok = true }
end

function WardService.useLens(player: Player, team: Types.TeamId): Types.AbilityResult
	local root = characterRoot(player)
	if not root then
		return { ok = false, error = "No character." }
	end
	return WardService.useLensFor(player.UserId, team, root)
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
				elseif ward.kind == "control" then
					local sight = Config.Vision.ControlTrueSight
					for otherId, other in wards do
						if otherId ~= id and other.team ~= ward.team then
							if (other.part.Position - ward.part.Position).Magnitude <= sight then
								other.revealedUntil = math.max(other.revealedUntil, t + Config.Vision.ControlRevealSeconds)
							end
						end
					end
				end
			end
			for _, id in expired do
				destroyWard(id)
			end
		end
	end)
end

return WardService
