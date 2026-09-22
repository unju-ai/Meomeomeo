--!strict

-- Cross-mode drip. Unlocks from stall scores and Cat Rift; apply on any player character.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local CosmeticCatalog = require(Shared:WaitForChild("CosmeticCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local ModeService = require(script.Parent.Parent.Mode.ModeService)
local ClosetStore = require(script.Parent.ClosetStore)
local CosmeticAppearance = require(script.Parent.CosmeticAppearance)

local CosmeticService = {}

local function statsOf(userId: number): CosmeticCatalog.Stats
	local row = ClosetStore.get(userId)
	return {
		runMeters = ModeService.yarnMetersOf(userId),
		koiLegendary = ModeService.koiLegendaryOf(userId),
		partyWins = ModeService.partyWinsOf(userId),
		arcadeProfit = ModeService.arcadeBestOf(userId),
		riftWins = row.riftWins,
		riftTowerKills = row.riftTowerKills,
		riftKills = row.riftKills,
	}
end

local function applyAttributes(player: Player)
	local row = ClosetStore.get(player.UserId)
	player:SetAttribute(Constants.Attributes.CosmeticHat, row.hat or "")
	player:SetAttribute(Constants.Attributes.CosmeticTrail, row.trail or "")
end

local function snapshot(player: Player, toast: string?): Types.ClosetStatus
	local row = ClosetStore.get(player.UserId)
	local owned = CosmeticCatalog.ownedSet(row.owned)
	local stats = statsOf(player.UserId)
	local items: { Types.CosmeticRow } = {}
	for _, def in CosmeticCatalog.all() do
		local isOwned = owned[def.id] == true
		local locked = not isOwned and not CosmeticCatalog.meets(def, stats) and CosmeticCatalog.yarnCost(def) <= 0
		if not isOwned and CosmeticCatalog.yarnCost(def) > 0 then
			locked = false
		end
		table.insert(items, {
			id = def.id,
			name = def.name,
			slot = def.slot,
			rarity = def.rarity,
			blurb = def.blurb,
			hint = def.hint,
			owned = isOwned,
			equipped = row.hat == def.id or row.trail == def.id,
			locked = locked and not isOwned,
			cost = CosmeticCatalog.yarnCost(def),
		})
	end
	return {
		yarn = row.yarn,
		persistMode = row.persistMode,
		hat = row.hat,
		trail = row.trail,
		items = items,
		toast = toast,
		disclaimer = CosmeticCatalog.Disclaimer,
	}
end

local function fire(player: Player, toast: string?)
	applyAttributes(player)
	Remotes.event("ClosetUpdated"):FireClient(player, snapshot(player, toast))
end

function CosmeticService.dress(player: Player)
	applyAttributes(player)
	local character = player.Character
	if not character then
		return
	end
	character:SetAttribute(Constants.Attributes.UserId, player.UserId)
	local row = ClosetStore.get(player.UserId)
	CosmeticAppearance.apply(character, row.hat, row.trail)
end

function CosmeticService.dressModel(model: Model, userId: number)
	local row = ClosetStore.get(userId)
	model:SetAttribute(Constants.Attributes.UserId, userId)
	CosmeticAppearance.apply(model, row.hat, row.trail)
end

local function grantFromStats(player: Player): { string }
	local row = ClosetStore.get(player.UserId)
	local owned = CosmeticCatalog.ownedSet(row.owned)
	local stats = statsOf(player.UserId)
	local gained = {}
	for _, def in CosmeticCatalog.all() do
		if not owned[def.id] and CosmeticCatalog.meets(def, stats) then
			if ClosetStore.grant(player.UserId, def.id) then
				table.insert(gained, def.name)
			end
		end
	end
	return gained
end

function CosmeticService.refresh(player: Player): { string }
	local gained = grantFromStats(player)
	if #gained > 0 then
		fire(player, `UNLOCKED · {gained[1]}`)
	else
		applyAttributes(player)
	end
	CosmeticService.dress(player)
	return gained
end

local function grantQuiet(player: Player): { string }
	local gained = grantFromStats(player)
	if #gained > 0 then
		fire(player, `UNLOCKED · {gained[1]}`)
		CosmeticService.dress(player)
	end
	return gained
end

function CosmeticService.noteRiftKill(player: Player)
	ClosetStore.noteRift(player.UserId, 0, 0, 1)
	grantQuiet(player)
end

function CosmeticService.noteRiftStructure(player: Player)
	ClosetStore.noteRift(player.UserId, 0, 1, 0)
	grantQuiet(player)
end

function CosmeticService.noteRiftMatchEnd(player: Player, won: boolean)
	if won then
		ClosetStore.noteRift(player.UserId, 1, 0, 0)
	end
	ClosetStore.addYarn(player.UserId, CosmeticCatalog.riftYarn(won))
	local gained = CosmeticService.refresh(player)
	if #gained == 0 then
		fire(player, nil)
	end
end

function CosmeticService.status(player: Player): Types.ClosetStatus
	CosmeticService.refresh(player)
	return snapshot(player, nil)
end

function CosmeticService.equip(player: Player, payload: unknown): Types.TradeResult
	if typeof(payload) ~= "table" then
		return { ok = false, error = "Bad closet input." }
	end
	local body = payload :: Types.CosmeticEquip
	local slot = CosmeticCatalog.parseSlot(body.slot)
	if (body.id == nil or body.id == "") and slot then
		ClosetStore.unequipSlot(player.UserId, slot)
		fire(player, "Unequipped")
		CosmeticService.dress(player)
		return { ok = true }
	end
	local ok, err = ClosetStore.equip(player.UserId, body.id)
	if not ok then
		return { ok = false, error = err or "Could not equip." }
	end
	local def = CosmeticCatalog.get(body.id)
	fire(player, if def then `EQUIPPED · {def.name}` else "Equipped")
	CosmeticService.dress(player)
	return { ok = true }
end

function CosmeticService.buy(player: Player, id: unknown): Types.TradeResult
	if typeof(id) ~= "string" then
		return { ok = false, error = "Unknown drip." }
	end
	local ok, err = ClosetStore.buy(player.UserId, id)
	if not ok then
		return { ok = false, error = err or "Could not buy." }
	end
	local def = CosmeticCatalog.get(id)
	fire(player, if def then `BOUGHT · {def.name}` else "Bought")
	CosmeticService.dress(player)
	return { ok = true }
end

function CosmeticService.init()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				CosmeticService.refresh(player)
				CosmeticService.dress(player)
			end)
		end)
		if player.Character then
			task.defer(function()
				CosmeticService.dress(player)
			end)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

function CosmeticService.clear(userId: number)
	ClosetStore.clear(userId)
end

return CosmeticService
