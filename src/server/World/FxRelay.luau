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
	attackerUserId: number?
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
	})
end

return FxRelay
