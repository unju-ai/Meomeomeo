--!strict

-- Thin broadcast for confirmed combat VFX. Combat logic does not wait on this.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local FxRelay = {}

function FxRelay.emit(event: Types.CombatFxEvent)
	Remotes.event("CombatFx"):FireAllClients(event)
end

return FxRelay
