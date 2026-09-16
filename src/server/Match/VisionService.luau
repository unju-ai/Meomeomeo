--!strict

local Players = game:GetService("Players")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local VisionLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("VisionLogic"))

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
local frameCache: { [number]: { at: number, frame: Types.VisionFrame } } = {}

local function sources(team: Types.TeamId): { VisionLogic.Source }
	local points: { VisionLogic.Source } = {}
	if not api then
		return points
	end
	local snapshot = api.getSnapshot()
	if not snapshot then
		return points
	end
	for _, matchPlayer in snapshot.players do
		if matchPlayer.team == team and matchPlayer.respawnAt == nil then
			local root = api.rootOf(matchPlayer.userId)
			if root then
				table.insert(points, {
					x = root.Position.X,
					z = root.Position.Z,
					radius = Config.Vision.ChampionRadius,
				})
			end
		end
	end
	for _, minion in MinionService.list() do
		if minion.team == team then
			table.insert(points, {
				x = minion.part.Position.X,
				z = minion.part.Position.Z,
				radius = Config.Vision.MinionRadius,
			})
		end
	end
	for _, objective in MapBuilder.objectiveStates() do
		if objective.team == team and objective.alive and (objective.kind == "Tower" or objective.kind == "Nexus") then
			local part = MapBuilder.getObjectivePart(objective.id)
			if part then
				table.insert(points, {
					x = part.Position.X,
					z = part.Position.Z,
					radius = Config.Vision.TowerRadius,
				})
			end
		end
	end
	for _, src in WardService.sources(team) do
		table.insert(points, {
			x = src.position.X,
			z = src.position.Z,
			radius = if src.control then Config.Vision.ControlRadius else Config.Vision.WardRadius,
		})
	end
	return points
end

local function emptyFrame(): Types.VisionFrame
	return {
		players = {},
		minions = {},
		jungle = {},
		wards = {},
		fogBits = VisionLogic.emptyMask(),
	}
end

local function computeFrame(userId: number): Types.VisionFrame
	if not api then
		return emptyFrame()
	end
	local snapshot = api.getSnapshot()
	if not snapshot or snapshot.phase ~= "InProgress" then
		return emptyFrame()
	end
	local mine = snapshot.players[tostring(userId)]
	if not mine then
		return emptyFrame()
	end

	local allySources = sources(mine.team)

	local visiblePlayers = {}
	for _, otherMatch in snapshot.players do
		local root = api.rootOf(otherMatch.userId)
		if root then
			if otherMatch.team == mine.team or VisionLogic.covered(allySources, root.Position.X, root.Position.Z) then
				table.insert(visiblePlayers, otherMatch.userId)
			end
		end
	end

	local visibleMinions = {}
	for _, minion in MinionService.list() do
		if minion.team == mine.team or VisionLogic.covered(allySources, minion.part.Position.X, minion.part.Position.Z) then
			table.insert(visibleMinions, minion.id)
		end
	end

	local visibleJungle = {}
	for _, monster in JungleService.list() do
		if VisionLogic.covered(allySources, monster.part.Position.X, monster.part.Position.Z) then
			table.insert(visibleJungle, monster.id)
		end
	end

	local root = api.rootOf(userId)
	local visibleWards = WardService.visibleToTeam(mine.team, if root then root.Position else nil)

	return {
		players = visiblePlayers,
		minions = visibleMinions,
		jungle = visibleJungle,
		wards = visibleWards,
		fogBits = VisionLogic.mask(allySources),
	}
end

function VisionService.frameForUser(userId: number): Types.VisionFrame
	local now = os.clock()
	local hit = frameCache[userId]
	if hit and now - hit.at < 0.08 then
		return hit.frame
	end
	local frame = computeFrame(userId)
	frameCache[userId] = { at = now, frame = frame }
	return frame
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

local function broadcast()
	if not api then
		return
	end
	table.clear(frameCache)
	local snapshot = api.getSnapshot()
	if not snapshot or snapshot.phase ~= "InProgress" then
		return
	end
	for _, player in Players:GetPlayers() do
		Remotes.event("VisionUpdated"):FireClient(player, VisionService.frameFor(player))
	end
end

function VisionService.stop()
	running = false
	table.clear(frameCache)
end

function VisionService.start()
	running = true
	task.spawn(function()
		broadcast()
		while running do
			task.wait(0.25)
			if running then
				broadcast()
			end
		end
	end)
end

function VisionService.init(hooks: Api)
	api = hooks
end

return VisionService
