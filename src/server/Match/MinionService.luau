--!strict

local Workspace = game:GetService("Workspace")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

export type Minion = {
	id: string,
	team: Types.TeamId,
	lane: string,
	health: number,
	maxHealth: number,
	part: BasePart,
	nextAttack: number,
}

type Api = {
	getPhase: () -> string?,
	damagePlayerNear: (team: Types.TeamId, position: Vector3, range: number, amount: number) -> (),
	damageObjectiveNear: (team: Types.TeamId, position: Vector3, range: number, amount: number) -> (),
	onLastHit: (player: Player, gold: number) -> (),
}

local MinionService = {}

local api: Api? = nil
local running = false
local wave = 0
local minions: { [string]: Minion } = {}

local function folder(): Folder
	return MapBuilder.minionFolder()
end

local function stamp(part: BasePart, minion: Minion)
	part:SetAttribute(Constants.Attributes.MinionId, minion.id)
	part:SetAttribute(Constants.Attributes.Team, minion.team)
	part:SetAttribute("Health", minion.health)
	part:SetAttribute("MaxHealth", minion.maxHealth)
	local label = part:FindFirstChild("Label")
	if label and label:IsA("BillboardGui") then
		local text = label:FindFirstChildWhichIsA("TextLabel")
		if text then
			text.Text = `{minion.team} kitten  {math.floor(minion.health)}`
		end
	end
end

local function spawnOne(team: Types.TeamId, lane: string, index: number)
	wave = math.max(wave, 1)
	local id = `{team}-{lane}-w{wave}-{index}-{os.clock()}`
	local z = MapBuilder.laneZ(lane)
	local x = if team == "Blue" then -148 else 148
	local color = if team == "Blue" then Color3.fromRGB(110, 170, 230) else Color3.fromRGB(230, 120, 120)

	local part = Instance.new("Part")
	part.Name = id
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(2.4, 2.2, 3.2)
	part.CFrame = CFrame.new(x, 2.2, z)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = folder()

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(90, 18)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Parent = gui

	local minion: Minion = {
		id = id,
		team = team,
		lane = lane,
		health = Config.Minions.Health,
		maxHealth = Config.Minions.Health,
		part = part,
		nextAttack = 0,
	}
	minions[id] = minion
	stamp(part, minion)
end

local function enemyInFront(minion: Minion): Minion?
	local best: Minion? = nil
	local bestDist = Config.Minions.AttackRange
	for _, other in minions do
		if other.team ~= minion.team and other.health > 0 then
			local d = (other.part.Position - minion.part.Position).Magnitude
			if d <= bestDist then
				best = other
				bestDist = d
			end
		end
	end
	return best
end

local function march(minion: Minion, dt: number)
	local pos = minion.part.Position
	local goalX = if minion.team == "Blue" then 168 else -168
	local laneZ = MapBuilder.laneZ(minion.lane)
	local goalZ = if math.abs(pos.X) >= 145 then 0 else laneZ
	local dest = Vector3.new(goalX, pos.Y, goalZ)
	local delta = dest - pos
	if delta.Magnitude < 1 then
		return
	end
	local step = math.min(Config.Minions.Speed * dt, delta.Magnitude)
	minion.part.CFrame = CFrame.new(pos + delta.Unit * step)
end

local function tickMinion(minion: Minion, dt: number, now: number)
	if not minion.part.Parent or minion.health <= 0 then
		return
	end

	local foe = enemyInFront(minion)
	if foe then
		if now >= minion.nextAttack then
			minion.nextAttack = now + Config.Minions.AttackInterval
			MinionService.applyDamage(nil, foe.id, Config.Minions.Damage)
		end
		return
	end

	if api then
		if now >= minion.nextAttack then
			minion.nextAttack = now + Config.Minions.AttackInterval
			api.damagePlayerNear(minion.team, minion.part.Position, Config.Minions.AttackRange, Config.Minions.Damage)
			api.damageObjectiveNear(minion.team, minion.part.Position, Config.Minions.AttackRange + 6, Config.Minions.Damage)
		end
	end

	if not enemyInFront(minion) then
		march(minion, dt)
	end
end

function MinionService.list(): { Minion }
	local list = {}
	for _, minion in minions do
		if minion.health > 0 and minion.part.Parent then
			table.insert(list, minion)
		end
	end
	return list
end

function MinionService.get(id: string): Minion?
	return minions[id]
end

function MinionService.applyDamage(attacker: Player?, minionId: string, amount: number): boolean
	local minion = minions[minionId]
	if not minion or minion.health <= 0 then
		return false
	end
	minion.health = math.max(0, minion.health - amount)
	stamp(minion.part, minion)
	if minion.health <= 0 then
		minion.part:Destroy()
		minions[minionId] = nil
		if attacker and api then
			api.onLastHit(attacker, Config.Match.MinionGold)
		end
		return true
	end
	return false
end

function MinionService.damageInRadius(attacker: Player, team: Types.TeamId, position: Vector3, radius: number, amount: number)
	for _, minion in minions do
		if minion.team ~= team and minion.health > 0 then
			if (minion.part.Position - position).Magnitude <= radius then
				MinionService.applyDamage(attacker, minion.id, amount)
			end
		end
	end
end

function MinionService.clear()
	for id, minion in minions do
		if minion.part.Parent then
			minion.part:Destroy()
		end
		minions[id] = nil
	end
	wave = 0
end

function MinionService.stop()
	running = false
	MinionService.clear()
end

function MinionService.start()
	MinionService.clear()
	running = true
	wave = 0
	task.spawn(function()
		task.wait(Config.Minions.FirstWaveDelay)
		while running do
			if not api or api.getPhase() ~= "InProgress" then
				break
			end
			wave += 1
			for _, lane in Constants.Lanes do
				for i = 1, Config.Minions.PerLane do
					spawnOne("Blue", lane, i)
					spawnOne("Red", lane, i)
					task.wait(0.35)
					if not running then
						return
					end
				end
			end
			task.wait(Config.Minions.WaveInterval)
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while running do
			local now = os.clock()
			local dt = math.clamp(now - last, 0, 0.2)
			last = now
			for _, minion in minions do
				tickMinion(minion, dt, Workspace:GetServerTimeNow())
			end
			task.wait(0.15)
		end
	end)
end

function MinionService.init(hooks: Api)
	api = hooks
end

return MinionService
