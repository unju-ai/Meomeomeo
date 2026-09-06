--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local MinionService = require(script.Parent.MinionService)

type Api = {
	getSnapshot: () -> Types.MatchSnapshot?,
	damagePlayer: (target: Player, amount: number) -> (),
	characterRoot: (player: Player) -> BasePart?,
}

local TowerService = {}

local api: Api? = nil
local running = false
local threat: { [string]: { userId: number, untilTime: number } } = {}
local nextShot: { [string]: number } = {}

function TowerService.noteThreat(attacker: Player, victimTeam: Types.TeamId)
	threat[victimTeam] = {
		userId = attacker.UserId,
		untilTime = Workspace:GetServerTimeNow() + Config.Towers.AggroSeconds,
	}
end

local function pickTarget(objective: Types.ObjectiveState, part: BasePart): (Player?, string?)
	if not api or not objective.alive then
		return nil, nil
	end
	local snapshot = api.getSnapshot()
	if not snapshot or snapshot.phase ~= "InProgress" then
		return nil, nil
	end

	local range = if objective.kind == "Nexus" then Config.Towers.NexusRange else Config.Towers.Range
	local now = Workspace:GetServerTimeNow()
	local aggro = threat[objective.team]
	if aggro and aggro.untilTime > now then
		for _, player in Players:GetPlayers() do
			local matchPlayer = snapshot.players[tostring(player.UserId)]
			local root = api.characterRoot(player)
			if matchPlayer and matchPlayer.team ~= objective.team and player.UserId == aggro.userId and root then
				if (root.Position - part.Position).Magnitude <= range then
					return player, nil
				end
			end
		end
	end

	local bestPlayer: Player? = nil
	local bestMinion: string? = nil
	local bestDist = range
	for _, player in Players:GetPlayers() do
		local matchPlayer = snapshot.players[tostring(player.UserId)]
		local root = api.characterRoot(player)
		if matchPlayer and matchPlayer.team ~= objective.team and root then
			local d = (root.Position - part.Position).Magnitude
			if d <= bestDist then
				bestPlayer = player
				bestMinion = nil
				bestDist = d
			end
		end
	end
	for _, minion in MinionService.list() do
		if minion.team ~= objective.team then
			local d = (minion.part.Position - part.Position).Magnitude
			if d <= bestDist then
				bestPlayer = nil
				bestMinion = minion.id
				bestDist = d
			end
		end
	end
	return bestPlayer, bestMinion
end

function TowerService.stop()
	running = false
	table.clear(threat)
	table.clear(nextShot)
end

function TowerService.start()
	TowerService.stop()
	running = true
	MapBuilder.refreshNexusGate()
	task.spawn(function()
		while running do
			task.wait(0.2)
			if not api then
				continue
			end
			local snapshot = api.getSnapshot()
			if not snapshot or snapshot.phase ~= "InProgress" then
				continue
			end
			local now = Workspace:GetServerTimeNow()
			for _, state in MapBuilder.objectiveStates() do
				if not state.alive then
					continue
				end
				local part = MapBuilder.getObjectivePart(state.id)
				if not part then
					continue
				end
				local readyAt = nextShot[state.id] or 0
				if now < readyAt then
					continue
				end
				local playerTarget, minionId = pickTarget(state, part)
				local dmg = if state.kind == "Nexus" then Config.Towers.NexusDamage else Config.Towers.Damage
				if playerTarget then
					nextShot[state.id] = now + Config.Towers.Interval
					api.damagePlayer(playerTarget, dmg)
				elseif minionId then
					nextShot[state.id] = now + Config.Towers.Interval
					MinionService.applyDamage(nil, minionId, dmg)
				end
			end
		end
	end)
end

function TowerService.init(hooks: Api)
	api = hooks
end

return TowerService
