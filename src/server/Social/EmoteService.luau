--!strict

-- Server-validated cat emotes. Cooldown + nearby replicate. No animation binaries.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local EmoteCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("EmoteCatalog"))

local CombatService = require(script.Parent.Parent.Match.CombatService)
local MatchService = require(script.Parent.Parent.Match.MatchService)

local EmoteService = {}

local lastAt: { [number]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return character.PrimaryPart
end

local function nearbyPlayers(origin: Vector3?): { Player }
	local radius = Config.Emotes.BroadcastRadius
	local out = {}
	for _, other in Players:GetPlayers() do
		if not origin then
			table.insert(out, other)
		else
			local root = rootOf(other)
			if not root or (root.Position - origin).Magnitude <= radius then
				table.insert(out, other)
			end
		end
	end
	return out
end

function EmoteService.play(player: Player, emoteId: unknown): Types.TradeResult
	local def = EmoteCatalog.get(emoteId)
	if not def then
		return { ok = false, error = "Unknown emote." }
	end

	local now = os.clock()
	local previous = lastAt[player.UserId]
	local cooldown = Config.Emotes.CooldownSeconds
	if previous and now - previous < cooldown then
		local remain = math.ceil(cooldown - (now - previous))
		return { ok = false, error = `Emote cooling down ({remain}s)` }
	end

	local snapshot = MatchService.snapshot()
	if snapshot and snapshot.phase == "InProgress" then
		local combat = CombatService.get(player.UserId)
		if combat and not combat.alive then
			return { ok = false, error = "Can't emote while down." }
		end
	end

	lastAt[player.UserId] = now
	local origin = rootOf(player)
	local payload: Types.EmoteEvent = {
		userId = player.UserId,
		emoteId = def.id,
		at = Workspace:GetServerTimeNow(),
	}
	for _, other in nearbyPlayers(if origin then origin.Position else nil) do
		Remotes.event("EmotePlayed"):FireClient(other, payload)
	end
	return { ok = true }
end

function EmoteService.clear(userId: number)
	lastAt[userId] = nil
end

function EmoteService.init()
	Players.PlayerRemoving:Connect(function(player)
		EmoteService.clear(player.UserId)
	end)
end

return EmoteService
