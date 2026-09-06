--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

export type Monster = {
	id: string,
	name: string,
	kind: string,
	health: number,
	maxHealth: number,
	damage: number,
	gold: number,
	xp: number,
	respawn: number,
	spawn: Vector3,
	part: BasePart,
	nextAttack: number,
	aggroUserId: number?,
}

type Api = {
	getPhase: () -> string?,
	damagePlayer: (target: Player, amount: number) -> (),
	characterRoot: (player: Player) -> BasePart?,
	onClear: (player: Player, gold: number, xp: number) -> (),
	onDied: (position: Vector3, lastHitter: Player?) -> (),
}

type CampDef = {
	id: string,
	name: string,
	kind: string,
	position: Vector3,
	health: number,
	damage: number,
	gold: number,
	xp: number,
	respawn: number,
	size: Vector3,
	color: Color3,
}

local CAMPS: { CampDef } = {
	{
		id = "YarnGolemNW",
		name = "Yarn Golem",
		kind = "golem",
		position = Vector3.new(-70, 3.2, -100),
		health = 220,
		damage = 22,
		gold = 48,
		xp = 42,
		respawn = 45,
		size = Vector3.new(5.2, 5.4, 5.2),
		color = Color3.fromRGB(230, 190, 110),
	},
	{
		id = "PigeonsNW",
		name = "Pigeon Pack",
		kind = "bird",
		position = Vector3.new(-100, 2.4, -88),
		health = 95,
		damage = 12,
		gold = 22,
		xp = 20,
		respawn = 32,
		size = Vector3.new(3.2, 2.4, 3.6),
		color = Color3.fromRGB(170, 168, 176),
	},
	{
		id = "YarnGolemSE",
		name = "Yarn Golem",
		kind = "golem",
		position = Vector3.new(70, 3.2, 100),
		health = 220,
		damage = 22,
		gold = 48,
		xp = 42,
		respawn = 45,
		size = Vector3.new(5.2, 5.4, 5.2),
		color = Color3.fromRGB(230, 190, 110),
	},
	{
		id = "PigeonsSE",
		name = "Pigeon Pack",
		kind = "bird",
		position = Vector3.new(100, 2.4, 88),
		health = 95,
		damage = 12,
		gold = 22,
		xp = 20,
		respawn = 32,
		size = Vector3.new(3.2, 2.4, 3.6),
		color = Color3.fromRGB(170, 168, 176),
	},
	{
		id = "RiverCrabN",
		name = "River Crab",
		kind = "crab",
		position = Vector3.new(0, 2.3, -48),
		health = 150,
		damage = 16,
		gold = 36,
		xp = 32,
		respawn = 50,
		size = Vector3.new(4.2, 2.2, 4.6),
		color = Color3.fromRGB(90, 170, 160),
	},
	{
		id = "RiverCrabS",
		name = "River Crab",
		kind = "crab",
		position = Vector3.new(0, 2.3, 48),
		health = 150,
		damage = 16,
		gold = 36,
		xp = 32,
		respawn = 50,
		size = Vector3.new(4.2, 2.2, 4.6),
		color = Color3.fromRGB(90, 170, 160),
	},
}

local JungleService = {}

local api: Api? = nil
local running = false
local monsters: { [string]: Monster } = {}
local pending: { [string]: number } = {}

local function folder(): Folder
	return MapBuilder.jungleFolder()
end

local function stamp(monster: Monster)
	monster.part:SetAttribute(Constants.Attributes.JungleId, monster.id)
	monster.part:SetAttribute("Health", monster.health)
	monster.part:SetAttribute("MaxHealth", monster.maxHealth)
	local label = monster.part:FindFirstChild("Label")
	if label and label:IsA("BillboardGui") then
		local text = label:FindFirstChildWhichIsA("TextLabel")
		if text then
			text.Text = `{monster.name}  {math.floor(monster.health)}`
		end
	end
end

