--!strict

local Players = game:GetService("Players")

local ItemCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

type Api = {
	getSnapshot: () -> Types.MatchSnapshot?,
	spendGold: (player: Player, amount: number) -> boolean,
	goldOf: (player: Player) -> number,
	onLoadoutChanged: (player: Player) -> (),
}

local ShopService = {}

local api: Api? = nil
local owned: { [number]: { string } } = {}

local function listOf(userId: number): { string }
	local bag = owned[userId]
	if not bag then
		bag = {}
		owned[userId] = bag
	end
	return bag
end

function ShopService.owned(userId: number): { string }
	return table.clone(listOf(userId))
end

function ShopService.has(userId: number, itemId: string): boolean
	return table.find(listOf(userId), itemId) ~= nil
end

function ShopService.bonuses(userId: number): Types.ItemBonuses
	return ItemCatalog.bonuses(listOf(userId))
end

function ShopService.atFountain(player: Player): boolean
	local snapshot = if api then api.getSnapshot() else nil
	if not snapshot or snapshot.phase ~= "InProgress" then
		return false
	end
	local matchPlayer = snapshot.players[tostring(player.UserId)]
	if not matchPlayer then
		return false
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return false
	end
	local spawn = MapBuilder.getSpawn(matchPlayer.team)
	return (root.Position - spawn.Position).Magnitude <= Config.Shop.FountainRadius
end

function ShopService.status(player: Player): Types.ShopStatus
	return {
		gold = if api then api.goldOf(player) else 0,
		atFountain = ShopService.atFountain(player),
		owned = ShopService.owned(player.UserId),
		items = ItemCatalog.all(),
	}
end

function ShopService.applyMovement(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if player:GetAttribute(Constants.Attributes.Recalling) == true then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		return
	end
	humanoid.WalkSpeed = 16 + ShopService.bonuses(player.UserId).walkSpeed
	if humanoid.JumpPower <= 0 then
		humanoid.JumpPower = 50
	end
end

function ShopService.buy(player: Player, itemId: unknown): Types.TradeResult
	if typeof(itemId) ~= "string" then
		return { ok = false, error = "Unknown item." }
	end
	local item = ItemCatalog.get(itemId)
	if not item then
		return { ok = false, error = "Unknown item." }
	end
	if not ShopService.atFountain(player) then
		return { ok = false, error = "Shop at your fountain (or press B there)." }
	end
	local bag = listOf(player.UserId)
	if table.find(bag, item.id) then
		return { ok = false, error = "Already own that." }
	end
	if not api or not api.spendGold(player, item.cost) then
		return { ok = false, error = "Not enough gold." }
	end
	table.insert(bag, item.id)
	ShopService.applyMovement(player)
	api.onLoadoutChanged(player)
	Remotes.event("ShopUpdated"):FireClient(player, ShopService.status(player))
	return { ok = true }
end

function ShopService.clear(userId: number)
	owned[userId] = nil
end

function ShopService.clearAll()
	table.clear(owned)
end

function ShopService.init(hooks: Api)
	api = hooks
	Players.PlayerRemoving:Connect(function(player)
		owned[player.UserId] = nil
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				ShopService.applyMovement(player)
			end)
		end)
	end)
end

return ShopService
