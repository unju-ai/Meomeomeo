--!strict

-- Per-player game mode. Hub is default. MOBA and Yarn Run are exclusive per player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local ModeCatalog = require(Shared:WaitForChild("ModeCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local YarnRunCatalog = require(Shared:WaitForChild("YarnRunCatalog"))

local ModeService = {}

local modes: { [number]: Types.GameMode } = {}
local yarnBest: { [number]: YarnRunCatalog.YarnBest } = {}
local matchBusy: (() -> boolean)? = nil
local riftPlaying: (() -> number)? = nil
local yarnPlaying: (() -> number)? = nil

local function current(userId: number): Types.GameMode
	return modes[userId] or "Hub"
end

function ModeService.init(hooks: {
	matchBusy: () -> boolean,
	riftPlaying: () -> number,
	yarnPlaying: () -> number,
})
	matchBusy = hooks.matchBusy
	riftPlaying = hooks.riftPlaying
	yarnPlaying = hooks.yarnPlaying
end

function ModeService.get(player: Player): Types.GameMode
	return current(player.UserId)
end

function ModeService.is(player: Player, mode: Types.GameMode): boolean
	return current(player.UserId) == mode
end

function ModeService.set(player: Player, mode: Types.GameMode)
	modes[player.UserId] = mode
	player:SetAttribute(Constants.Attributes.GameMode, mode)
	ModeService.fire(player)
end

function ModeService.noteYarnBest(userId: number, score: number, meters: number?, samples: { YarnRunCatalog.GhostSample }?, combo: number?)
	local prev = yarnBest[userId]
	local prevScore = if prev then prev.score else 0
	if score > prevScore then
		local copy: { YarnRunCatalog.GhostSample } = {}
		if samples then
			for _, sample in samples do
				table.insert(copy, { t = sample.t, lane = sample.lane, y = sample.y, z = sample.z })
			end
		end
		yarnBest[userId] = {
			score = score,
			meters = meters or 0,
			combo = combo or 0,
			samples = copy,
		}
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		local best = yarnBest[userId]
		player:SetAttribute(Constants.Attributes.YarnBest, if best then best.score else 0)
	end
end

function ModeService.yarnBestOf(userId: number): number
	local best = yarnBest[userId]
	return if best then best.score else 0
end

function ModeService.yarnRecord(userId: number): YarnRunCatalog.YarnBest?
	return yarnBest[userId]
end

function ModeService.status(player: Player): Types.HubStatus
	local rift = if riftPlaying then riftPlaying() else 0
	local run = if yarnPlaying then yarnPlaying() else 0
	local tiles = {}
	for _, tile in ModeCatalog.all() do
		local playing = 0
		if tile.id == "CatRift" then
			playing = rift
		elseif tile.id == "YarnRun" then
			playing = run
		end
		table.insert(tiles, { id = tile.id, playing = playing })
	end
	return {
		mode = current(player.UserId),
		tiles = tiles,
		yarnBest = ModeService.yarnBestOf(player.UserId),
	}
end

function ModeService.fire(player: Player)
	Remotes.event("ModeChanged"):FireClient(player, ModeService.status(player))
end

function ModeService.busyMatch(): boolean
	return if matchBusy then matchBusy() else false
end

function ModeService.clear(userId: number)
	modes[userId] = nil
end

return ModeService
