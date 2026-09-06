--!strict

local Players = game:GetService("Players")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)
local JungleService = require(script.Parent.JungleService)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local MinionService = require(script.Parent.MinionService)
local WardService = require(script.Parent.WardService)

type Api = {
	getSnapshot: () -> Types.MatchSnapshot?,
	rootOf: (userId: number) -> BasePart?,
}

local VisionService = {}

local api: Api? = nil
local running = false

type VisionSource = { position: Vector3, kind: "unit" | "tower" | "ward" }

local function sources(team: Types.TeamId): { VisionSource }
	local points: { VisionSource } = {}
	if not api then
		return points
	end
	local snapshot = api.getSnapshot()
	if not snapshot then
		return points
	end
	for _, matchPlayer in snapshot.players do
		local root = api.rootOf(matchPlayer.userId)
		if matchPlayer.team == team and root then
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
	for _, pos in WardService.sources(team) do
		table.insert(points, { position = pos, kind = "ward" })
	end
	return points
end

local function seen(position: Vector3, team: Types.TeamId, kind: "champion" | "minion"): boolean
	local unitRadius = if kind == "champion" then Config.Vision.ChampionRadius else Config.Vision.MinionRadius
	for _, source in sources(team) do
		local limit = if source.kind == "tower"
			then Config.Vision.TowerRadius
			elseif source.kind == "ward" then Config.Vision.WardRadius
			else unitRadius
		if (source.position - position).Magnitude <= limit then
			return true
		end
	end
	return false
end

function VisionService.frameForUser(userId: number): Types.VisionFrame
	local empty: Types.VisionFrame = { players = {}, minions = {}, jungle = {}, wards = {} }
	if not api then
		return empty
	end
	local snapshot = api.getSnapshot()
	if not snapshot or snapshot.phase ~= "InProgress" then
		return empty
	end
	local mine = snapshot.players[tostring(userId)]
	if not mine then
		return empty
	end

	local visiblePlayers = {}
	for _, otherMatch in snapshot.players do
		local root = api.rootOf(otherMatch.userId)
		if root then
			if otherMatch.team == mine.team or seen(root.Position, mine.team, "champion") then
				table.insert(visiblePlayers, otherMatch.userId)
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

	local root = api.rootOf(userId)
	local visibleWards = WardService.visibleToTeam(mine.team, if root then root.Position else nil)

	return { players = visiblePlayers, minions = visibleMinions, jungle = visibleJungle, wards = visibleWards }
end

function VisionService.frameFor(player: Player): Types.VisionFrame
	return VisionService.frameForUser(player.UserId)
end

function VisionService.canSeeChampion(viewerUserId: number, targetUserId: number): boolean
	if viewerUserId == targetUserId then
		return true
	end
	for _, userId in VisionService.frameForUser(viewerUserId).players do
		if userId == targetUserId then
			return true
		end
	end
	return false
end

function VisionService.canSeePlayer(viewer: Player, target: Player): boolean
	return VisionService.canSeeChampion(viewer.UserId, target.UserId)
end

function VisionService.canSeeMinion(viewerUserId: number, minionId: string): boolean
	for _, id in VisionService.frameForUser(viewerUserId).minions do
		if id == minionId then
			return true
		end
	end
	return false
end

function VisionService.canSeeJungle(viewerUserId: number, jungleId: string): boolean
	for _, id in VisionService.frameForUser(viewerUserId).jungle do
		if id == jungleId then
			return true
		end
	end
	return false
end

function VisionService.canSeeWard(viewerUserId: number, wardId: string): boolean
	for _, id in VisionService.frameForUser(viewerUserId).wards do
		if id == wardId then
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
