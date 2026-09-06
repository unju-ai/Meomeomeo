--!strict

local Players = game:GetService("Players")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)
local JungleService = require(script.Parent.JungleService)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local MinionService = require(script.Parent.MinionService)

type Api = {
	getSnapshot: () -> Types.MatchSnapshot?,
	characterRoot: (player: Player) -> BasePart?,
}

local VisionService = {}

local api: Api? = nil
local running = false

type VisionSource = { position: Vector3, kind: "unit" | "tower" }

local function sources(team: Types.TeamId): { VisionSource }
	local points: { VisionSource } = {}
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
			table.insert(points, { position = root.Position, kind = "unit" })
		end
	end
	for _, minion in MinionService.list() do
		if minion.team == team then
			table.insert(points, { position = minion.part.Position, kind = "unit" })
		end
	end
	for _, objective in MapBuilder.objectiveStates() do
		if objective.team == team and objective.alive and objective.kind == "Tower" then
			local part = MapBuilder.getObjectivePart(objective.id)
			if part then
				table.insert(points, { position = part.Position, kind = "tower" })
			end
		end
	end
	return points
end

local function seen(position: Vector3, team: Types.TeamId, kind: "champion" | "minion"): boolean
	local unitRadius = if kind == "champion" then Config.Vision.ChampionRadius else Config.Vision.MinionRadius
	for _, source in sources(team) do
		local limit = if source.kind == "tower" then Config.Vision.TowerRadius else unitRadius
		if (source.position - position).Magnitude <= limit then
			return true
		end
	end
	return false
end

function VisionService.frameFor(player: Player): Types.VisionFrame
	local empty: Types.VisionFrame = { players = {}, minions = {}, jungle = {} }
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

	local visibleJungle = {}
	for _, monster in JungleService.list() do
		if seen(monster.part.Position, mine.team, "minion") then
			table.insert(visibleJungle, monster.id)
		end
	end

	return { players = visiblePlayers, minions = visibleMinions, jungle = visibleJungle }
end

function VisionService.canSeePlayer(viewer: Player, target: Player): boolean
	if viewer == target then
		return true
	end
	for _, userId in VisionService.frameFor(viewer).players do
		if userId == target.UserId then
			return true
		end
	end
	return false
end

function VisionService.canSeeMinion(viewer: Player, minionId: string): boolean
	for _, id in VisionService.frameFor(viewer).minions do
		if id == minionId then
			return true
		end
	end
	return false
end

function VisionService.canSeeJungle(viewer: Player, jungleId: string): boolean
	for _, id in VisionService.frameFor(viewer).jungle do
		if id == jungleId then
			return true
		end
	end
	return false
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
