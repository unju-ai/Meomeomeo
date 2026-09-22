--!strict

-- Thin broadcast for confirmed combat VFX. Combat logic does not wait on this.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local FxRelay = {}

function FxRelay.emit(event: Types.CombatFxEvent)
	Remotes.event("CombatFx"):FireAllClients(event)
end

-- Floating combat numbers on the same CombatFx remote (amount + kind).
-- Client filters to local deal/take, fog, and spam caps.
function FxRelay.float(
	origin: Vector3,
	amount: number,
	floatKind: Types.CombatFloatKind,
	targetUserId: number?,
	attackerUserId: number?,
	team: Types.TeamId?
)
	if amount <= 0.05 then
		return
	end
	FxRelay.emit({
		kind = "float",
		origin = origin,
		amount = amount,
		floatKind = floatKind,
		userId = targetUserId,
		attackerUserId = attackerUserId,
		team = team,
	})
end

-- Local last-hit gold paint. Same gold FarmCredit just credited. Not a bounty.
-- Client keeps it on the credited cat and merges with CombatFloat.
function FxRelay.lastHit(origin: Vector3, userId: number, gold: number)
	if gold <= 0 then
		return
	end
	FxRelay.emit({
		kind = "lastHit",
		origin = origin,
		amount = gold,
		userId = userId,
	})
end

return FxRelay
