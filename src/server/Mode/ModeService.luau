--!strict

-- Per-player game mode. Hub is default. Mini-games are exclusive.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArcadeCatalog = require(Shared:WaitForChild("ArcadeCatalog"))
local Constants = require(Shared:WaitForChild("Constants"))
local ModeCatalog = require(Shared:WaitForChild("ModeCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local YarnRunCatalog = require(Shared:WaitForChild("YarnRunCatalog"))

local ModeService = {}

local modes: { [number]: Types.GameMode } = {}
local yarnBest: { [number]: YarnRunCatalog.YarnBest } = {}
local yarnMeters: { [number]: number } = {}
local koiBest: { [number]: number } = {}
local arcadeBest: { [number]: { day: string, profit: number } } = {}
local koiLegendary: { [number]: boolean } = {}
local partyWins: { [number]: number } = {}
local matchBusy: (() -> boolean)? = nil
local riftPlaying: (() -> number)? = nil
local yarnPlaying: (() -> number)? = nil
local koiPlaying: (() -> number)? = nil
local partyPlaying: (() -> number)? = nil
local arcadePlaying: (() -> number)? = nil

local function current(userId: number): Types.GameMode
	return modes[userId] or "Hub"
end

function ModeService.init(hooks: {
	matchBusy: () -> boolean,
	riftPlaying: () -> number,
	yarnPlaying: () -> number,
	koiPlaying: () -> number,
	partyPlaying: () -> number,
	arcadePlaying: () -> number,
})
	matchBusy = hooks.matchBusy
	riftPlaying = hooks.riftPlaying
	yarnPlaying = hooks.yarnPlaying
	koiPlaying = hooks.koiPlaying
	partyPlaying = hooks.partyPlaying
	arcadePlaying = hooks.arcadePlaying
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
			for _, sample in YarnRunCatalog.capSamples(samples) do
				table.insert(copy, sample)
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

function ModeService.seedYarnBest(userId: number, record: YarnRunCatalog.YarnBest)
	local prev = yarnBest[userId]
	if prev == nil or record.score > prev.score then
		local copy: { YarnRunCatalog.GhostSample } = {}
		for _, sample in record.samples do
			table.insert(copy, YarnRunCatalog.packSample(sample))
		end
		yarnBest[userId] = {
			score = record.score,
			meters = record.meters,
			combo = record.combo,
			samples = copy,
		}
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:SetAttribute(Constants.Attributes.YarnBest, record.score)
		end
	end
	ModeService.noteYarnMeters(userId, record.meters)
end

function ModeService.noteYarnMeters(userId: number, meters: number)
	local prev = yarnMeters[userId] or 0
	if meters > prev then
		yarnMeters[userId] = meters
	end
end

function ModeService.yarnMetersOf(userId: number): number
	local rec = yarnBest[userId]
	local fromBest = if rec then rec.meters else 0
	return math.max(yarnMeters[userId] or 0, fromBest)
end

function ModeService.noteKoiBest(userId: number, score: number)
	local prev = koiBest[userId] or 0
	if score > prev then
		koiBest[userId] = score
	end
end

function ModeService.koiBestOf(userId: number): number
	return koiBest[userId] or 0
end

function ModeService.noteArcadeBest(userId: number, profit: number): number
	local today = ArcadeCatalog.dayKey(os.time())
	local rec = arcadeBest[userId]
	if rec == nil or rec.day ~= today then
		rec = { day = today, profit = 0 }
	end
	if profit > rec.profit then
		rec.profit = profit
	end
	arcadeBest[userId] = rec
	return rec.profit
end

function ModeService.arcadeBestOf(userId: number): number
	local rec = arcadeBest[userId]
	if rec == nil or rec.day ~= ArcadeCatalog.dayKey(os.time()) then
		return 0
	end
	return rec.profit
end

function ModeService.noteKoiLegendary(userId: number)
	koiLegendary[userId] = true
end

function ModeService.koiLegendaryOf(userId: number): boolean
	return koiLegendary[userId] == true
end

function ModeService.notePartyWin(userId: number)
	partyWins[userId] = (partyWins[userId] or 0) + 1
end

function ModeService.partyWinsOf(userId: number): number
	return partyWins[userId] or 0
end

function ModeService.status(player: Player): Types.HubStatus
	local rift = if riftPlaying then riftPlaying() else 0
	local run = if yarnPlaying then yarnPlaying() else 0
	local pond = if koiPlaying then koiPlaying() else 0
	local bash = if partyPlaying then partyPlaying() else 0
	local tape = if arcadePlaying then arcadePlaying() else 0
	local tiles = {}
	for _, tile in ModeCatalog.all() do
		local playing = 0
		if tile.id == "CatRift" then
			playing = rift
		elseif tile.id == "YarnRun" then
			playing = run
		elseif tile.id == "KoiPond" then
			playing = pond
		elseif tile.id == "YarnParty" then
			playing = bash
		elseif tile.id == "MemeArcade" then
			playing = tape
		end
		table.insert(tiles, { id = tile.id, playing = playing })
	end
	return {
		mode = current(player.UserId),
		tiles = tiles,
		yarnBest = ModeService.yarnBestOf(player.UserId),
		koiBest = ModeService.koiBestOf(player.UserId),
		arcadeBest = ModeService.arcadeBestOf(player.UserId),
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
