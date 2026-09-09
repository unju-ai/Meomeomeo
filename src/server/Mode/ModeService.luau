--!strict

-- Per-player game mode. Hub is default. MOBA and Yarn Run are exclusive per player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local ModeCatalog = require(Shared:WaitForChild("ModeCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local ModeService = {}

local modes: { [number]: Types.GameMode } = {}
local yarnBest: { [number]: number } = {}
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

function ModeService.noteYarnBest(userId: number, score: number)
	local prev = yarnBest[userId] or 0
	if score > prev then
		yarnBest[userId] = score
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		player:SetAttribute(Constants.Attributes.YarnBest, yarnBest[userId] or 0)
	end
end

function ModeService.yarnBestOf(userId: number): number
	return yarnBest[userId] or 0
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
		yarnBest = yarnBest[player.UserId] or 0,
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
