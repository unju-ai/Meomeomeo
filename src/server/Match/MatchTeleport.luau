--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)

local MatchTeleport = {}

function MatchTeleport.targetPlaceId(): number
	return Config.Match.MatchPlaceId
end

function MatchTeleport.shouldReserve(): boolean
	return Config.Match.MatchPlaceId > 0
end

function MatchTeleport.mode(): Types.QueueMode
	return if MatchTeleport.shouldReserve() then "Reserved" else "InPlace"
end

function MatchTeleport.isReservedInstance(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

function MatchTeleport.lobbyPlaceId(payload: Types.MatchTeleportData?): number
	if Config.Match.LobbyPlaceId > 0 then
		return Config.Match.LobbyPlaceId
	end
	if payload and payload.lobbyPlaceId > 0 then
		return payload.lobbyPlaceId
	end
	return game.PlaceId
end

function MatchTeleport.read(player: Player): Types.MatchTeleportData?
	local ok, join = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or typeof(join) ~= "table" then
		return nil
	end
	local raw = (join :: any).TeleportData
	if typeof(raw) ~= "table" then
		return nil
	end
	local data = raw :: any
	if data.kind ~= "MeoMatch" or typeof(data.matchId) ~= "string" then
		return nil
	end
	local seats: { Types.MatchTeleportSeat } = {}
	if typeof(data.seats) == "table" then
		for _, seat in data.seats do
			if typeof(seat) == "table" and typeof(seat.userId) == "number" then
				local team: Types.TeamId = if seat.team == "Red" then "Red" else "Blue"
				table.insert(seats, {
					userId = seat.userId,
					displayName = if typeof(seat.displayName) == "string" then seat.displayName else "Cat",
					team = team,
					championId = if typeof(seat.championId) == "string" then seat.championId else nil,
				})
			end
		end
	end
	return {
		kind = "MeoMatch",
		matchId = data.matchId,
		lobbyPlaceId = if typeof(data.lobbyPlaceId) == "number" then data.lobbyPlaceId else 0,
		practice = data.practice == true,
		padWithBots = data.padWithBots ~= false,
		botDifficulty = if data.botDifficulty == "Easy" then "Easy" else "Normal",
		seats = seats,
	}
end

function MatchTeleport.reserveAndTeleport(players: { Player }, payload: Types.MatchTeleportData): (boolean, string?)
	local placeId = Config.Match.MatchPlaceId
	if placeId <= 0 then
		return false, "MatchPlaceId is 0 — in-place fallback."
	end
	if #players == 0 then
		return false, "Nobody to teleport."
	end
	if RunService:IsStudio() then
		return false, "Reserved servers need a published experience (Studio fallback)."
	end

	local reserved, code = pcall(function()
		return TeleportService:ReserveServer(placeId)
	end)
	if not reserved or typeof(code) ~= "string" then
		return false, "ReserveServer failed. Publish the experience and set MatchPlaceId."
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData(payload)

	local sent, err = pcall(function()
		TeleportService:TeleportAsync(placeId, players, options)
	end)
	if not sent then
		return false, if typeof(err) == "string" then err else "TeleportAsync failed."
	end
	return true, nil
end

function MatchTeleport.returnToLobby(players: { Player }, lobbyPlaceId: number): (boolean, string?)
	if lobbyPlaceId <= 0 or lobbyPlaceId == game.PlaceId and not MatchTeleport.isReservedInstance() then
		return false, "already-lobby"
	end
	if RunService:IsStudio() then
		return false, "studio"
	end
	local living = {}
	for _, player in players do
		if player.Parent then
			table.insert(living, player)
		end
	end
	if #living == 0 then
		return false, "empty"
	end
	local sent, err = pcall(function()
		TeleportService:TeleportAsync(lobbyPlaceId, living)
	end)
	if not sent then
		return false, if typeof(err) == "string" then err else "lobby teleport failed"
	end
	return true, nil
end

function MatchTeleport.presentSeats(seats: { Types.MatchTeleportSeat }): { Player }
	local list = {}
	for _, seat in seats do
		local player = Players:GetPlayerByUserId(seat.userId)
		if player then
			table.insert(list, player)
		end
	end
	return list
end

return MatchTeleport
