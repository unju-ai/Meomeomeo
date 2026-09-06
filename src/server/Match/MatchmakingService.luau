--!strict

local Players = game:GetService("Players")

local Config = require(script.Parent.Parent.Config)
local MatchService = require(script.Parent.MatchService)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local MatchmakingService = {}

local queue: { Player } = {}
local lastDifficulty: Types.BotDifficulty = Config.Bots.DefaultDifficulty

local function parseDifficulty(value: unknown): Types.BotDifficulty
	if value == "Easy" then
		return "Easy"
	end
	return "Normal"
end

local function queued(player: Player): boolean
	return table.find(queue, player) ~= nil
end

local function remove(player: Player)
	local index = table.find(queue, player)
	if index then
		table.remove(queue, index)
	end
end

local function snapshotQueue(): { Player }
	local living = {}
	for _, player in queue do
		if player.Parent then
			table.insert(living, player)
		end
	end
	queue = living
	return living
end

local function tryForm()
	if MatchService.isBusy() then
		return
	end
	local players = snapshotQueue()
	local needed = math.min(Config.Match.TeamSize * 2, math.max(Config.Match.MinPlayersToStart, 2))
	if #players < needed then
		return
	end
	local taken = {}
	for i = 1, needed do
		table.insert(taken, players[i])
	end
	for _, player in taken do
		remove(player)
	end
	MatchService.start(taken, false)
end

function MatchmakingService.queueCount(): number
	return #snapshotQueue()
end

function MatchmakingService.queue(player: Player): Types.TradeResult
	if MatchService.isBusy() then
		return { ok = false, error = "A match is already running on this server." }
	end
	if queued(player) then
		return { ok = false, error = "Already in queue." }
	end
	table.insert(queue, player)
	tryForm()
	return { ok = true }
end

function MatchmakingService.leave(player: Player): Types.TradeResult
	if not queued(player) then
		return { ok = false, error = "Not in queue." }
	end
	remove(player)
	return { ok = true }
end

function MatchmakingService.practice(player: Player, difficulty: unknown): Types.TradeResult
	if not Config.Match.PracticeEnabled then
		return { ok = false, error = "Practice is disabled." }
	end
	if MatchService.isBusy() then
		return { ok = false, error = "A match is already running." }
	end
	remove(player)
	lastDifficulty = parseDifficulty(difficulty)
	local ok, err = MatchService.start({ player }, true, lastDifficulty)
	if not ok then
		return { ok = false, error = err }
	end
	return { ok = true }
end

function MatchmakingService.leaveMatch(_player: Player): Types.TradeResult
	if not MatchService.snapshot() then
		return { ok = true }
	end
	if not MatchService.isEnded() then
		return { ok = false, error = "Wait for the match to end." }
	end
	MatchService.returnToLobby(true)
	return { ok = true }
end

function MatchmakingService.playAgain(player: Player): Types.TradeResult
	if MatchService.snapshot() and not MatchService.isEnded() then
		return { ok = false, error = "The match is still on." }
	end
	if MatchService.isEnded() then
		MatchService.returnToLobby(false)
	end
	return MatchmakingService.practice(player, lastDifficulty)
end

function MatchmakingService.init()
	Players.PlayerRemoving:Connect(remove)
	MatchService.init(function()
		tryForm()
	end)
end

return MatchmakingService
