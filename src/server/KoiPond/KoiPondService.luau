--!strict

-- Server-authoritative cozy fishing. Cast → wait → cream-window reel.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local KoiCatalog = require(Shared:WaitForChild("KoiCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local ModeService = require(script.Parent.Parent.Mode.ModeService)
local CosmeticService = require(script.Parent.Parent.Cosmetics.CosmeticService)
local KoiPondBuilder = require(script.Parent.KoiPondBuilder)

type Session = {
	player: Player,
	phase: Types.KoiPondPhase,
	score: number,
	counts: { [string]: number },
	bestCatchScore: number,
	bestCatchName: string,
	bestCatchRarity: string,
	dayKey: string,
	seed: number,
	rng: Random,
	walkSpeed: number,
	biteAt: number,
	biteEnds: number,
	revealUntil: number,
	bar: number,
	barDir: number,
	fish: KoiCatalog.FishDef?,
	event: string?,
	eventUntil: number,
	missReason: string?,
	lastCatchName: string?,
	lastCatchRarity: string?,
	lastCatchScore: number,
	ticker: boolean,
	sendAcc: number,
	charConn: RBXScriptConnection?,
}

local KoiPondService = {}

local sessions: { [number]: Session } = {}
local bound = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function clockNow(): number
	return os.clock()
end

local function snapshotOf(session: Session): Types.KoiPondSnapshot
	local t = clockNow()
	local fish = session.fish
	return {
		phase = session.phase,
		score = session.score,
		bestCatchScore = session.bestCatchScore,
		bestCatchName = session.bestCatchName,
		bestCatchRarity = session.bestCatchRarity,
		dayKey = session.dayKey,
		event = if t < session.eventUntil then session.event else nil,
		missReason = session.missReason,
		bar = if session.phase == "Bite" then session.bar else nil,
		sweetHalf = if session.phase == "Bite" and fish then fish.sweetHalf else nil,
		caught = KoiCatalog.logRows(session.counts),
		lastCatchName = session.lastCatchName,
		lastCatchRarity = session.lastCatchRarity,
		lastCatchScore = session.lastCatchScore,
		ticker = session.ticker,
		pb = ModeService.koiBestOf(session.player.UserId),
	}
end

local function fire(session: Session)
	Remotes.event("KoiPondUpdated"):FireClient(session.player, snapshotOf(session))
end

local function shout(session: Session, text: string, hold: number?)
	session.event = text
	session.eventUntil = clockNow() + (hold or 1.25)
end

local function freezeCharacter(player: Player, on: boolean, walkSpeed: number?)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if on then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
	else
		humanoid.WalkSpeed = walkSpeed or 16
		humanoid.JumpPower = 50
		humanoid.AutoRotate = true
	end
end

local function place(session: Session)
	local character = session.player.Character
	if not character then
		return
	end
	local cf = KoiPondBuilder.dockCFrame()
	local ok = pcall(function()
		character:PivotTo(cf)
	end)
	if not ok then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.CFrame = cf
		end
	end
	CosmeticService.dress(session.player)
end

local function sendHome(player: Player)
	local map = Workspace:FindFirstChild(Constants.MapFolderName)
	local spawns = if map then map:FindFirstChild("Spawns") else nil
	local spawn = if spawns then spawns:FindFirstChild("Lobby") else nil
	if spawn and spawn:IsA("BasePart") then
		player.RespawnLocation = spawn
		local character = player.Character
		if character then
			pcall(function()
				character:PivotTo(spawn.CFrame + Vector3.new(0, 5, 0))
			end)
		end
	end
end

local function remember(session: Session)
	ModeService.noteKoiBest(session.player.UserId, session.bestCatchScore)
end

local function idleBobber(session: Session)
	KoiPondBuilder.setBobber(session.player.UserId, "none")
end

local function toIdle(session: Session)
	session.phase = "Idle"
	session.fish = nil
	session.bar = 0
	session.ticker = false
	idleBobber(session)
end

local function miss(session: Session, reason: string)
	session.phase = "Reveal"
	session.missReason = reason
	session.lastCatchName = nil
	session.lastCatchRarity = nil
	session.lastCatchScore = 0
	session.ticker = false
	session.revealUntil = clockNow() + KoiCatalog.RevealSeconds
	session.fish = nil
	shout(session, reason, 1.2)
	KoiPondBuilder.setBobber(session.player.UserId, "none")
	fire(session)
end

local function catch(session: Session)
	local fish = session.fish
	if not fish then
		miss(session, "The loaf swam off")
		return
	end
	session.score += fish.score
	session.counts[fish.id] = (session.counts[fish.id] or 0) + 1
	if fish.score > session.bestCatchScore then
		session.bestCatchScore = fish.score
		session.bestCatchName = fish.name
		session.bestCatchRarity = fish.rarity
	end
	if fish.rarity == "Legendary" then
		ModeService.noteKoiLegendary(session.player.UserId)
	end
	remember(session)
	CosmeticService.refresh(session.player)
	session.phase = "Reveal"
	session.missReason = nil
	session.lastCatchName = fish.name
	session.lastCatchRarity = fish.rarity
	session.lastCatchScore = fish.score
	session.ticker = fish.rarity == "Legendary"
	session.revealUntil = clockNow() + (if fish.rarity == "Legendary" then 1.8 else KoiCatalog.RevealSeconds)
	shout(session, if fish.ticker then fish.ticker else fish.name, if fish.rarity == "Legendary" then 1.8 else 1.25)
	KoiPondBuilder.setBobber(session.player.UserId, "catch", fish.color)
	session.fish = nil
	fire(session)
end

local function beginBite(session: Session)
	local fish = KoiCatalog.pick(session.rng:NextNumber())
	session.phase = "Bite"
	session.fish = fish
	session.bar = 0
	session.barDir = 1
	session.biteEnds = clockNow() + KoiCatalog.BiteSeconds
	session.missReason = nil
	session.ticker = false
	shout(session, "Nibble — reel the cream window", 1.1)
	KoiPondBuilder.setBobber(session.player.UserId, "bite", fish.color)
	fire(session)
end

local function cast(session: Session)
	session.phase = "Waiting"
	session.fish = nil
	session.missReason = nil
	session.ticker = false
	session.lastCatchName = nil
	session.lastCatchRarity = nil
	session.lastCatchScore = 0
	local waitFor = KoiCatalog.WaitMin + session.rng:NextNumber() * (KoiCatalog.WaitMax - KoiCatalog.WaitMin)
	session.biteAt = clockNow() + waitFor
	shout(session, "Yarn's in the drink", 1.0)
	KoiPondBuilder.setBobber(session.player.UserId, "waiting")
	fire(session)
end

local function bind()
	if bound then
		return
	end
	bound = true
	RunService.Heartbeat:Connect(function(dt)
		for _, session in sessions do
			if session.phase == "Waiting" then
				if clockNow() >= session.biteAt then
					beginBite(session)
				end
			elseif session.phase == "Bite" then
				session.bar += session.barDir * KoiCatalog.BarSpeed * dt
				if session.bar >= 1 then
					session.bar = 1
					session.barDir = -1
				elseif session.bar <= 0 then
					session.bar = 0
					session.barDir = 1
				end
				if clockNow() >= session.biteEnds then
					miss(session, "The loaf swam off")
				end
			elseif session.phase == "Reveal" then
				if clockNow() >= session.revealUntil then
					toIdle(session)
					fire(session)
				end
			end
			session.sendAcc += dt
			local hz = if session.phase == "Bite" then 0.05 else 0.18
			if session.sendAcc >= hz then
				session.sendAcc = 0
				if session.phase ~= "Idle" or clockNow() < session.eventUntil then
					fire(session)
				end
			end
		end
	end)
end

function KoiPondService.playingCount(): number
	local n = 0
	for _ in sessions do
		n += 1
	end
	return n
end

function KoiPondService.isPlaying(player: Player): boolean
	return sessions[player.UserId] ~= nil
end

function KoiPondService.snapshot(player: Player): Types.KoiPondSnapshot?
	local session = sessions[player.UserId]
	if not session then
		return nil
	end
	return snapshotOf(session)
end

function KoiPondService.start(player: Player): Types.TradeResult
	if ModeService.busyMatch() then
		return { ok = false, error = "Cat Rift is live on this server — try the pond after." }
	end
	if ModeService.is(player, "Moba") then
		return { ok = false, error = "Leave the Rift first." }
	end
	if ModeService.is(player, "YarnRun") then
		return { ok = false, error = "Leave Yarn Run first." }
	end
	if ModeService.is(player, "YarnParty") then
		return { ok = false, error = "Leave Yarn Party first." }
	end
	if ModeService.is(player, "MemeArcade") then
		return { ok = false, error = "Leave the arcade first." }
	end
	if sessions[player.UserId] then
		return { ok = false, error = "Already at the pond." }
	end

	KoiPondBuilder.ensure()
	local unix = now()
	local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
	local session: Session = {
		player = player,
		phase = "Idle",
		score = 0,
		counts = {},
		bestCatchScore = 0,
		bestCatchName = "",
		bestCatchRarity = "",
		dayKey = KoiCatalog.dayKey(unix),
		seed = KoiCatalog.dailySeed(unix),
		rng = Random.new(KoiCatalog.dailySeed(unix) + player.UserId),
		walkSpeed = if humanoid then humanoid.WalkSpeed else 16,
		biteAt = 0,
		biteEnds = 0,
		revealUntil = 0,
		bar = 0,
		barDir = 1,
		fish = nil,
		event = "Toss the yarn bobber",
		eventUntil = clockNow() + 1.4,
		missReason = nil,
		lastCatchName = nil,
		lastCatchRarity = nil,
		lastCatchScore = 0,
		ticker = false,
		sendAcc = 1,
		charConn = nil,
	}
	sessions[player.UserId] = session
	ModeService.set(player, "KoiPond")
	freezeCharacter(player, true, session.walkSpeed)
	place(session)
	session.charConn = player.CharacterAdded:Connect(function()
		task.defer(function()
			if sessions[player.UserId] ~= session then
				return
			end
			freezeCharacter(player, true, session.walkSpeed)
			place(session)
		end)
	end)
	bind()
	fire(session)
	return { ok = true }
end

function KoiPondService.input(player: Player, payload: unknown): Types.TradeResult
	local session = sessions[player.UserId]
	if not session then
		return { ok = false, error = "Not at the pond." }
	end
	if typeof(payload) ~= "table" then
		return { ok = false, error = "Bad input." }
	end
	local body = payload :: Types.KoiPondInput
	if body.action ~= "cast" and body.action ~= "reel" then
		return { ok = false, error = "Unknown pond action." }
	end
	if session.phase == "Idle" or session.phase == "Reveal" then
		if session.phase == "Reveal" then
			toIdle(session)
		end
		cast(session)
		return { ok = true }
	end
	if session.phase == "Waiting" then
		miss(session, "Patience, loaf — nothing bit")
		return { ok = true }
	end
	if session.phase == "Bite" then
		local fish = session.fish
		if fish and KoiCatalog.inWindow(session.bar, fish) then
			catch(session)
		else
			miss(session, "Slipped the cream window")
		end
		return { ok = true }
	end
	return { ok = true }
end

function KoiPondService.leave(player: Player): Types.TradeResult
	local session = sessions[player.UserId]
	if session then
		remember(session)
		freezeCharacter(player, false, session.walkSpeed)
		if session.charConn then
			session.charConn:Disconnect()
		end
		KoiPondBuilder.clearBobber(player.UserId)
	end
	sessions[player.UserId] = nil
	ModeService.set(player, "Hub")
	sendHome(player)
	return { ok = true }
end

function KoiPondService.clear(userId: number)
	local session = sessions[userId]
	if session and session.charConn then
		session.charConn:Disconnect()
	end
	KoiPondBuilder.clearBobber(userId)
	sessions[userId] = nil
end

return KoiPondService
