--!strict

-- Pure rule for the lane siege kitten (Yarn Cannon).
-- MinionService still owns the waits (FirstWaveDelay, KittenStep, WaveInterval).
-- Wave numbers are 1-based, matching the counter MinionService increments
-- before it spawns. Wave 3, 6, 9… put a cannon in the last slot of each
-- lane, for each team. Earlier slots and other waves stay ordinary kittens.
-- This module does not wait, spawn, or grant gold.

local CannonKitten = {}

CannonKitten.Name = "Yarn Cannon"
CannonKitten.SourceId = "yarn-cannon"
CannonKitten.HitLabel = "Yarn Shot"

-- First cannon is wave 3. Then every 3rd wave.
CannonKitten.Every = 3

-- About 1.8× a 95 HP kitten. Not a second Canal Levi.
CannonKitten.Health = 170
-- A little above Config.Minions.Damage (14). Champs and structures both take it.
CannonKitten.Damage = 18
-- Premium last hit. Still one CS through FarmCredit.lastHit. Above MinionGold (18).
CannonKitten.Gold = 36
-- A touch slower than Config.Minions.Speed (18). Spawn cadence does not use this.
CannonKitten.Speed = 16

-- Larger than a lane kitten (2.4, 2.2, 3.2). The gold ball is the accent.
CannonKitten.BodyX = 4.2
CannonKitten.BodyY = 3.2
CannonKitten.BodyZ = 3.6
CannonKitten.YarnSize = 2

CannonKitten.YarnRgb = { 255, 196, 90 }
CannonKitten.BlueBodyRgb = { 126, 148, 196 }
CannonKitten.RedBodyRgb = { 196, 120, 112 }

function CannonKitten.isCannonWave(waveNumber: number): boolean
	if waveNumber ~= waveNumber or waveNumber < CannonKitten.Every then
		return false
	end
	return waveNumber % CannonKitten.Every == 0
end

-- spawnIndex and perLane are 1-based. Only the last kitten of a cannon wave.
function CannonKitten.isCannonSlot(waveNumber: number, spawnIndex: number, perLane: number): boolean
	if spawnIndex ~= spawnIndex or perLane ~= perLane then
		return false
	end
	if perLane < 1 or spawnIndex ~= perLane then
		return false
	end
	return CannonKitten.isCannonWave(waveNumber)
end

return CannonKitten