local function spawnCamp(def: CampDef)
	if monsters[def.id] then
		return
	end
	local part = Instance.new("Part")
	part.Name = def.id
	part.Anchored = true
	part.CanCollide = false
	part.Size = def.size
	part.CFrame = CFrame.new(def.position)
	part.Color = def.color
	part.Material = Enum.Material.SmoothPlastic
	if def.kind == "golem" then
		part.Shape = Enum.PartType.Ball
	elseif def.kind == "crab" then
		part.Shape = Enum.PartType.Cylinder
		part.CFrame = CFrame.new(def.position) * CFrame.Angles(0, 0, math.rad(90))
	end
	part.Parent = folder()

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(120, 20)
	gui.StudsOffset = Vector3.new(0, def.size.Y / 2 + 1.4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Parent = gui

	local monster: Monster = {
		id = def.id,
		name = def.name,
		kind = def.kind,
		health = def.health,
		maxHealth = def.health,
		damage = def.damage,
		gold = def.gold,
		xp = def.xp,
		respawn = def.respawn,
		spawn = def.position,
		part = part,
		nextAttack = 0,
		aggroUserId = nil,
	}
	monsters[def.id] = monster
	stamp(monster)
end

local function scheduleRespawn(def: CampDef)
	pending[def.id] = Workspace:GetServerTimeNow() + def.respawn
end

local function findDef(id: string): CampDef?
	for _, def in CAMPS do
		if def.id == id then
			return def
		end
	end
	return nil
end

local function resetCamp(monster: Monster)
	monster.health = monster.maxHealth
	monster.aggroUserId = nil
	monster.part.CFrame = CFrame.new(monster.spawn)
	stamp(monster)
end

local function tickMonster(monster: Monster, dt: number, now: number)
	if not monster.part.Parent or monster.health <= 0 then
		return
	end
	if not api then
		return
	end

	if monster.aggroUserId then
		local target = Players:GetPlayerByUserId(monster.aggroUserId)
		local root = if target then api.characterRoot(target) else nil
		if not target or not root then
			resetCamp(monster)
			return
		end
		local leash = (monster.part.Position - monster.spawn).Magnitude
		if leash > Config.Jungle.Leash then
			resetCamp(monster)
			return
		end
		local dest = root.Position
		local delta = dest - monster.part.Position
		local dist = delta.Magnitude
		if dist > Config.Jungle.AttackRange and dist > 0.5 then
			local step = math.min(Config.Jungle.Speed * dt, dist)
			monster.part.CFrame = CFrame.new(monster.part.Position + delta.Unit * step)
		elseif now >= monster.nextAttack then
			monster.nextAttack = now + Config.Jungle.AttackInterval
			api.damagePlayer(target, monster.damage)
		end
		return
	end

	local home = monster.spawn - monster.part.Position
	if home.Magnitude > 1 then
		local step = math.min(Config.Jungle.Speed * dt, home.Magnitude)
		monster.part.CFrame = CFrame.new(monster.part.Position + home.Unit * step)
	end
end

function JungleService.list(): { Monster }
	local list = {}
	for _, monster in monsters do
		if monster.health > 0 and monster.part.Parent then
			table.insert(list, monster)
		end
	end
	return list
end

function JungleService.get(id: string): Monster?
	return monsters[id]
end

function JungleService.applyDamage(attacker: Player?, jungleId: string, amount: number): boolean
	local monster = monsters[jungleId]
	if not monster or monster.health <= 0 then
		return false
	end
	if attacker then
		monster.aggroUserId = attacker.UserId
	end
	monster.health = math.max(0, monster.health - amount)
	stamp(monster)
	if monster.health <= 0 then
		local pos = monster.part.Position
		local def = findDef(monster.id)
		monster.part:Destroy()
		monsters[jungleId] = nil
		if def then
			scheduleRespawn(def)
		end
		if api then
			if attacker then
				api.onClear(attacker, monster.gold, monster.xp)
			end
			api.onDied(pos, attacker)
		end
		return true
	end
	return false
end

function JungleService.damageInRadius(attacker: Player, position: Vector3, radius: number, amount: number)
	for _, monster in monsters do
		if monster.health > 0 and (monster.part.Position - position).Magnitude <= radius then
			JungleService.applyDamage(attacker, monster.id, amount)
		end
	end
end

function JungleService.clear()
	for id, monster in monsters do
		if monster.part.Parent then
			monster.part:Destroy()
		end
		monsters[id] = nil
	end
	table.clear(pending)
end

function JungleService.stop()
	running = false
	JungleService.clear()
end

function JungleService.start()
	JungleService.clear()
	running = true
	task.spawn(function()
		task.wait(Config.Jungle.FirstSpawnDelay)
		if not running then
			return
		end
		for _, def in CAMPS do
			spawnCamp(def)
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while running do
			local clock = os.clock()
			local dt = math.clamp(clock - last, 0, 0.2)
			last = clock
			local now = Workspace:GetServerTimeNow()
			if api and api.getPhase() == "InProgress" then
				for id, readyAt in pending do
					if now >= readyAt then
						pending[id] = nil
						local def = findDef(id)
						if def then
							spawnCamp(def)
						end
					end
				end
				for _, monster in monsters do
					tickMonster(monster, dt, now)
				end
			end
			task.wait(0.15)
		end
	end)
end

function JungleService.init(hooks: Api)
	api = hooks
end

return JungleService
