--!strict

local Players = game:GetService("Players")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local MinionService = require(script.Parent.MinionService)

type Api = {
	getSnapshot: () -> Types.MatchSnapshot?,
	characterRoot: (player: Player) -> BasePart?,
}

local VisionService = {}

local api: Api? = nil
local running = false

local function sources(team: Types.TeamId): { Vector3 }
	local points = {}
	if not api then
		return points
	end
	local snapshot = api.getSnapshot()
	if not snapshot then
		return points
	end
	for _, player in Players:GetPlayers() do
		local matchPlayer = snapshot.players[tostring(player.UserId)]
		local root = api.characterRoot(player)
		if matchPlayer and matchPlayer.team == team and root then
			table.insert(points, root.Position)
		end
	end
	for _, minion in MinionService.list() do
		if minion.team == team then
			table.insert(points, minion.part.Position)
		end
	end
	for _, objective in MapBuilder.objectiveStates() do
		if objective.team == team and objective.alive and objective.kind == "Tower" then
			local part = MapBuilder.getObjectivePart(objective.id)
			if part then
				table.insert(points, part.Position)
			end
		end
	end
	return points
end

local function seen(position: Vector3, team: Types.TeamId, kind: "champion" | "minion"): boolean
	local radius = if kind == "champion" then Config.Vision.ChampionRadius else Config.Vision.MinionRadius
	-- Ally towers use tower radius when the source is a tower-sized gap;
	-- we just take the max of nearby source types by checking all sources
	-- with champion radius for players/towers and minion radius for minions.
	-- Simpler: any ally source within the unit's reveal radius.
	for _, point in sources(team) do
		local limit = radius
		if (point - position).Magnitude <= limit then
			return true
		end
		if (point - position).Magnitude <= Config.Vision.TowerRadius then
			-- still allow tower-sized reveal on minions/champs near towers
			return true
		end
	end
	return false
end

function VisionService.frameFor(player: Player): Types.VisionFrame
	local empty: Types.VisionFrame = { players = {}, minions = {} }
	if not api then
		return empty
	end
	local snapshot = api.getSnapshot()
	if not snapshot or snapshot.phase ~= "InProgress" then
		return empty
	end
	local mine = snapshot.players[tostring(player.UserId)]
	if not mine then
		return empty
	end

	local visiblePlayers = {}
	for _, other in Players:GetPlayers() do
		local otherMatch = snapshot.players[tostring(other.UserId)]
		local root = api.characterRoot(other)
		if otherMatch and root then
			if otherMatch.team == mine.team or seen(root.Position, mine.team, "champion") then
				table.insert(visiblePlayers, other.UserId)
			end
		end
	end

	local visibleMinions = {}
	for _, minion in MinionService.list() do
		if minion.team == mine.team or seen(minion.part.Position, mine.team, "minion") then
			table.insert(visibleMinions, minion.id)
		end
	end

	return { players = visiblePlayers, minions = visibleMinions }
end

function VisionService.stop()
	running = false
end

function VisionService.start()
	running = true
	task.spawn(function()
		while running do
			task.wait(0.25)
			if not api then
				continue
			end
			local snapshot = api.getSnapshot()
			if not snapshot or snapshot.phase ~= "InProgress" then
				continue
			end
			for _, player in Players:GetPlayers() do
				Remotes.event("VisionUpdated"):FireClient(player, VisionService.frameFor(player))
			end
		end
	end)
end

function VisionService.init(hooks: Api)
	api = hooks
end

return VisionService
