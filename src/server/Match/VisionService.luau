--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
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
local teamFogCache: { [Types.TeamId]: { number } } = {}
-- Match-lifetime only. Cleared on start/stop — never DataStore.
local teamExplored: { [Types.TeamId]: { number } } = {
	Blue = VisionLogic.emptyMask(),
	Red = VisionLogic.emptyMask(),
}
local lastKnown: { [Types.TeamId]: { [number]: Vector3 } } = {
	Blue = {},
	Red = {},
}
local rayCache: { [string]: boolean } = {}
local rayParams: RaycastParams? = nil

local function resetMemory()
	teamExplored.Blue = VisionLogic.emptyMask()
	teamExplored.Red = VisionLogic.emptyMask()
	table.clear(lastKnown.Blue)
	table.clear(lastKnown.Red)
	table.clear(frameCache)
	table.clear(teamFogCache)
	table.clear(rayCache)
end

local function shapeKind(part: BasePart): string
	if part:IsA("MeshPart") then
		return "Mesh"
	end
	return part.Shape.Name
end

local function harvestBlockers(map: Instance): ({ VisionLogic.Blocker }, { Instance })
	local blockers: { VisionLogic.Blocker } = {}
	local meshes: { Instance } = {}
	for _, inst in map:GetDescendants() do
		if inst:IsA("BasePart") and inst:GetAttribute(Constants.Attributes.BlocksVision) == true then
			local cf = inst.CFrame
			local right = cf.RightVector
			local up = cf.UpVector
			local look = cf.LookVector
			local sx, sy, sz, shape = VisionLogic.worldExtents(
				inst.Size.X,
				inst.Size.Y,
				inst.Size.Z,
				right.X,
				right.Y,
				right.Z,
				up.X,
				up.Y,
				up.Z,
				look.X,
				look.Y,
				look.Z,
				shapeKind(inst)
			)
			local blocker = VisionLogic.blockerFromExtents(inst.Name, sx, sy, sz, cf.Position.X, cf.Position.Y, cf.Position.Z, shape)
			if blocker then
				table.insert(blockers, blocker)
				if shape == "mesh" then
					table.insert(meshes, inst)
				end
			end
		end
	end
	return blockers, meshes
end

local function harvestIsComplete(blockers: { VisionLogic.Blocker }): boolean
	local names: { [string]: boolean } = {}
	for _, blocker in blockers do
		names[blocker.name] = true
	end
	for _, wall in VisionLogic.Walls do
		if not names[wall.name] then
			return false
		end
	end
	for _, cover in VisionLogic.Cover do
		if not names[cover.name] then
			return false
		end
	end
	return true
end

local function clearLos()
	VisionLogic.setBlockers(nil)
	VisionLogic.setMeshProbe(nil)
	rayParams = nil
	table.clear(rayCache)
end

-- Curated LoS layer: authored boxes/cylinders stay analytical. MeshParts raycast.
local function installLos()
	clearLos()
	local map = MapBuilder.get()
	local blockers, meshes = harvestBlockers(map)
	if harvestIsComplete(blockers) then
		VisionLogic.setBlockers(blockers)
	elseif #meshes > 0 then
		local merged = table.clone(VisionLogic.activeBlockers())
		for _, blocker in blockers do
			if blocker.shape == "mesh" then
				table.insert(merged, blocker)
			end
		end
		VisionLogic.setBlockers(merged)
	end
	if #meshes == 0 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = meshes
	params.RespectCanCollide = false
	params.IgnoreWater = true
	rayParams = params
	VisionLogic.setMeshProbe(function(sx: number, sz: number, tx: number, tz: number): boolean
		if not VisionLogic.meshAlong(sx, sz, tx, tz, VisionLogic.activeBlockers()) then
			return false
		end
		local paramsNow = rayParams
		if not paramsNow then
			return false
		end
		local key = `{math.floor(sx + 0.5)}:{math.floor(sz + 0.5)}:{math.floor(tx + 0.5)}:{math.floor(tz + 0.5)}`
		local cached = rayCache[key]
		if cached ~= nil then
			return cached
		end
		local origin = Vector3.new(sx, VisionLogic.EyeHeight, sz)
		local dest = Vector3.new(tx, VisionLogic.EyeHeight, tz)
		local delta = dest - origin
		if delta.Magnitude < 0.2 then
			rayCache[key] = false
			return false
		end
		local hit = Workspace:Raycast(origin, delta, paramsNow)
		local blocked = hit ~= nil
		rayCache[key] = blocked
		return blocked
	end)
end

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

local function fogForTeam(team: Types.TeamId): { number }
	local hit = teamFogCache[team]
	if hit then
		return hit
	end
	local mask = VisionLogic.mask(sources(team))
	teamFogCache[team] = mask
	local memory = teamExplored[team]
	if memory then
		VisionLogic.orInto(memory, mask)
	end
	return mask
end

local function emptyFrame(): Types.VisionFrame
	return {
		players = {},
		minions = {},
		jungle = {},
		wards = {},
		fogBits = VisionLogic.emptyMask(),
		exploredBits = VisionLogic.emptyMask(),
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
	local fogBits = fogForTeam(mine.team)
	local known = lastKnown[mine.team]

	local visiblePlayers = {}
	for _, otherMatch in snapshot.players do
		local root = api.rootOf(otherMatch.userId)
		if root then
			local seen = otherMatch.team == mine.team or VisionLogic.covered(allySources, root.Position.X, root.Position.Z)
			if seen then
				table.insert(visiblePlayers, otherMatch.userId)
				if otherMatch.team ~= mine.team and known then
					if otherMatch.respawnAt == nil then
						known[otherMatch.userId] = root.Position
					else
						known[otherMatch.userId] = nil
					end
				end
			end
		elseif known then
			if otherMatch.respawnAt ~= nil then
				known[otherMatch.userId] = nil
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

	local memory = teamExplored[mine.team] or VisionLogic.emptyMask()
	return {
		players = visiblePlayers,
		minions = visibleMinions,
		jungle = visibleJungle,
		wards = visibleWards,
		fogBits = fogBits,
		exploredBits = VisionLogic.cloneMask(memory),
	}
end

function VisionService.lastKnownOf(team: Types.TeamId, userId: number): Vector3?
	local bag = lastKnown[team]
	if not bag then
		return nil
	end
	return bag[userId]
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
	table.clear(teamFogCache)
	table.clear(rayCache)
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
	resetMemory()
	clearLos()
end

function VisionService.start()
	resetMemory()
	installLos()
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
