--!strict

local Players = game:GetService("Players")

local ItemCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local ShopSell = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ShopSell"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Config = require(script.Parent.Parent.Config)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

type Api = {
	getSnapshot: () -> Types.MatchSnapshot?,
	spendGold: (userId: number, amount: number) -> boolean,
	-- Purse only. Not farm, not a bounty float, not CS.
	grantGold: (userId: number, amount: number) -> boolean,
	goldOf: (userId: number) -> number,
	onLoadoutChanged: (userId: number) -> (),
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

function ShopService.nearFountain(userId: number, position: Vector3): boolean
	local snapshot = if api then api.getSnapshot() else nil
	if not snapshot or snapshot.phase ~= "InProgress" then
		return false
	end
	local matchPlayer = snapshot.players[tostring(userId)]
	if not matchPlayer then
		return false
	end
	local spawn = MapBuilder.getSpawn(matchPlayer.team)
	return (position - spawn.Position).Magnitude <= Config.Shop.FountainRadius
end

function ShopService.atFountain(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return false
	end
	return ShopService.nearFountain(player.UserId, root.Position)
end

function ShopService.status(player: Player): Types.ShopStatus
	return {
		gold = if api then api.goldOf(player.UserId) else 0,
		atFountain = ShopService.atFountain(player),
		owned = ShopService.owned(player.UserId),
		items = ItemCatalog.all(),
	}
end

function ShopService.applyMovementToModel(model: Model?, userId: number)
	if not model then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	if player and (player:GetAttribute(Constants.Attributes.Recalling) == true or player:GetAttribute(Constants.Attributes.Channeling) == true) then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		return
	end
	humanoid.WalkSpeed = 16 + ShopService.bonuses(userId).walkSpeed
	if humanoid.JumpPower <= 0 then
		humanoid.JumpPower = 50
	end
end

function ShopService.applyMovement(player: Player)
	ShopService.applyMovementToModel(player.Character, player.UserId)
end

function ShopService.count(userId: number, itemId: string): number
	return ItemCatalog.count(listOf(userId), itemId)
end

function ShopService.consume(userId: number, itemId: string): boolean
	local bag = listOf(userId)
	local index = table.find(bag, itemId)
	if not index then
		return false
	end
	table.remove(bag, index)
	if api then
		api.onLoadoutChanged(userId)
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		Remotes.event("ShopUpdated"):FireClient(player, ShopService.status(player))
	end
	return true
end

function ShopService.grant(userId: number, itemId: string): Types.TradeResult
	local item = ItemCatalog.get(itemId)
	if not item then
		return { ok = false, error = "Unknown item." }
	end
	local bag = listOf(userId)
	if not ItemCatalog.canBuy(bag, item.id) then
		if ItemCatalog.maxStack(item.id) > 1 then
			return { ok = false, error = `Already carrying {ItemCatalog.maxStack(item.id)}.` }
		end
		return { ok = false, error = "Already own that." }
	end
	if not api or not api.spendGold(userId, item.cost) then
		return { ok = false, error = "Not enough gold." }
	end
	table.insert(bag, item.id)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		ShopService.applyMovement(player)
		Remotes.event("ShopUpdated"):FireClient(player, ShopService.status(player))
	end
	api.onLoadoutChanged(userId)
	return { ok = true }
end

-- Fountain check, then the gold + stack grant humans and bots share.
function ShopService.buyAt(userId: number, itemId: string, position: Vector3): Types.TradeResult
	if not ShopService.nearFountain(userId, position) then
		return { ok = false, error = "Shop at your fountain (or press B there)." }
	end
	return ShopService.grant(userId, itemId)
end

function ShopService.buy(player: Player, itemId: unknown): Types.TradeResult
	if typeof(itemId) ~= "string" then
		return { ok = false, error = "Unknown item." }
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return { ok = false, error = "Shop at your fountain (or press B there)." }
	end
	return ShopService.buyAt(player.UserId, itemId, root.Position)
end

local function pawnOne(userId: number, itemId: string): Types.TradeResult
	local item = ItemCatalog.get(itemId)
	if not item then
		return { ok = false, error = "Unknown item." }
	end
	local bag = listOf(userId)
	local index = table.find(bag, itemId)
	if not index then
		return { ok = false, error = ShopSell.EmptyError }
	end
	-- One copy. Control Yarn copies are remaining charges, each bought at
	-- full price, so this is full-item 70% once — not a slice of the cap.
	-- Cooldown is ignored. The stamp stays on the cat.
	local refund = ShopSell.refundGold(item.cost)
	table.remove(bag, index)
	if not api or not api.grantGold(userId, refund) then
		table.insert(bag, index, itemId)
		return { ok = false, error = "Could not return gold." }
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		ShopService.applyMovement(player)
		Remotes.event("ShopUpdated"):FireClient(player, ShopService.status(player))
	end
	api.onLoadoutChanged(userId)
	return { ok = true, gold = refund }
end

-- Same fountain disk as buy. Away from the pad refuses, even for a bad id.
-- Bots do not call this.
function ShopService.sellAt(userId: number, itemId: string, position: Vector3): Types.TradeResult
	local atFountain = ShopService.nearFountain(userId, position)
	if not atFountain then
		local _, reason = ShopSell.gate(false, 1)
		return { ok = false, error = reason }
	end
	if not ItemCatalog.get(itemId) then
		return { ok = false, error = "Unknown item." }
	end
	local allowed, reason = ShopSell.gate(true, ShopService.count(userId, itemId))
	if not allowed then
		return { ok = false, error = reason }
	end
	return pawnOne(userId, itemId)
end

function ShopService.sell(player: Player, itemId: unknown): Types.TradeResult
	if typeof(itemId) ~= "string" then
		return { ok = false, error = "Unknown item." }
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return { ok = false, error = ShopSell.AwayError }
	end
	return ShopService.sellAt(player.UserId, itemId, root.Position)
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
