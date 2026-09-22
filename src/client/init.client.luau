--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrandCatalog = require(Shared:WaitForChild("BrandCatalog"))
local ChampionCatalog = require(Shared:WaitForChild("ChampionCatalog"))
local Constants = require(Shared:WaitForChild("Constants"))
local HostGuide = require(Shared:WaitForChild("HostGuide"))
local OldTomGuide = require(Shared:WaitForChild("OldTomGuide"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Targeting = require(Shared:WaitForChild("Targeting"))
local Types = require(Shared:WaitForChild("Types"))
local VisionLogic = require(Shared:WaitForChild("VisionLogic"))
local RecallLogic = require(Shared:WaitForChild("RecallLogic"))
local ChampionKits = require(Shared:WaitForChild("ChampionKits"))
local ArcadeCatalog = require(Shared:WaitForChild("ArcadeCatalog"))
local CosmeticCatalog = require(Shared:WaitForChild("CosmeticCatalog"))
local PingCatalog = require(Shared:WaitForChild("PingCatalog"))
local PingLogic = require(Shared:WaitForChild("PingLogic"))
local SoundIds = require(script.Audio.SoundIds)

local Music = require(script.Audio.Music)
local Sfx = require(script.Audio.Sfx)
local CameraFollow = require(script.CameraFollow)
local CombatFx = require(script.Juice.CombatFx)
local EmoteFx = require(script.Juice.EmoteFx)
local FogOfWar = require(script.Juice.FogOfWar)
local LastSeenGhosts = require(script.Juice.LastSeenGhosts)
local PingFx = require(script.Juice.PingFx)
local ScreenJuice = require(script.Juice.ScreenJuice)
local Hud = require(script.UI.Hud)
local TargetingIndicator = require(script.TargetingIndicator)
local YarnCamera = require(script.YarnRun.YarnCamera)
local YarnGhost = require(script.YarnRun.YarnGhost)
local KoiCamera = require(script.KoiPond.KoiCamera)
local YarnPartyCamera = require(script.YarnParty.YarnPartyCamera)
local ArcadeCamera = require(script.Arcade.ArcadeCamera)

local player = Players.LocalPlayer

local function writePrefAttrs(
	sfxVolume: number,
	sfxMuted: boolean,
	musicVolume: number,
	musicMuted: boolean,
	muteOthers: boolean,
	hideBoardName: boolean,
	difficulty: Types.BotDifficulty?
)
	player:SetAttribute(Constants.Attributes.SfxVolume, sfxVolume)
	player:SetAttribute(Constants.Attributes.SfxMuted, sfxMuted)
	player:SetAttribute(Constants.Attributes.MusicVolume, musicVolume)
	player:SetAttribute(Constants.Attributes.MusicMuted, musicMuted)
	player:SetAttribute(Constants.Attributes.MuteOthersEmotes, muteOthers)
	player:SetAttribute(Constants.Attributes.HideBoardName, hideBoardName)
	if difficulty == "Easy" or difficulty == "Normal" or difficulty == "Hard" then
		player:SetAttribute(Constants.Attributes.PracticeDifficulty, difficulty)
	end
end

local function prefsFromRemote(value: any): Types.PlayerPrefs?
	if typeof(value) ~= "table" then
		return nil
	end
	local row = value :: any
	if typeof(row.sfxVolume) ~= "number" or typeof(row.musicVolume) ~= "number" then
		return nil
	end
	local difficulty: Types.BotDifficulty = "Normal"
	if row.practiceDifficulty == "Easy" or row.practiceDifficulty == "Hard" then
		difficulty = row.practiceDifficulty
	elseif row.practiceDifficulty == "Normal" then
		difficulty = "Normal"
	end
	return {
		sfxVolume = math.clamp(row.sfxVolume, 0, 1),
		sfxMuted = row.sfxMuted == true,
		musicVolume = math.clamp(row.musicVolume, 0, 1),
		musicMuted = row.musicMuted == true,
		muteOthersEmotes = row.muteOthersEmotes == true,
		hideBoardName = row.hideBoardName == true,
		practiceDifficulty = difficulty,
		persistMode = if row.persistMode == "DataStore" then "DataStore" else "Memory",
	}
end

-- Load before Hud + Music.setPhase so sliders and beds start on the saved mix.
local loadedPrefs: Types.PlayerPrefs? = nil
do
	local ok, result = pcall(function()
		return Remotes.function_("GetSettings"):InvokeServer()
	end)
	if ok then
		loadedPrefs = prefsFromRemote(result)
		if loadedPrefs then
			writePrefAttrs(
				loadedPrefs.sfxVolume,
				loadedPrefs.sfxMuted,
				loadedPrefs.musicVolume,
				loadedPrefs.musicMuted,
				loadedPrefs.muteOthersEmotes,
				loadedPrefs.hideBoardName,
				loadedPrefs.practiceDifficulty
			)
		end
	end
end

local hud = Hud.create()
ScreenJuice.init(hud.gui)
local muteOthersEmotes = false
local persistReady = false
local saveGen = 0

local function applyAudio(state: {
	sfxVolume: number,
	sfxMuted: boolean,
	musicVolume: number,
	musicMuted: boolean,
	muteOthersEmotes: boolean,
	hideBoardName: boolean,
})
	Sfx.setVolume(state.sfxVolume)
	Sfx.setMuted(state.sfxMuted)
	Music.setVolume(state.musicVolume)
	Music.setMuted(state.musicMuted)
	muteOthersEmotes = state.muteOthersEmotes
	writePrefAttrs(
		state.sfxVolume,
		state.sfxMuted,
		state.musicVolume,
		state.musicMuted,
		state.muteOthersEmotes,
		state.hideBoardName,
		hud.lobby.difficulty()
	)
end

local function queueSavePrefs()
	if not persistReady then
		return
	end
	saveGen += 1
	local gen = saveGen
	task.delay(0.45, function()
		if gen ~= saveGen then
			return
		end
		local state = hud.settings.getState()
		pcall(function()
			Remotes.function_("SaveSettings"):InvokeServer({
				sfxVolume = state.sfxVolume,
				sfxMuted = state.sfxMuted,
				musicVolume = state.musicVolume,
				musicMuted = state.musicMuted,
				muteOthersEmotes = state.muteOthersEmotes,
				hideBoardName = state.hideBoardName,
				practiceDifficulty = hud.lobby.difficulty(),
			})
		end)
	end)
end

local function saveDifficulty(difficulty: Types.BotDifficulty)
	pcall(function()
		Remotes.function_("SaveSettings"):InvokeServer({
			practiceDifficulty = difficulty,
		})
	end)
end

hud.settings.onChange(function(state)
	applyAudio(state)
	queueSavePrefs()
end)

local function applyLoadedPrefs(prefs: Types.PlayerPrefs)
	writePrefAttrs(
		prefs.sfxVolume,
		prefs.sfxMuted,
		prefs.musicVolume,
		prefs.musicMuted,
		prefs.muteOthersEmotes,
		prefs.hideBoardName,
		prefs.practiceDifficulty
	)
	hud.settings.apply({
		sfxVolume = prefs.sfxVolume,
		sfxMuted = prefs.sfxMuted,
		musicVolume = prefs.musicVolume,
		musicMuted = prefs.musicMuted,
		muteOthersEmotes = prefs.muteOthersEmotes,
		hideBoardName = prefs.hideBoardName,
	})
	hud.lobby.setDifficulty(prefs.practiceDifficulty)
end

if loadedPrefs then
	applyLoadedPrefs(loadedPrefs)
end
persistReady = true

local gameMode: Types.GameMode = "Hub"
local hubPage: "grid" | "moba" = "grid"
local latestYarn: Types.YarnRunSnapshot? = nil
local latestKoi: Types.KoiPondSnapshot? = nil
local latestParty: Types.YarnPartySnapshot? = nil
local latestArcade: Types.ArcadeSnapshot? = nil
local latestMatch: Types.MatchSnapshot? = nil
local latestCombat: Types.CombatState? = nil
local juiceCombat: Types.CombatState? = nil
local tutorialDone = player:GetAttribute(Constants.Attributes.TutorialDone) == true

local function tutorialIsDone(): boolean
	return tutorialDone or player:GetAttribute(Constants.Attributes.TutorialDone) == true
end

local lastVision: Types.VisionFrame = { players = {}, minions = {}, jungle = {}, wards = {}, fogBits = {}, exploredBits = {} }
local lastKnownPos: { [number]: Vector3 } = {}
local applyVision: () -> () = function() end
local armedSlot: Types.AbilitySlot? = nil
local armedKind: "hold" | "ground" | nil = nil
local lastErrorAt = 0
local cameraArmed = false

local SLOT_KEYS: { [Enum.KeyCode]: Types.AbilitySlot } = {
	[Enum.KeyCode.Q] = "Q",
	[Enum.KeyCode.W] = "W",
	[Enum.KeyCode.E] = "E",
	[Enum.KeyCode.R] = "R",
}

local function inMini(): boolean
	return gameMode == "YarnRun" or gameMode == "KoiPond" or gameMode == "YarnParty" or gameMode == "MemeArcade"
end

local function toast(text: string)
	hud.banner(text)
end

local recentCallouts: { string } = {}

local function riftCalloutsOn(): boolean
	if inMini() then
		return false
	end
	return gameMode == "Moba"
end

local function rememberCallout(text: string, beat: string?)
	if beat == "Draft" or beat == "DraftPractice" then
		table.clear(recentCallouts)
	end
	table.insert(recentCallouts, text)
	while #recentCallouts > 6 do
		table.remove(recentCallouts, 1)
	end
end

local function seedCasterChat(npcId: string)
	if npcId ~= "KittyCaster" then
		return
	end
	for _, line in recentCallouts do
		hud.chat.append("Kitty Caster", line)
	end
end

local lastPartyNotice = 0
local function noteParty(queue: Types.QueueStatus)
	if typeof(queue.noticeId) == "number" and typeof(queue.notice) == "string" and queue.notice ~= "" and queue.noticeId ~= lastPartyNotice then
		lastPartyNotice = queue.noticeId
		toast(queue.notice)
	end
end

local function refreshRiftPeers()
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(list, { userId = other.UserId, name = other.DisplayName })
		end
	end
	table.sort(list, function(a, b)
		return a.userId < b.userId
	end)
	hud.lobby.setPeers(list)
end

local function refreshBars()
	if not latestMatch then
		return
	end
	local mine = latestMatch.players[tostring(player.UserId)]
	if not mine then
		return
	end
	hud.abilities.update(mine, latestCombat)
	if latestMatch.phase == "InProgress" then
		hud.economy.update(mine, latestMatch.riverEpic)
	end
	if hud.scoreboard.root.Visible then
		hud.scoreboard.update(latestMatch, player.UserId)
	end
end

local function refreshVoiceContext()
	local place: "Match" | "Hub" | "Stall" = "Hub"
	local selfTeam: string? = nil
	local seats: { { userId: number, team: string, isBot: boolean } } = {}
	if inMini() then
		place = "Stall"
	elseif gameMode == "Moba" and latestMatch and latestMatch.phase ~= "Lobby" then
		place = "Match"
		for _, matchPlayer in latestMatch.players do
			table.insert(seats, {
				userId = matchPlayer.userId,
				team = matchPlayer.team,
				isBot = matchPlayer.isBot == true,
			})
			if matchPlayer.userId == player.UserId then
				selfTeam = matchPlayer.team
			end
		end
	end
	hud.voice.setContext({
		place = place,
		selfTeam = selfTeam,
		seats = seats,
	})
end

type TapeQuote = {
	id: string,
	symbol: string,
	price: number,
	change: number,
}

local marketRows: { TapeQuote } = {}
local marketEnabled = true

local function ingestMarket(payload: any): { string }?
	if typeof(payload) ~= "table" then
		return nil
	end
	if (payload :: any).enabled == false then
		marketEnabled = false
	elseif (payload :: any).enabled == true then
		marketEnabled = true
	end
	local tickers = (payload :: any).tickers
	if typeof(tickers) ~= "table" then
		return {}
	end
	local rows: { TapeQuote } = {}
	for _, ticker in tickers do
		if typeof(ticker) == "table" then
			local quote = ticker :: any
			local id = quote.id
			local symbol = quote.symbol
			local price = quote.price
			local change = quote.change
			if typeof(id) == "string" and typeof(symbol) == "string" and typeof(price) == "number" and typeof(change) == "number" then
				table.insert(rows, {
					id = id,
					symbol = symbol,
					price = price,
					change = change,
				})
			end
		end
	end
	marketRows = rows
	local flash = {}
	local rawFlash = (payload :: any).flash
	if typeof(rawFlash) == "table" then
		for _, symbol in rawFlash do
			if typeof(symbol) == "string" then
				table.insert(flash, symbol)
			end
		end
	end
	return flash
end

local function riftTapeQuotes(): { TapeQuote }
	if not latestMatch then
		return {}
	end
	local want: { [string]: boolean } = {}
	for _, matchPlayer in latestMatch.players do
		if matchPlayer.championId then
			want[matchPlayer.championId] = true
		end
	end
	local rows: { TapeQuote } = {}
	for _, row in marketRows do
		if want[row.id] then
			table.insert(rows, row)
		end
	end
	table.sort(rows, function(a, b)
		return a.symbol < b.symbol
	end)
	return rows
end

local function paintMemeTape(flash: { string }?)
	local phase = if latestMatch then latestMatch.phase else nil
	local inRift = (not inMini()) and gameMode == "Moba" and marketEnabled and (phase == "InProgress" or phase == "Ended")
	if not inRift then
		hud.tape.setVisible(false)
		return
	end
	local rows = riftTapeQuotes()
	if #rows == 0 then
		hud.tape.setVisible(false)
		return
	end
	hud.tape.setVisible(true)
	hud.tape.setRows(rows, flash)
end

local function applyShellView()
	hud.applyShell(gameMode, hubPage, latestMatch, player.UserId)
	if gameMode == "YarnRun" then
		Music.setPhase("YarnRun")
		hud.help.setContext("runner")
		KoiCamera.setEnabled(false)
		YarnPartyCamera.setEnabled(false)
		ArcadeCamera.setEnabled(false)
		CameraFollow.setEnabled(false)
		cameraArmed = false
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			YarnCamera.setSubject(root)
		end
		YarnCamera.setEnabled(true)
		YarnCamera.setDeath(latestYarn ~= nil and latestYarn.phase == "Dead")
		if latestYarn then
			YarnGhost.update(latestYarn.ghostLane, latestYarn.ghostZ, latestYarn.ghostY, latestYarn.ghostAlive)
		end
	elseif gameMode == "KoiPond" then
		Music.setPhase("KoiPond")
		hud.help.setContext("koi")
		YarnCamera.setEnabled(false)
		YarnGhost.setVisible(false)
		YarnPartyCamera.setEnabled(false)
		ArcadeCamera.setEnabled(false)
		CameraFollow.setEnabled(false)
		cameraArmed = false
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			KoiCamera.setSubject(root)
		end
		KoiCamera.setEnabled(true)
	elseif gameMode == "YarnParty" then
		Music.setPhase("YarnParty")
		hud.help.setContext("party")
		YarnCamera.setEnabled(false)
		YarnGhost.setVisible(false)
		KoiCamera.setEnabled(false)
		ArcadeCamera.setEnabled(false)
		CameraFollow.setEnabled(false)
		cameraArmed = false
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			YarnPartyCamera.setSubject(root)
		end
		YarnPartyCamera.setEnabled(true)
	elseif gameMode == "MemeArcade" then
		Music.setPhase("MemeArcade")
		hud.help.setContext("arcade")
		YarnCamera.setEnabled(false)
		YarnGhost.setVisible(false)
		KoiCamera.setEnabled(false)
		YarnPartyCamera.setEnabled(false)
		ArcadeCamera.setEnabled(false)
		CameraFollow.setEnabled(false)
		cameraArmed = false
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			ArcadeCamera.setSubject(root)
		end
		ArcadeCamera.setEnabled(true)
	elseif gameMode == "Hub" and hubPage == "grid" and (latestMatch == nil or latestMatch.phase == "Lobby") then
		Music.setPhase("Hub")
		hud.help.setContext("hub")
		YarnCamera.setEnabled(false)
		YarnGhost.setVisible(false)
		KoiCamera.setEnabled(false)
		YarnPartyCamera.setEnabled(false)
		ArcadeCamera.setEnabled(false)
		CameraFollow.setEnabled(false)
		cameraArmed = false
	else
		YarnCamera.setEnabled(false)
		YarnGhost.setVisible(false)
		KoiCamera.setEnabled(false)
		YarnPartyCamera.setEnabled(false)
		ArcadeCamera.setEnabled(false)
		hud.help.setContext("moba")
		if latestMatch then
			Music.setPhase(latestMatch.phase)
		end
	end
	refreshVoiceContext()
	paintMemeTape(nil)
end

local function applySnapshot(snapshot: Types.MatchSnapshot?)
	if snapshot == nil then
		snapshot = Remotes.function_("GetMatchSnapshot"):InvokeServer()
	end
	if typeof(snapshot) ~= "table" then
		return
	end
	latestMatch = snapshot :: Types.MatchSnapshot
	if latestMatch.queue then
		noteParty(latestMatch.queue)
	end
	if not inMini() then
		if latestMatch.phase ~= "Lobby" then
			gameMode = "Moba"
			hubPage = "moba"
		elseif gameMode == "Moba" then
			gameMode = "Hub"
			hubPage = "grid"
		end
	end
	applyShellView()
	if not inMini() and latestMatch.phase ~= "Lobby" then
		hud.tips.sync(latestMatch, player.UserId, tutorialIsDone())
	end
	refreshBars()
	if inMini() then
		applyVision()
		return
	end
	if latestMatch.phase == "InProgress" then
		hud.minimap.update(latestMatch, lastVision, player.UserId)
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			CameraFollow.setSubject(root)
		end
		if not cameraArmed then
			CameraFollow.setEnabled(true)
			cameraArmed = true
		end
	else
		CameraFollow.setEnabled(false)
		cameraArmed = false
		armedSlot = nil
		armedKind = nil
		TargetingIndicator.hide()
		Sfx.stopLoop("RecallLoop")
	end
	applyVision()
end

-- WASD, arrows, jump, and the engine stick. W is also an ability; a fresh press is still a move order.
local MOVE_KEYS: { Enum.KeyCode } = {
	Enum.KeyCode.W,
	Enum.KeyCode.A,
	Enum.KeyCode.S,
	Enum.KeyCode.D,
	Enum.KeyCode.Up,
	Enum.KeyCode.Down,
	Enum.KeyCode.Left,
	Enum.KeyCode.Right,
	Enum.KeyCode.Space,
}

local recallLatch = {
	active = false,
	heldAtStart = false,
	sawRest = false,
}
local recallMoveSent = false
local stickControls: any = nil
local stickLookup = false

local function stickMoving(): boolean
	if not stickLookup then
		local scripts = player:FindFirstChild("PlayerScripts")
		if not scripts then
			return false
		end
		stickLookup = true
		local moduleScript = scripts:FindFirstChild("PlayerModule")
		if moduleScript and moduleScript:IsA("ModuleScript") then
			local ok, result = pcall(require, moduleScript)
			if ok and type(result) == "table" and type((result :: any).GetControls) == "function" then
				local okControls, controls = pcall(function()
					return (result :: any):GetControls()
				end)
				if okControls then
					stickControls = controls
				end
			end
		end
	end
	if type(stickControls) ~= "table" or type(stickControls.GetMoveVector) ~= "function" then
		return false
	end
	local ok, vec = pcall(function()
		return stickControls:GetMoveVector()
	end)
	if not ok or typeof(vec) ~= "Vector3" then
		return false
	end
	return vec.Magnitude > 0.2
end

local function keyboardMoving(): boolean
	if UserInputService:GetFocusedTextBox() then
		return false
	end
	for _, key in MOVE_KEYS do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

local function movementIntent(): boolean
	return keyboardMoving() or stickMoving()
end

local function channelActive(state: Types.CombatState): boolean
	local ends = state.channelEndsAt
	return ends ~= nil and ends > Workspace:GetServerTimeNow()
end

local function rootedChannel(state: Types.CombatState): boolean
	return state.recalling or channelActive(state)
end

local function noteRecallChannel(recalling: boolean)
	if recalling then
		if not recallLatch.active then
			recallLatch.active = true
			recallLatch.heldAtStart = movementIntent()
			recallLatch.sawRest = false
			recallMoveSent = false
		end
	else
		recallLatch.active = false
		recallLatch.heldAtStart = false
		recallLatch.sawRest = false
		recallMoveSent = false
	end
end

local function applyCombatJuice(state: Types.CombatState)
	noteRecallChannel(rootedChannel(state))
	local prev = juiceCombat
	juiceCombat = state
	if not prev then
		if state.recalling then
			Sfx.startLoop("RecallLoop")
			local remain = if state.recallEndsAt then state.recallEndsAt - Workspace:GetServerTimeNow() else 7
			CombatFx.localRecall(player.UserId, true, remain)
		end
		return
	end
	if state.health + 0.5 < prev.health then
		ScreenJuice.damageFlash()
	elseif state.health > prev.health + 4 then
		ScreenJuice.healFlash()
		Sfx.play("Heal")
	elseif state.attackTarget and state.nextAutoAttack > prev.nextAutoAttack + 0.05 then
		Sfx.play("AutoHit")
	end
	if state.level > prev.level then
		ScreenJuice.levelUp(state.level)
		Sfx.play("LevelUp")
	end
	if state.recalling and not prev.recalling then
		Sfx.startLoop("RecallLoop")
		local remain = if state.recallEndsAt then state.recallEndsAt - Workspace:GetServerTimeNow() else 7
		CombatFx.localRecall(player.UserId, true, remain)
	elseif not state.recalling and prev.recalling then
		Sfx.stopLoop("RecallLoop")
		CombatFx.localRecall(player.UserId, false, 0)
	end
end

hud.lobby.onQueue(function()
	local result = Remotes.function_("QueueMatch"):InvokeServer()
	if result and result.ok == false then
		hud.lobby.setQueued(false)
		toast(result.error or "Queue failed")
	end
	applySnapshot(Remotes.function_("GetMatchSnapshot"):InvokeServer())
end)

hud.lobby.onLeave(function()
	local result = Remotes.function_("LeaveQueue"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Could not leave queue")
	else
		hud.lobby.setQueued(false)
	end
	applySnapshot(Remotes.function_("GetMatchSnapshot"):InvokeServer())
end)

hud.lobby.onInvite(function()
	local result = Remotes.function_("InviteParty"):InvokeServer(hud.lobby.inviteUserId())
	if result and result.ok == false then
		toast(result.error or "Invite failed")
	end
	local queue = Remotes.function_("GetQueueStatus"):InvokeServer()
	if typeof(queue) == "table" then
		local status = queue :: Types.QueueStatus
		hud.lobby.updateQueue(status)
		noteParty(status)
	end
end)

hud.lobby.onAcceptInvite(function()
	local result = Remotes.function_("AcceptPartyInvite"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Could not accept")
	end
end)

hud.lobby.onDeclineInvite(function()
	local result = Remotes.function_("DeclinePartyInvite"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Could not decline")
	end
end)

hud.lobby.onLeaveParty(function()
	local result = Remotes.function_("LeaveParty"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Could not leave the party")
	end
end)

refreshRiftPeers()
Players.PlayerAdded:Connect(refreshRiftPeers)
Players.PlayerRemoving:Connect(function()
	task.defer(refreshRiftPeers)
end)

hud.lobby.onDifficulty(function(difficulty)
	player:SetAttribute(Constants.Attributes.PracticeDifficulty, difficulty)
	saveDifficulty(difficulty)
end)

hud.lobby.onPractice(function(difficulty)
	player:SetAttribute(Constants.Attributes.PracticeDifficulty, difficulty)
	task.spawn(function()
		saveDifficulty(difficulty)
	end)
	local result = Remotes.function_("StartPractice"):InvokeServer(difficulty)
	if result and result.ok == false then
		toast(result.error or "Practice failed")
	end
end)

hud.lobby.onShowTips(function()
	hud.tips.replay()
end)

hud.lobby.onBack(function()
	hubPage = "grid"
	gameMode = "Hub"
	applyShellView()
end)

hud.hub.onTalk(function(hostId, hostName)
	hud.chat.open(hostId, hostName)
end)

hud.hub.onPlayRift(function()
	hubPage = "moba"
	gameMode = "Hub"
	refreshRiftPeers()
	applyShellView()
end)

hud.hub.onPlayRun(function(championId)
	local result = Remotes.function_("StartYarnRun"):InvokeServer(championId)
	if result and result.ok == false then
		toast(result.error or "Yarn Run failed")
		return
	end
	gameMode = "YarnRun"
	applyShellView()
end)

hud.hub.onPlayPond(function()
	local result = Remotes.function_("StartKoiPond"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Koi Pond failed")
		return
	end
	gameMode = "KoiPond"
	applyShellView()
end)

hud.hub.onPlayParty(function()
	local result = Remotes.function_("StartYarnParty"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Yarn Party failed")
		return
	end
	gameMode = "YarnParty"
	applyShellView()
end)

hud.hub.onPlayArcade(function()
	local result = Remotes.function_("StartMemeArcade"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Arcade failed")
		return
	end
	gameMode = "MemeArcade"
	applyShellView()
end)

hud.hub.onMint(function()
	hud.hub.dismissPublish()
	hud.closet.setVisible(false)
	hud.mint.toggle()
end)

local function refreshCloset()
	local nextStatus = Remotes.function_("GetCloset"):InvokeServer()
	if typeof(nextStatus) == "table" then
		hud.closet.update(nextStatus :: Types.ClosetStatus)
	end
end

local function applyClosetToast(status: Types.ClosetStatus)
	local line = status.toast
	if typeof(line) ~= "string" or line == "" then
		return
	end
	hud.ticker(line)
	toast(line)
	if string.find(line, "UNLOCKED", 1, true) then
		ScreenJuice.banner(line, Color3.fromRGB(255, 196, 74))
		Sfx.play("LevelUp")
	elseif string.find(line, "EQUIPPED", 1, true) or string.find(line, "BOUGHT", 1, true) then
		Sfx.play("ShopBuy")
	end
end

hud.hub.onCloset(function()
	hud.hub.dismissPublish()
	hud.mint.setVisible(false)
	hud.closet.toggle()
	if hud.closet.root.Visible then
		refreshCloset()
	end
end)

local publishFetch = 0
hud.hub.onLive(function()
	hud.mint.setVisible(false)
	hud.closet.setVisible(false)
	publishFetch += 1
	local generation = publishFetch
	task.spawn(function()
		local ok, result = pcall(function()
			return Remotes.function_("GetPublishReadiness"):InvokeServer()
		end)
		if generation ~= publishFetch then
			return
		end
		if ok and typeof(result) == "table" then
			hud.hub.applyPublish(result)
		else
			hud.hub.showPublishError("Could not read the server checklist. Play is not blocked. See PLAYTEST §7.")
		end
	end)
end)

hud.closet.onEquip(function(id, slot)
	local result = Remotes.function_("EquipCosmetic"):InvokeServer({ id = id, slot = slot })
	if result and result.ok == false then
		toast(result.error or "Could not equip")
	end
end)

hud.closet.onUnequip(function(slot)
	local result = Remotes.function_("EquipCosmetic"):InvokeServer({ id = "", slot = slot })
	if result and result.ok == false then
		toast(result.error or "Could not unequip")
	end
end)

hud.closet.onBuy(function(id)
	local result = Remotes.function_("BuyCosmetic"):InvokeServer(id)
	if result and result.ok == false then
		toast(result.error or "Could not buy")
	end
end)

local function applyYarnBoards(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	if typeof(payload.daily) == "table" and typeof(payload.weekly) == "table" then
		local boards = payload :: Types.YarnBoards
		hud.board.update(boards)
		hud.hub.updateBoard(boards.daily)
	elseif typeof(payload.entries) == "table" then
		local board = payload :: Types.YarnBoard
		hud.board.updateDaily(board)
		hud.hub.updateBoard(board)
	end
end

local function applyStallBoard(payload: any): Types.StallBoard?
	if typeof(payload) ~= "table" or typeof(payload.entries) ~= "table" then
		return nil
	end
	return payload :: Types.StallBoard
end

local function refreshYarnBoard()
	local ok, board = pcall(function()
		return Remotes.function_("GetYarnBoard"):InvokeServer()
	end)
	if ok then
		applyYarnBoards(board)
	end
end

local function refreshKoiBoard()
	local ok, board = pcall(function()
		return Remotes.function_("GetKoiBoard"):InvokeServer()
	end)
	if ok then
		local stall = applyStallBoard(board)
		if stall then
			hud.koiBoard.update(stall)
			hud.hub.updateKoiBoard(stall)
		end
	end
end

local function refreshArcadeBoard()
	local ok, board = pcall(function()
		return Remotes.function_("GetArcadeBoard"):InvokeServer()
	end)
	if ok then
		local stall = applyStallBoard(board)
		if stall then
			hud.arcadeBoard.update(stall)
			hud.hub.updateArcadeBoard(stall)
		end
	end
end

local function openYarnBoard()
	hud.koiBoard.setVisible(false)
	hud.arcadeBoard.setVisible(false)
	refreshYarnBoard()
	hud.board.setVisible(true)
end

local function openKoiBoard()
	hud.board.setVisible(false)
	hud.arcadeBoard.setVisible(false)
	refreshKoiBoard()
	hud.koiBoard.setVisible(true)
end

local function openArcadeBoard()
	hud.board.setVisible(false)
	hud.koiBoard.setVisible(false)
	refreshArcadeBoard()
	hud.arcadeBoard.setVisible(true)
end

hud.hub.onBoard(openYarnBoard)
hud.hub.onKoiBoard(openKoiBoard)
hud.hub.onArcadeBoard(openArcadeBoard)
hud.yarn.onBoard(openYarnBoard)
hud.koi.onBoard(openKoiBoard)
hud.arcade.onBoard(openArcadeBoard)

hud.yarn.onRetry(function()
	local result = Remotes.function_("RetryYarnRun"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Retry failed")
	end
end)

hud.yarn.onHub(function()
	local result = Remotes.function_("LeaveYarnRun"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Could not leave Yarn Run")
	end
	gameMode = "Hub"
	hubPage = "grid"
	latestYarn = nil
	hud.board.setVisible(false)
	applyShellView()
	refreshYarnBoard()
end)

hud.koi.onHub(function()
	local result = Remotes.function_("LeaveKoiPond"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Could not leave the pond")
	end
	gameMode = "Hub"
	hubPage = "grid"
	latestKoi = nil
	hud.koiBoard.setVisible(false)
	applyShellView()
	refreshKoiBoard()
end)

hud.party.onHub(function()
	local result = Remotes.function_("LeaveYarnParty"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Could not leave Yarn Party")
	end
	gameMode = "Hub"
	hubPage = "grid"
	latestParty = nil
	applyShellView()
end)

hud.party.onRetry(function()
	local result = Remotes.function_("RetryYarnParty"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Party retry failed")
	end
end)

hud.arcade.onHub(function()
	local result = Remotes.function_("LeaveMemeArcade"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Could not leave the arcade")
	end
	gameMode = "Hub"
	hubPage = "grid"
	latestArcade = nil
	hud.arcadeBoard.setVisible(false)
	applyShellView()
	refreshArcadeBoard()
end)

hud.arcade.onRetry(function()
	local result = Remotes.function_("RetryMemeArcade"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Arcade retry failed")
	end
end)

hud.arcade.onTrade(function(tickerId, action)
	task.spawn(function()
		local result = Remotes.function_("MemeArcadeInput"):InvokeServer({
			tickerId = tickerId,
			action = action,
		})
		if result and result.ok == false and typeof(result.error) == "string" then
			toast(result.error)
		end
	end)
end)

hud.tips.onDismissed(function(permanent: boolean)
	if not permanent then
		return
	end
	tutorialDone = true
	player:SetAttribute(Constants.Attributes.TutorialDone, true)
	task.spawn(function()
		Remotes.function_("SetTutorialDone"):InvokeServer()
	end)
end)

hud.endScreen.onLobby(function()
	local result = Remotes.function_("LeaveMatch"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Could not return to lobby")
	end
	applySnapshot(Remotes.function_("GetMatchSnapshot"):InvokeServer())
end)

hud.endScreen.onPractice(function()
	local result = Remotes.function_("PlayAgain"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Practice failed")
	end
	applySnapshot(Remotes.function_("GetMatchSnapshot"):InvokeServer())
end)

hud.lobby.onMint(function()
	hud.closet.setVisible(false)
	hud.mint.toggle()
end)

hud.lobby.onCloset(function()
	hud.mint.setVisible(false)
	hud.closet.toggle()
	if hud.closet.root.Visible then
		refreshCloset()
	end
end)

local function refreshMint()
	local nextStatus = Remotes.function_("GetMintStatus"):InvokeServer()
	if typeof(nextStatus) == "table" then
		hud.mint.update(nextStatus :: Types.MintStatus)
	end
end

hud.mint.onBuy(function()
	local status = Remotes.function_("GetMintStatus"):InvokeServer()
	if typeof(status) == "table" and typeof((status :: any).productId) == "number" and (status :: any).productId > 0 then
		MarketplaceService:PromptProductPurchase(player, (status :: any).productId)
		toast("Roblox purchase prompt — this is a Developer Product, not a chain swap")
		return
	end
	local result = Remotes.function_("SimulateStudioPurchase"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Mock entitlement failed")
	else
		toast("Studio entitlement granted. Link a wallet, then Claim 404.")
	end
	refreshMint()
end)

hud.mint.onLink(function(address: string)
	local result = Remotes.function_("LinkWallet"):InvokeServer(address)
	if result and result.ok == false then
		toast(result.error or "Wallet link failed — need 0x + 40 hex chars")
	else
		toast("Address saved unverified. Request a SIWE challenge next.")
	end
	refreshMint()
end)

hud.mint.onChallenge(function()
	local result = Remotes.function_("RequestSiweChallenge"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "SIWE challenge failed")
	else
		toast("Sign the message in an external wallet — or paste studio-bypass in Studio")
	end
	refreshMint()
end)

hud.mint.onVerify(function(signature: string)
	local result = Remotes.function_("VerifySiwe"):InvokeServer(signature)
	if result and result.ok == false then
		toast(result.error or "SIWE verify failed")
	else
		toast("Wallet SIWE-verified. Server stored the recovered address only.")
	end
	refreshMint()
end)

hud.mint.onClaim(function(purchaseId: string)
	local result = Remotes.function_("ClaimMeo404"):InvokeServer(purchaseId)
	if result and result.ok == false then
		toast(result.error or "Claim failed — tap Retry claim")
	else
		toast("Claim ok. Already-claimed is retry-safe. Live mint is hosted.")
	end
	refreshMint()
end)

hud.mint.onReplay(function(purchaseId: string)
	local result = Remotes.function_("ReplayReceipt"):InvokeServer(purchaseId)
	if result and result.ok == false then
		toast(result.error or "Receipt replay failed")
	else
		toast("Receipt replayed (idempotent GrantProduct). No extra Robux.")
	end
	refreshMint()
end)

hud.select.onPick(function(championId: string)
	local result = Remotes.function_("SelectChampion"):InvokeServer(championId)
	if result and result.ok == false then
		toast(result.error or "Could not lock that cat")
	end
end)

hud.shop.onBuy(function(itemId: string)
	local result = Remotes.function_("BuyItem"):InvokeServer(itemId)
	if result and result.ok == false then
		toast(result.error or "Shop said no")
	else
		Sfx.play("ShopBuy")
		toast("Pawmart thanks you for your gold")
	end
	local status = Remotes.function_("GetShopStatus"):InvokeServer()
	if typeof(status) == "table" then
		hud.shop.update(status :: Types.ShopStatus)
	end
end)

hud.chat.onSend(function(npcId: string, text: string, reply: (string, string) -> ())
	local ok, result = pcall(function()
		return Remotes.function_("ChatWithNpc"):InvokeServer(npcId, text)
	end)
	if not ok then
		reply("System", "That meow got lost. Try again.")
	elseif typeof(result) == "table" then
		if result.ok and typeof(result.reply) == "string" then
			reply(result.speaker or "Cat", result.reply)
		elseif typeof(result.error) == "string" then
			reply("System", result.error)
		end
	end
end)

Remotes.event("MatchStateChanged").OnClientEvent:Connect(function(snapshot)
	applySnapshot(snapshot)
end)

Remotes.event("ModeChanged").OnClientEvent:Connect(function(status)
	if typeof(status) ~= "table" then
		return
	end
	local hub = status :: Types.HubStatus
	if hub.mode == "Hub" or hub.mode == "Moba" or hub.mode == "YarnRun" or hub.mode == "KoiPond" or hub.mode == "YarnParty" or hub.mode == "MemeArcade" then
		gameMode = hub.mode
	end
	if gameMode == "Hub" and hubPage == "moba" then
		-- stay on the Cat Rift stall until they hit ← Hub
	elseif gameMode == "Hub" then
		hubPage = "grid"
	end
	hud.hub.update(hub)
	applyShellView()
end)

local lastYarnEvent: string? = nil
local lastYarnPhase: Types.YarnRunPhase? = nil

Remotes.event("YarnRunUpdated").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local snap = payload :: Types.YarnRunSnapshot
	latestYarn = snap
	gameMode = "YarnRun"
	hud.yarn.update(snap)
	YarnGhost.update(snap.ghostLane, snap.ghostZ, snap.ghostY, snap.ghostAlive)
	if lastYarnPhase ~= "Running" then
		applyShellView()
	end
	if snap.event and snap.event ~= lastYarnEvent then
		if snap.event == "YARN" or snap.event == "MEGA YARN" or snap.event == "ROOMBA RAIL" then
			Sfx.play("ShopBuy")
		elseif snap.event == "COMBO BREAK" then
			Sfx.play("Kill")
			ScreenJuice.comboBreak()
		elseif string.find(snap.event, "COMBO x", 1, true) == 1 then
			Sfx.play("LevelUp")
		elseif snap.event == "GO GO YARN" then
			Sfx.play("MatchFound")
		elseif snap.event == "SPEED BURST" then
			Sfx.play("LevelUp")
			ScreenJuice.powerFlash(Color3.fromRGB(90, 220, 255))
		elseif snap.event == "MAGNET ON" then
			Sfx.play("ShopBuy")
			ScreenJuice.powerFlash(Color3.fromRGB(220, 90, 210))
		elseif snap.event == "MAGNET YARN" then
			Sfx.play("ShopBuy")
		elseif snap.event == "SHIELD UP" then
			Sfx.play("LevelUp")
			ScreenJuice.healFlash()
		elseif snap.event == "SHIELD POP" then
			Sfx.play("Kill")
			ScreenJuice.damageFlash()
		elseif snap.event == "2X YARN" then
			Sfx.play("LevelUp")
			ScreenJuice.powerFlash(Color3.fromRGB(255, 196, 74))
		elseif snap.event == "CLOSE!" then
			ScreenJuice.nearMiss()
		elseif snap.event == "NEW PB" then
			Sfx.play("MatchFound")
			ScreenJuice.banner("NEW PB", Color3.fromRGB(255, 196, 74))
		elseif snap.event == "BEAT YOUR GHOST" then
			Sfx.play("LevelUp")
			ScreenJuice.banner("BEAT YOUR GHOST", Color3.fromRGB(255, 196, 74))
		elseif snap.event == "#1 YARN LORD" then
			Sfx.play("MatchFound")
			ScreenJuice.banner("#1 YARN LORD", Color3.fromRGB(255, 196, 74))
			ScreenJuice.powerFlash(Color3.fromRGB(255, 196, 74))
		elseif snap.event == "#2 YARN ACE" then
			Sfx.play("LevelUp")
			ScreenJuice.banner("#2 YARN ACE", Color3.fromRGB(255, 184, 140))
		elseif snap.event == "#3 YARN CREW" then
			Sfx.play("LevelUp")
			ScreenJuice.banner("#3 YARN CREW", Color3.fromRGB(120, 196, 150))
		elseif snap.event and string.find(snap.event, "DAILY #", 1, true) == 1 then
			ScreenJuice.banner(snap.event, Color3.fromRGB(255, 243, 224))
		end
	end
	if snap.phase == "Dead" and lastYarnPhase ~= "Dead" then
		Sfx.play("Kill")
		YarnCamera.setDeath(true)
		if snap.event ~= "COMBO BREAK" then
			ScreenJuice.damageFlash()
		end
		applyShellView()
	elseif snap.phase == "Running" then
		YarnCamera.setDeath(false)
	end
	if snap.phase == "Dead" and (snap.dailyRank ~= nil or snap.weeklyRank ~= nil) then
		task.defer(refreshYarnBoard)
	end
	lastYarnEvent = snap.event
	lastYarnPhase = snap.phase
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		YarnCamera.setSubject(root)
	end
end)

Remotes.event("YarnBoardUpdated").OnClientEvent:Connect(function(payload)
	applyYarnBoards(payload)
end)

Remotes.event("KoiBoardUpdated").OnClientEvent:Connect(function(payload)
	local stall = applyStallBoard(payload)
	if stall then
		hud.koiBoard.update(stall)
		hud.hub.updateKoiBoard(stall)
	end
end)

Remotes.event("ArcadeBoardUpdated").OnClientEvent:Connect(function(payload)
	local stall = applyStallBoard(payload)
	if stall then
		hud.arcadeBoard.update(stall)
		hud.hub.updateArcadeBoard(stall)
	end
end)

local lastKoiEvent: string? = nil
local lastKoiPhase: Types.KoiPondPhase? = nil

Remotes.event("KoiPondUpdated").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local snap = payload :: Types.KoiPondSnapshot
	latestKoi = snap
	gameMode = "KoiPond"
	hud.koi.update(snap)
	if lastKoiPhase ~= snap.phase then
		applyShellView()
	end
	if snap.event and snap.event ~= lastKoiEvent then
		if snap.event == "LEGENDARY KOI" then
			Sfx.play("MatchFound")
			ScreenJuice.banner("LEGENDARY KOI", Color3.fromRGB(255, 122, 98))
			ScreenJuice.powerFlash(Color3.fromRGB(255, 122, 98))
			hud.ticker("LEGENDARY KOI · coral crown loaf")
		elseif snap.lastCatchRarity == "Epic" then
			Sfx.play("LevelUp")
			ScreenJuice.banner(snap.lastCatchName or "Amber Lantern", Color3.fromRGB(255, 196, 74))
			ScreenJuice.powerFlash(Color3.fromRGB(255, 196, 74))
		elseif snap.lastCatchName then
			Sfx.play("ShopBuy")
			ScreenJuice.banner(snap.lastCatchName, Color3.fromRGB(255, 184, 140))
		elseif snap.missReason then
			Sfx.play("Kill")
		elseif snap.event == "Nibble — reel the cream window" then
			Sfx.play("WardPlace")
		elseif snap.event == "Yarn's in the drink" then
			Sfx.play("AbilityCast")
		end
	end
	lastKoiEvent = snap.event
	lastKoiPhase = snap.phase
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		KoiCamera.setSubject(root)
	end
end)

local lastPartyEvent: string? = nil
local lastPartyPhase: Types.YarnPartyPhase? = nil

Remotes.event("YarnPartyUpdated").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local snap = payload :: Types.YarnPartySnapshot
	latestParty = snap
	gameMode = "YarnParty"
	hud.party.update(snap, player.UserId)
	if lastPartyPhase ~= snap.phase then
		applyShellView()
	end
	if snap.event and snap.event ~= lastPartyEvent then
		if string.find(snap.event, "CROWNED", 1, true) then
			Sfx.play("MatchFound")
			ScreenJuice.banner(snap.event, Color3.fromRGB(255, 196, 74))
			ScreenJuice.powerFlash(Color3.fromRGB(255, 196, 74))
			hud.ticker(`YARN PARTY · {snap.winnerName or "loaf"} crowned`)
		elseif snap.event == "YARN DODGE" or snap.event == "STALL FREEZE" then
			Sfx.play("LevelUp")
			ScreenJuice.banner(snap.event, Color3.fromRGB(255, 122, 98))
		elseif snap.event == "GO" then
			Sfx.play("MatchFound")
		elseif string.find(snap.event, "took seat", 1, true) then
			Sfx.play("LevelUp")
			ScreenJuice.banner(snap.event, Color3.fromRGB(255, 196, 74))
		elseif string.find(snap.event, "YARN BONK", 1, true) or string.find(snap.event, "WRONG PILLOW", 1, true) then
			Sfx.play("Kill")
			ScreenJuice.damageFlash()
		end
	end
	lastPartyEvent = snap.event
	lastPartyPhase = snap.phase
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		YarnPartyCamera.setSubject(root)
	end
end)

local lastArcadeEvent: string? = nil
local lastArcadePhase: Types.ArcadePhase? = nil
local lastArcadeProfit: number? = nil

Remotes.event("MemeArcadeUpdated").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local snap = payload :: Types.ArcadeSnapshot
	latestArcade = snap
	gameMode = "MemeArcade"
	hud.arcade.update(snap)
	if lastArcadePhase ~= snap.phase then
		applyShellView()
	end
	if snap.eventBanner ~= "" and snap.eventBanner ~= lastArcadeEvent then
		if snap.eventKind == "rug" or string.find(snap.eventBanner, "RUG", 1, true) then
			Sfx.play("Kill")
			ScreenJuice.banner(snap.eventBanner, Color3.fromRGB(255, 122, 98))
			ScreenJuice.damageFlash()
			hud.ticker(snap.eventBanner)
		elseif snap.eventKind == "moon" or string.find(snap.eventBanner, "MOON", 1, true) then
			Sfx.play("MatchFound")
			ScreenJuice.banner(snap.eventBanner, Color3.fromRGB(120, 196, 150))
			ScreenJuice.powerFlash(Color3.fromRGB(96, 196, 120))
			hud.ticker(snap.eventBanner)
		elseif snap.eventKind == "sneeze" or string.find(snap.eventBanner, "WHALE", 1, true) then
			Sfx.play("LevelUp")
			ScreenJuice.banner(snap.eventBanner, Color3.fromRGB(255, 196, 74))
			hud.ticker(snap.eventBanner)
		elseif snap.phase == "Settled" then
			Sfx.play("MatchFound")
			ScreenJuice.banner(snap.eventBanner, if snap.profit >= 0 then Color3.fromRGB(96, 196, 120) else Color3.fromRGB(255, 122, 98))
		end
	end
	if lastArcadeProfit ~= nil and snap.profit ~= lastArcadeProfit then
		if snap.profit > lastArcadeProfit then
			ScreenJuice.healFlash()
		elseif snap.profit < lastArcadeProfit then
			ScreenJuice.damageFlash()
		end
	end
	lastArcadeEvent = snap.eventBanner
	lastArcadePhase = snap.phase
	lastArcadeProfit = snap.profit
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		ArcadeCamera.setSubject(root)
	end
end)

Remotes.event("QueueUpdated").OnClientEvent:Connect(function(status)
	if typeof(status) ~= "table" then
		return
	end
	local queue = status :: Types.QueueStatus
	hud.lobby.updateQueue(queue)
	noteParty(queue)
	if queue.phase == "Found" then
		Sfx.play("MatchFound")
		Music.duck(1.8)
		toast(if queue.mode == "InPlace" then "Match found — in-place" else "Match found!")
	elseif queue.phase == "Teleporting" then
		toast("Teleporting to the rift…")
	end
end)

Remotes.event("CombatUpdated").OnClientEvent:Connect(function(state)
	if typeof(state) == "table" then
		latestCombat = state :: Types.CombatState
		applyCombatJuice(latestCombat)
		refreshBars()
		if latestCombat.alive == false then
			hud.emotes.close()
		else
			hud.recap.hide()
		end
	end
end)

Remotes.event("EmotePlayed").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local event = payload :: Types.EmoteEvent
	if typeof(event.userId) ~= "number" or typeof(event.emoteId) ~= "string" then
		return
	end
	local muteSfx = muteOthersEmotes and event.userId ~= player.UserId
	-- Server Closet loadout is authoritative; attributes are a fallback for older payloads.
	local tint: Color3? = if typeof(event.flairTint) == "Color3" then event.flairTint else nil
	if tint == nil then
		local who = if event.userId == player.UserId then player else Players:GetPlayerByUserId(event.userId)
		if who then
			tint = CosmeticCatalog.emoteTint(
				who:GetAttribute(Constants.Attributes.CosmeticHat) :: any,
				who:GetAttribute(Constants.Attributes.CosmeticTrail) :: any
			)
		end
	end
	EmoteFx.play(event, { muteSfx = muteSfx, tint = tint })
end)

Remotes.event("VoiceStatusChanged").OnClientEvent:Connect(function(status)
	if typeof(status) == "table" then
		hud.voice.update(status :: Types.VoiceStatus)
	end
end)

Remotes.event("AnnouncerMessage").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof((payload :: any).text) ~= "string" then
		return
	end
	if not riftCalloutsOn() then
		return
	end
	local text = (payload :: any).text :: string
	local beat = if typeof((payload :: any).beat) == "string" then (payload :: any).beat :: string else nil
	local speaker = if typeof((payload :: any).speaker) == "string" then (payload :: any).speaker :: string else "Kitty Caster"
	local line = `{speaker}: {text}`
	hud.callout(line)
	hud.feed.push({
		kind = "announce",
		text = line,
		at = os.clock(),
	})
	hud.chat.note(speaker, text)
	rememberCallout(text, beat)
	local explicit = (payload :: any).cue
	if explicit == "Announcer" then
		Sfx.play("Announcer")
	elseif explicit == "MatchFound" then
		Sfx.play("MatchFound")
	elseif beat == nil then
		local cue = Sfx.cueForAnnouncer(text)
		if cue then
			Sfx.play(cue)
		end
	end
end)

Remotes.event("CombatFx").OnClientEvent:Connect(function(payload)
	CombatFx.playUnknown(payload)
end)

Remotes.event("DeathRecap").OnClientEvent:Connect(function(payload)
	if gameMode ~= "Moba" or not latestMatch or latestMatch.phase ~= "InProgress" then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end
	local raw = payload :: Types.DeathRecap
	if raw.victimUserId ~= player.UserId or typeof(raw.lines) ~= "table" then
		return
	end
	local lines: { Types.DamageLine } = {}
	for _, item in raw.lines do
		if
			typeof(item) == "table"
			and typeof(item.sourceKind) == "string"
			and typeof(item.sourceName) == "string"
			and typeof(item.label) == "string"
			and typeof(item.amount) == "number"
		then
			table.insert(lines, {
				sourceKind = item.sourceKind,
				sourceName = item.sourceName,
				sourceId = if typeof(item.sourceId) == "string" then item.sourceId else nil,
				label = item.label,
				amount = item.amount,
				killingBlow = item.killingBlow == true,
				at = if typeof(item.at) == "number" then item.at else 0,
			})
		end
	end
	hud.recap.show({
		victimUserId = player.UserId,
		respawnAt = if typeof(raw.respawnAt) == "number" then raw.respawnAt else nil,
		lines = lines,
	})
end)

Remotes.event("KillFeed").OnClientEvent:Connect(function(event)
	if typeof(event) == "table" and typeof((event :: any).text) == "string" then
		local feed = event :: Types.FeedEvent
		hud.feed.push(feed)
		local cue = Sfx.cueForFeed(feed.kind)
		if cue then
			Sfx.play(cue)
		end
		if feed.kind == "nexus" then
			Music.duck(2.2)
		end
		if feed.kind == "tower" then
			ScreenJuice.shakeTower()
			if latestMatch and latestMatch.practice then
				hud.tips.notifyTower()
			end
		elseif feed.kind == "nexus" then
			ScreenJuice.shakeNexus()
		end
	end
end)

Remotes.event("MintStatusChanged").OnClientEvent:Connect(function(status)
	if typeof(status) == "table" then
		hud.mint.update(status :: Types.MintStatus)
	end
end)

Remotes.event("ClosetUpdated").OnClientEvent:Connect(function(status)
	if typeof(status) == "table" then
		local row = status :: Types.ClosetStatus
		hud.closet.update(row)
		applyClosetToast(row)
	end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(_userId, _productId, _isPurchased)
	task.defer(function()
		local status = Remotes.function_("GetMintStatus"):InvokeServer()
		if typeof(status) == "table" then
			hud.mint.update(status :: Types.MintStatus)
		end
	end)
end)

Remotes.event("ShopUpdated").OnClientEvent:Connect(function(status)
	if typeof(status) == "table" then
		hud.shop.update(status :: Types.ShopStatus)
	end
end)

local visionArmed = false

local function setHidden(inst: Instance, hidden: boolean)
	if inst:IsA("BasePart") then
		inst.LocalTransparencyModifier = if hidden then 1 else 0
	elseif inst:IsA("BillboardGui") or inst:IsA("Highlight") then
		inst.Enabled = not hidden
	end
end

local function hideTree(root: Instance, hidden: boolean)
	if root:IsA("BasePart") or root:IsA("BillboardGui") or root:IsA("Highlight") then
		setHidden(root, hidden)
	end
	for _, inst in root:GetDescendants() do
		setHidden(inst, hidden)
	end
end

-- Enemy left the visible set: ghost uses the last seen() pose and is not parented
-- to the live model. Coming back into vision clears that ghost immediately.
local function presentEnemy(key: string, source: Instance, show: boolean)
	if show then
		LastSeenGhosts.seen(key, source)
		hideTree(source, false)
	else
		LastSeenGhosts.lost(key, source)
		hideTree(source, true)
	end
end

local function rememberChampion(userId: number, model: Model)
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		lastKnownPos[userId] = rootPart.Position
	end
end

local function restoreAllVision()
	for _, other in Players:GetPlayers() do
		if other.Character then
			hideTree(other.Character, false)
		end
	end
	local map = Workspace:FindFirstChild(Constants.MapFolderName)
	if not map then
		return
	end
	for _, folderName in { "Bots", "Minions", "Jungle", "Wards" } do
		local folder = map:FindFirstChild(folderName)
		if folder then
			for _, child in folder:GetChildren() do
				hideTree(child, false)
			end
		end
	end
end

applyVision = function()
	local snapshot = latestMatch
	local active = snapshot ~= nil and snapshot.phase == "InProgress" and not inMini()
	if not active then
		if visionArmed then
			FogOfWar.setEnabled(false)
			FogOfWar.resetExplored()
			LastSeenGhosts.clear()
			table.clear(lastKnownPos)
			restoreAllVision()
			visionArmed = false
		end
		return
	end
	visionArmed = true
	FogOfWar.setEnabled(true)
	FogOfWar.apply(lastVision.fogBits, lastVision.exploredBits)

	local mine = snapshot.players[tostring(player.UserId)]
	local visiblePlayers: { [number]: boolean } = { [player.UserId] = true }
	for _, userId in lastVision.players do
		visiblePlayers[userId] = true
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			local show = visiblePlayers[other.UserId] == true
			local otherMatch = snapshot.players[tostring(other.UserId)]
			local enemy = mine ~= nil and otherMatch ~= nil and otherMatch.team ~= mine.team
			if enemy then
				presentEnemy(`p:{other.UserId}`, other.Character, show)
			else
				hideTree(other.Character, not show)
			end
			if show then
				rememberChampion(other.UserId, other.Character)
			end
		end
	end

	local map = Workspace:FindFirstChild(Constants.MapFolderName)

	local botsFolder = if map then map:FindFirstChild("Bots") else nil
	if botsFolder then
		for _, child in botsFolder:GetChildren() do
			if child:IsA("Model") then
				local userId = child:GetAttribute(Constants.Attributes.UserId)
				local otherMatch = if typeof(userId) == "number" then snapshot.players[tostring(userId)] else nil
				local ally = mine ~= nil and otherMatch ~= nil and otherMatch.team == mine.team
				local show = ally or (typeof(userId) == "number" and visiblePlayers[userId] == true)
				local enemy = typeof(userId) == "number" and mine ~= nil and otherMatch ~= nil and otherMatch.team ~= mine.team
				if enemy and typeof(userId) == "number" then
					presentEnemy(`p:{userId}`, child, visiblePlayers[userId] == true)
				else
					hideTree(child, not show)
				end
				if show and typeof(userId) == "number" then
					rememberChampion(userId, child)
				end
			end
		end
	end

	local folder = if map then map:FindFirstChild("Minions") else nil
	if folder then
		local visibleMinions: { [string]: boolean } = {}
		for _, id in lastVision.minions do
			visibleMinions[id] = true
		end
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				local team = child:GetAttribute(Constants.Attributes.Team)
				local ally = mine ~= nil and team == mine.team
				if ally then
					hideTree(child, false)
				else
					presentEnemy(`m:{child.Name}`, child, visibleMinions[child.Name] == true)
				end
			end
		end
	end

	local jungle = if map then map:FindFirstChild("Jungle") else nil
	if jungle then
		local visibleJungle: { [string]: boolean } = {}
		for _, id in (lastVision.jungle or {}) do
			visibleJungle[id] = true
		end
		for _, child in jungle:GetChildren() do
			if child:IsA("BasePart") then
				presentEnemy(`j:{child.Name}`, child, visibleJungle[child.Name] == true)
			end
		end
	end

	local wards = if map then map:FindFirstChild("Wards") else nil
	if wards then
		local visibleWards: { [string]: boolean } = {}
		for _, id in (lastVision.wards or {}) do
			visibleWards[id] = true
		end
		for _, child in wards:GetChildren() do
			if child:IsA("BasePart") then
				local team = child:GetAttribute(Constants.Attributes.Team)
				local ally = mine ~= nil and team == mine.team
				local show = ally or visibleWards[child.Name] == true
				hideTree(child, not show)
			end
		end
	end
end

Remotes.event("VisionUpdated").OnClientEvent:Connect(function(frame)
	if typeof(frame) == "table" then
		local incoming = frame :: Types.VisionFrame
		if incoming.jungle == nil then
			incoming.jungle = {}
		end
		if incoming.wards == nil then
			incoming.wards = {}
		end
		if incoming.fogBits == nil then
			incoming.fogBits = {}
		end
		if incoming.exploredBits == nil then
			incoming.exploredBits = {}
		end
		lastVision = incoming
		applyVision()
		if latestMatch and latestMatch.phase == "InProgress" then
			hud.minimap.update(latestMatch, lastVision, player.UserId)
		end
	end
end)

local lastPingSend = 0
local lastPingAttempt = 0
local lastPingRefuse = 0

local function sendPing(kind: string, position: Vector3, target: Types.AttackRequest?, source: string)
	if PingLogic.cooling(os.clock() - lastPingSend) then
		hud.pings.close()
		return
	end
	if os.clock() - lastPingAttempt < 0.4 then
		hud.pings.close()
		return
	end
	lastPingAttempt = os.clock()
	local body: Types.PingRequest = {
		kind = kind,
		position = position,
		source = source,
	}
	if target then
		if target.kind == "objective" and typeof(target.objectiveId) == "string" then
			body.objectiveId = target.objectiveId
		elseif target.kind == "player" and typeof(target.userId) == "number" then
			body.targetUserId = target.userId
		elseif target.kind == "jungle" and typeof(target.jungleId) == "string" then
			body.jungleId = target.jungleId
		elseif target.kind == "ward" and typeof(target.wardId) == "string" then
			body.wardId = target.wardId
		end
	end
	local result = Remotes.function_("MinimapPing"):InvokeServer(body)
	if result and result.ok == false then
		local reason = result.error or "Ping failed"
		if reason == "Ping cooling down." then
			return
		end
		if reason == "No vision." then
			if os.clock() - lastPingRefuse > 0.8 then
				lastPingRefuse = os.clock()
				hud.aside("No vision.")
			end
			hud.pings.close()
			return
		end
		toast(reason)
		hud.pings.close()
		return
	end
	lastPingSend = os.clock()
	hud.pings.close()
end

hud.minimap.onPing(function(position: Vector3)
	sendPing("Attention", position, nil, "minimap")
end)

Remotes.event("PingReceived").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local ping = payload :: Types.PingPayload
	if typeof(ping.position) ~= "Vector3" then
		return
	end
	hud.minimap.showPing(ping)
	PingFx.play(ping)
	local def = PingCatalog.get(ping.kind)
	if def then
		Sfx.play(def.cue :: SoundIds.Cue)
	end
	local line = if typeof(ping.text) == "string" and ping.text ~= "" then ping.text else "Ping"
	hud.feed.push({
		kind = "ping",
		text = line,
		at = os.clock(),
	})
	-- Yields the banner while Kitty Caster is holding it. The feed still shows the line.
	hud.aside(line)
end)

Remotes.event("MarketUpdated").OnClientEvent:Connect(function(payload)
	local flash = ingestMarket(payload)
	if flash then
		paintMemeTape(flash)
	end
end)

local mutterAt = -HostGuide.AmbientGap
local tomMutterAt = -OldTomGuide.AmbientGap
local FOUNTAIN_RADIUS = 32
local RIFT_FOUNTAINS = { Vector3.new(-176, 0, 0), Vector3.new(176, 0, 0) }

local function nearRiftFountain(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
	for _, fountain in RIFT_FOUNTAINS do
		if (flat - fountain).Magnitude <= FOUNTAIN_RADIUS then
			return true
		end
	end
	return false
end

-- Cat Rift only. A live fight, or a fountain visit while his Talk prompt is up.
-- Draft, the hub, and the other stalls stay quiet. He does not join the kill feed.
local function oldTomAmbientOk(): boolean
	if gameMode ~= "Moba" then
		return false
	end
	if latestMatch and latestMatch.phase == "InProgress" then
		return true
	end
	return nearRiftFountain()
end

local function showHostMutter(part: Instance, line: string)
	local previous = part:FindFirstChild("HostMutter")
	if previous then
		previous:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "HostMutter"
	gui.AlwaysOnTop = false
	gui.MaxDistance = 22
	gui.Size = UDim2.fromOffset(200, 72)
	gui.StudsOffset = Vector3.new(0, 2.8, 0)
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Line"
	label.BackgroundColor3 = Color3.fromRGB(44, 30, 28)
	label.BackgroundTransparency = 0.12
	label.TextColor3 = Color3.fromRGB(255, 243, 224)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 14
	label.TextWrapped = true
	label.Text = line
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	task.delay(4, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

-- Rare line while the Talk prompt is up. Does not open the panel or move the cat.
-- Hosts mutter in the hub. Old Tom mutters in a live Cat Rift, or at a fountain, and rarely.
ProximityPromptService.PromptShown:Connect(function(prompt)
	if hud.chat.root.Visible then
		return
	end
	local part = prompt.Parent
	if not part then
		return
	end
	local npcId = part:GetAttribute(Constants.Attributes.NpcId)
	if typeof(npcId) ~= "string" then
		return
	end
	local now = os.clock()
	if BrandCatalog.host(npcId) then
		if gameMode ~= "Hub" then
			return
		end
		local line, nextAt = HostGuide.ambient(npcId, now, mutterAt, math.floor(now * 10))
		mutterAt = nextAt
		if line then
			showHostMutter(part, line)
		end
		return
	end
	if npcId ~= OldTomGuide.NpcId or not oldTomAmbientOk() then
		return
	end
	local line, nextAt = OldTomGuide.ambient(npcId, now, tomMutterAt, math.floor(now * 10))
	tomMutterAt = nextAt
	if line then
		showHostMutter(part, line)
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= player then
		return
	end
	local part = prompt.Parent
	if not part then
		return
	end
	local npcId = part:GetAttribute(Constants.Attributes.NpcId)
	if typeof(npcId) == "string" then
		local mutter = part:FindFirstChild("HostMutter")
		if mutter then
			mutter:Destroy()
		end
		if latestMatch and latestMatch.phase == "InProgress" and string.find(npcId, "Pawmart") then
			local status = Remotes.function_("GetShopStatus"):InvokeServer()
			if typeof(status) == "table" then
				hud.shop.update(status :: Types.ShopStatus)
			end
			hud.shop.setVisible(true)
		end
		hud.chat.open(npcId, prompt.ObjectText)
		seedCasterChat(npcId)
	end
end)

-- Vision cover is CanQuery so mesh LoS can hit it. Clicks should still land on the ground.
local function clickRayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local map = Workspace:FindFirstChild(Constants.MapFolderName)
	if map then
		local cover = map:FindFirstChild(Constants.VisionCoverName)
		if cover then
			table.insert(ignore, cover)
		end
	end
	-- Aim juice is CanQuery=false; keep it ignored so a future change cannot steal ground clicks.
	local targeting = Workspace:FindFirstChild("MeoTargeting")
	if targeting then
		table.insert(ignore, targeting)
	end
	if #ignore > 0 then
		params.FilterDescendantsInstances = ignore
	end
	return params
end

local function aimPoint(): Vector3
	local camera = Workspace.CurrentCamera
	if not camera then
		return Vector3.zero
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 400, clickRayParams())
	if hit then
		return hit.Position
	end
	return ray.Origin + ray.Direction * 80
end

local function listHas(list: { any }, value: any): boolean
	for _, item in list do
		if item == value then
			return true
		end
	end
	return false
end

local function visibleAttack(req: Types.AttackRequest): boolean
	if req.kind == "objective" then
		return true
	end
	if req.kind == "player" and req.userId then
		if req.userId == player.UserId then
			return true
		end
		return listHas(lastVision.players, req.userId)
	end
	if req.kind == "minion" and req.minionId then
		return listHas(lastVision.minions, req.minionId)
	end
	if req.kind == "jungle" and req.jungleId then
		return listHas(lastVision.jungle, req.jungleId)
	end
	if req.kind == "ward" and req.wardId then
		return listHas(lastVision.wards, req.wardId)
	end
	return false
end

local function cursorHit(): RaycastResult?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	return Workspace:Raycast(ray.Origin, ray.Direction * 400, clickRayParams())
end

local function classifyInstance(inst: Instance): Types.AttackRequest?
	local model = inst:FindFirstAncestorOfClass("Model")
	local req: Types.AttackRequest? = nil
	if model then
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local other = Players:GetPlayerFromCharacter(model)
			if other and other ~= player then
				req = { kind = "player", userId = other.UserId }
			end
			if not req then
				local botId = model:GetAttribute(Constants.Attributes.UserId)
				if typeof(botId) ~= "number" then
					botId = inst:GetAttribute(Constants.Attributes.UserId)
				end
				if typeof(botId) == "number" and botId ~= player.UserId then
					req = { kind = "player", userId = botId }
				end
			end
		end
	end
	if not req then
		local minionId = inst:GetAttribute(Constants.Attributes.MinionId)
		if typeof(minionId) == "string" then
			req = { kind = "minion", minionId = minionId }
		end
	end
	if not req then
		local objectiveId = inst:GetAttribute(Constants.Attributes.ObjectiveId)
		if typeof(objectiveId) == "string" then
			req = { kind = "objective", objectiveId = objectiveId }
		end
	end
	if not req then
		local jungleId = inst:GetAttribute(Constants.Attributes.JungleId)
		if typeof(jungleId) == "string" then
			req = { kind = "jungle", jungleId = jungleId }
		end
	end
	if not req then
		local wardId = inst:GetAttribute(Constants.Attributes.WardId)
		if typeof(wardId) == "string" then
			req = { kind = "ward", wardId = wardId }
		end
	end
	return req
end

local function pickAttack(): Types.AttackRequest?
	local hit = cursorHit()
	if not hit then
		return nil
	end
	local req = classifyInstance(hit.Instance)
	if req and lastVision.fogBits and #lastVision.fogBits > 0 and not visibleAttack(req) then
		return nil
	end
	return req
end

-- Includes a fogged enemy body so the server can refuse Attention. Minions stay ground pings.
local function pickPingTarget(): Types.AttackRequest?
	local hit = cursorHit()
	if not hit then
		return nil
	end
	local req = classifyInstance(hit.Instance)
	if not req or req.kind == "minion" then
		return nil
	end
	return req
end

local LAST_KNOWN_SNAP = 18

local function championIdFromHit(inst: Instance): number?
	local model = inst:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	if not model:FindFirstChildOfClass("Humanoid") then
		return nil
	end
	local other = Players:GetPlayerFromCharacter(model)
	if other and other ~= player then
		return other.UserId
	end
	local botId = model:GetAttribute(Constants.Attributes.UserId)
	if typeof(botId) ~= "number" then
		botId = inst:GetAttribute(Constants.Attributes.UserId)
	end
	if typeof(botId) == "number" and botId ~= player.UserId then
		return botId
	end
	return nil
end

-- Attack-move walks to last-known (into brush), never the live hidden body.
local function attackMovePoint(): Vector3
	local dest = aimPoint()
	local camera = Workspace.CurrentCamera
	if camera then
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		-- Last-seen ghosts are CanQuery false, so this ray still hits the live hidden body.
		-- Vision cover is excluded so a drum does not steal the ground click.
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 400, clickRayParams())
		if hit then
			local hiddenId = championIdFromHit(hit.Instance)
			local remembered = if hiddenId then lastKnownPos[hiddenId] else nil
			if hiddenId and remembered and not listHas(lastVision.players, hiddenId) then
				return remembered
			end
		end
	end
	local best: Vector3? = nil
	local bestD = LAST_KNOWN_SNAP
	for userId, pos in lastKnownPos do
		if not listHas(lastVision.players, userId) and VisionLogic.brushAt(pos.X, pos.Z) ~= nil then
			local d = (Vector3.new(pos.X, dest.Y, pos.Z) - dest).Magnitude
			if d < bestD then
				best = pos
				bestD = d
			end
		end
	end
	if best then
		return best
	end
	return dest
end

local function reportAttack(result: any, cue: string?)
	if result and result.ok == false and result.error then
		if os.clock() - lastErrorAt > 0.4 then
			lastErrorAt = os.clock()
			toast(result.error)
		end
	elseif result and result.ok ~= false then
		if cue == "AutoHit" then
			Sfx.play("AutoHit")
		elseif cue == "WardPlace" then
			Sfx.play("WardPlace")
		elseif cue == "AbilityCast" then
			Sfx.play("AbilityCast")
		end
		if result.combat then
			latestCombat = result.combat
			applyCombatJuice(latestCombat)
			refreshBars()
		end
	end
end

local recallMoveBusy = false

-- Nil position: cancel and let WASD / stick drive. A ground point walks there without attacking.
local function requestMove(position: Vector3?)
	if recallMoveSent or recallMoveBusy or gameMode ~= "Moba" then
		return
	end
	if not latestMatch or latestMatch.phase ~= "InProgress" then
		return
	end
	if not latestCombat or not rootedChannel(latestCombat) then
		return
	end
	recallMoveSent = true
	recallMoveBusy = true
	local ok, result = pcall(function()
		return Remotes.function_("IssueMove"):InvokeServer(position)
	end)
	recallMoveBusy = false
	local accepted = ok and typeof(result) == "table" and (result :: any).ok ~= false
	if accepted then
		reportAttack(result)
	end
	if not accepted or (latestCombat and rootedChannel(latestCombat)) then
		recallMoveSent = false
	end
end

RunService.Heartbeat:Connect(function()
	if not recallLatch.active or recallMoveSent or recallMoveBusy or gameMode ~= "Moba" then
		return
	end
	if UserInputService:GetFocusedTextBox() then
		return
	end
	local moving = movementIntent()
	if not moving then
		if recallLatch.heldAtStart then
			recallLatch.sawRest = true
		end
		return
	end
	if RecallLogic.isNewMoveOrder(recallLatch.heldAtStart, true, recallLatch.sawRest) then
		requestMove(nil)
	end
end)

local attackMoveArmed = false

local function currentAbility(slot: Types.AbilitySlot): Types.AbilityDef?
	if not latestMatch then
		return nil
	end
	local mine = latestMatch.players[tostring(player.UserId)]
	if not mine or not mine.championId then
		return nil
	end
	local champ = ChampionCatalog.get(mine.championId)
	if not champ then
		return nil
	end
	return champ.abilities[slot]
end

local function castAbility(slot: Types.AbilitySlot)
	local result = Remotes.function_("UseAbility"):InvokeServer({
		slot = slot,
		aimPosition = aimPoint(),
	})
	if result and result.ok == false and result.error then
		if os.clock() - lastErrorAt > 0.4 then
			lastErrorAt = os.clock()
			toast(result.error)
		end
	elseif result and result.ok ~= false then
		local wasChanneling = latestCombat ~= nil and channelActive(latestCombat)
		local nextCombat = if result.combat then result.combat :: Types.CombatState else nil
		local cancelledChannel = wasChanneling
			and latestCombat ~= nil
			and latestCombat.channelSlot == slot
			and (nextCombat == nil or not channelActive(nextCombat))
		if not cancelledChannel then
			local pitch = 1
			if latestMatch then
				local mine = latestMatch.players[tostring(player.UserId)]
				if mine and mine.championId then
					pitch = ChampionKits.castPitch(mine.championId, slot)
				end
			end
			Sfx.play("AbilityCast", pitch)
		end
		if result.combat then
			latestCombat = result.combat
			applyCombatJuice(latestCombat)
			refreshBars()
		end
	end
end

local function hideAim()
	armedSlot = nil
	armedKind = nil
	TargetingIndicator.hide()
end

local emoteHeld = false
local emoteConsumed = false
local lastEmoteSend = 0

local function canEmoteNow(): boolean
	if latestMatch and latestMatch.phase == "InProgress" and latestCombat and latestCombat.alive == false then
		return false
	end
	return true
end

local function requestEmote(emoteId: string)
	if os.clock() - lastEmoteSend < 0.2 then
		return
	end
	lastEmoteSend = os.clock()
	local result = Remotes.function_("PlayEmote"):InvokeServer(emoteId)
	if result and result.ok == false then
		toast(result.error or "Emote failed")
	end
	hud.emotes.close()
end

hud.emotes.onPick(function(emoteId: string)
	emoteConsumed = true
	requestEmote(emoteId)
end)

local pingHeld = false
local pingConsumed = false
local pendingPingPos = Vector3.zero
local pendingPingTarget: Types.AttackRequest? = nil

local function requestPing(kind: string)
	sendPing(kind, pendingPingPos, pendingPingTarget, "world")
end

hud.pings.onPick(function(kind: string)
	pingConsumed = true
	requestPing(kind)
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Tab then
		hud.scoreboard.setVisible(false)
	end
	if input.KeyCode == Enum.KeyCode.H then
		hud.help.setHeld(false)
	end
	if input.KeyCode == Enum.KeyCode.T then
		if emoteHeld and not emoteConsumed then
			local picked = hud.emotes.selected()
			if picked then
				requestEmote(picked)
			end
		end
		emoteHeld = false
		hud.emotes.close()
	end
	if input.KeyCode == Enum.KeyCode.G then
		if pingHeld and not pingConsumed then
			local picked = hud.pings.selected()
			if picked then
				requestPing(picked)
			end
		end
		pingHeld = false
		hud.pings.close()
	end
	local slot = SLOT_KEYS[input.KeyCode]
	if slot and armedSlot == slot and armedKind == "hold" then
		castAbility(slot)
		hideAim()
	end
end)

player.CharacterAdded:Connect(function(character)
	task.defer(function()
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			CameraFollow.setSubject(root)
			YarnCamera.setSubject(root)
			KoiCamera.setSubject(root)
			YarnPartyCamera.setSubject(root)
			ArcadeCamera.setSubject(root)
		end
	end)
end)
if player.Character then
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		CameraFollow.setSubject(root)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Tab then
		if latestMatch and latestMatch.phase == "InProgress" then
			hud.scoreboard.update(latestMatch, player.UserId)
			hud.scoreboard.setVisible(true)
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.H then
		hud.help.setHeld(true)
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		if hud.emotes.isOpen() then
			emoteHeld = false
			emoteConsumed = true
			hud.emotes.close()
			return
		end
		if hud.pings.isOpen() then
			pingHeld = false
			pingConsumed = true
			hud.pings.close()
			return
		end
	end
	if armedSlot and (input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton2) then
		hideAim()
		toast("Cast canceled")
		return
	end
	if processed then
		return
	end
	if gameMode == "YarnRun" then
		if input.KeyCode == Enum.KeyCode.T then
			if not canEmoteNow() then
				toast("Can't emote while down")
				return
			end
			emoteHeld = true
			emoteConsumed = false
			hud.emotes.open()
			return
		end
		if input.KeyCode == Enum.KeyCode.G then
			toast("Pings are for the Rift")
			return
		end
		local send: Types.YarnRunInput = {}
		if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			local lane = if latestYarn then latestYarn.lane else 1
			send.lane = math.max(0, lane - 1)
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			local lane = if latestYarn then latestYarn.lane else 1
			send.lane = math.min(2, lane + 1)
		elseif input.KeyCode == Enum.KeyCode.Space then
			send.jump = true
		elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl then
			send.slide = true
		else
			return
		end
		task.spawn(function()
			Remotes.function_("YarnRunInput"):InvokeServer(send)
		end)
		return
	end
	if gameMode == "KoiPond" then
		if input.KeyCode == Enum.KeyCode.T then
			if not canEmoteNow() then
				toast("Can't emote while down")
				return
			end
			emoteHeld = true
			emoteConsumed = false
			hud.emotes.open()
			return
		end
		if input.KeyCode == Enum.KeyCode.G then
			toast("Pings are for the Rift")
			return
		end
		local tap = input.KeyCode == Enum.KeyCode.Space
			or input.UserInputType == Enum.UserInputType.MouseButton1
		if not tap then
			return
		end
		local action: Types.KoiPondInput = {
			action = if latestKoi and latestKoi.phase == "Bite" then "reel" else "cast",
		}
		task.spawn(function()
			Remotes.function_("KoiPondInput"):InvokeServer(action)
		end)
		return
	end
	if gameMode == "YarnParty" then
		if input.KeyCode == Enum.KeyCode.T then
			if not canEmoteNow() then
				toast("Can't emote while down")
				return
			end
			emoteHeld = true
			emoteConsumed = false
			hud.emotes.open()
			return
		end
		if input.KeyCode == Enum.KeyCode.G then
			toast("Pings are for the Rift")
			return
		end
		return
	end
	if gameMode == "MemeArcade" then
		if input.KeyCode == Enum.KeyCode.T then
			if not canEmoteNow() then
				toast("Can't emote while down")
				return
			end
			emoteHeld = true
			emoteConsumed = false
			hud.emotes.open()
			return
		end
		if input.KeyCode == Enum.KeyCode.G then
			toast("Pings are for the Rift")
			return
		end
		local index = if input.KeyCode == Enum.KeyCode.One
			then 1
			elseif input.KeyCode == Enum.KeyCode.Two then 2
			elseif input.KeyCode == Enum.KeyCode.Three then 3
			elseif input.KeyCode == Enum.KeyCode.Four then 4
			elseif input.KeyCode == Enum.KeyCode.Five then 5
			else 0
		if index <= 0 then
			return
		end
		local ids = ArcadeCatalog.ids()
		local tickerId = ids[index]
		if not tickerId then
			return
		end
		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		local action: Types.ArcadeInput = {
			tickerId = tickerId,
			action = if shift then "sell" else "buy",
		}
		task.spawn(function()
			Remotes.function_("MemeArcadeInput"):InvokeServer(action)
		end)
		return
	end
	if input.KeyCode == Enum.KeyCode.T then
		if hud.pings.isOpen() then
			hud.pings.close()
			pingHeld = false
		end
		if not canEmoteNow() then
			toast("Can't emote while down")
			return
		end
		emoteHeld = true
		emoteConsumed = false
		hud.emotes.open()
		return
	end
	if input.KeyCode == Enum.KeyCode.G then
		if hud.emotes.isOpen() then
			return
		end
		if not latestMatch or latestMatch.phase ~= "InProgress" then
			toast("Ping during a match")
			return
		end
		pingHeld = true
		pingConsumed = false
		pendingPingPos = aimPoint()
		pendingPingTarget = pickPingTarget()
		hud.pings.open()
		return
	end
	if input.KeyCode == Enum.KeyCode.V then
		if latestMatch and latestMatch.phase == "InProgress" then
			local on = not CameraFollow.isEnabled()
			CameraFollow.setEnabled(on)
			toast(if on then "Follow camera on" else "Free camera")
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.X then
		if latestMatch and latestMatch.phase == "InProgress" then
			attackMoveArmed = true
			toast("Attack-move — click the ground or a target")
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.S then
		if latestMatch and latestMatch.phase == "InProgress" then
			attackMoveArmed = false
			hideAim()
			reportAttack(Remotes.function_("IssueAttack"):InvokeServer({ kind = "stop" }))
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		if latestMatch and latestMatch.phase == "InProgress" then
			reportAttack(Remotes.function_("StartRecall"):InvokeServer())
		end
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if hud.emotes.isOpen() or hud.pings.isOpen() then
			return
		end
		if not latestMatch or latestMatch.phase ~= "InProgress" then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		if hud.minimap.contains(mouse.X, mouse.Y) then
			return
		end
		if armedSlot and armedKind == "ground" then
			castAbility(armedSlot)
			hideAim()
			return
		end
		local target = pickAttack()
		if target then
			attackMoveArmed = false
			reportAttack(Remotes.function_("IssueAttack"):InvokeServer(target))
		elseif attackMoveArmed then
			attackMoveArmed = false
			reportAttack(Remotes.function_("AttackMove"):InvokeServer(attackMovePoint()))
		elseif latestCombat and rootedChannel(latestCombat) then
			requestMove(aimPoint())
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		if latestMatch and latestMatch.phase == "InProgress" then
			local status = Remotes.function_("GetShopStatus"):InvokeServer()
			if typeof(status) == "table" then
				hud.shop.update(status :: Types.ShopStatus)
			end
			hud.shop.toggle()
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.Four then
		if latestMatch and latestMatch.phase == "InProgress" then
			reportAttack(Remotes.function_("PlaceWard"):InvokeServer(aimPoint()), "WardPlace")
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.Five then
		if latestMatch and latestMatch.phase == "InProgress" then
			reportAttack(Remotes.function_("UseLens"):InvokeServer(), "AbilityCast")
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.Six then
		if latestMatch and latestMatch.phase == "InProgress" then
			reportAttack(Remotes.function_("PlaceControl"):InvokeServer(aimPoint()), "WardPlace")
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.Seven then
		if latestMatch and latestMatch.phase == "InProgress" then
			reportAttack(Remotes.function_("UseCleave"):InvokeServer(), "AbilityCast")
		end
		return
	end
	local slot = SLOT_KEYS[input.KeyCode]
	if not slot then
		return
	end
	if not latestMatch or latestMatch.phase ~= "InProgress" then
		return
	end
	local ability = currentAbility(slot)
	if not ability then
		return
	end
	local mode = Targeting.of(ability)
	if mode == "line" or mode == "dash" then
		armedSlot = slot
		armedKind = "hold"
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			TargetingIndicator.show(ability, root.Position, aimPoint())
		end
		return
	end
	if mode == "ground" then
		if armedSlot == slot and armedKind == "ground" then
			castAbility(slot)
			hideAim()
			return
		end
		armedSlot = slot
		armedKind = "ground"
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			TargetingIndicator.show(ability, root.Position, aimPoint())
		end
		toast("Click or press again to cast · Esc / RMB cancel")
		return
	end
	-- Instant heals/shields: fire once, never leave a ghost ring.
	TargetingIndicator.hide()
	castAbility(slot)
end)

task.spawn(function()
	local hubOk, hubStatus = pcall(function()
		return Remotes.function_("GetHubStatus"):InvokeServer()
	end)
	if hubOk and typeof(hubStatus) == "table" then
		local hub = hubStatus :: Types.HubStatus
		if hub.mode == "Hub" or hub.mode == "Moba" or hub.mode == "YarnRun" or hub.mode == "KoiPond" or hub.mode == "YarnParty" or hub.mode == "MemeArcade" then
			gameMode = hub.mode
		end
		hud.hub.update(hub)
		if gameMode == "Hub" then
			hubPage = "grid"
		end
	end
	refreshYarnBoard()
	refreshKoiBoard()
	refreshArcadeBoard()
	if not loadedPrefs then
		local ok, result = pcall(function()
			return Remotes.function_("GetSettings"):InvokeServer()
		end)
		if ok then
			loadedPrefs = prefsFromRemote(result)
			if loadedPrefs then
				applyLoadedPrefs(loadedPrefs)
			end
		end
	end
	local tutorial = Remotes.function_("GetTutorialStatus"):InvokeServer()
	if typeof(tutorial) == "table" and (tutorial :: any).done == true then
		tutorialDone = true
		player:SetAttribute(Constants.Attributes.TutorialDone, true)
	end
	applySnapshot(Remotes.function_("GetMatchSnapshot"):InvokeServer())
	local voice = Remotes.function_("GetVoiceStatus"):InvokeServer()
	if typeof(voice) == "table" then
		hud.voice.update(voice :: Types.VoiceStatus)
	end
	local mint = Remotes.function_("GetMintStatus"):InvokeServer()
	if typeof(mint) == "table" then
		hud.mint.update(mint :: Types.MintStatus)
	end
	local closet = Remotes.function_("GetCloset"):InvokeServer()
	if typeof(closet) == "table" then
		hud.closet.update(closet :: Types.ClosetStatus)
	end
	local market = Remotes.function_("GetMemeMarket"):InvokeServer()
	if ingestMarket(market) then
		paintMemeTape(nil)
	end
end)

-- Refresh champ-select countdown locally
task.spawn(function()
	while true do
		task.wait(0.4)
		if latestMatch and latestMatch.phase == "ChampionSelect" then
			hud.select.update(latestMatch, player.UserId)
		elseif latestMatch and latestMatch.phase == "InProgress" then
			refreshBars()
			applyVision()
			hud.minimap.update(latestMatch, lastVision, player.UserId)
			if latestMatch.practice then
				local mine = latestMatch.players[tostring(player.UserId)]
				local character = player.Character
				local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
				local atFountain = false
				if mine and root and root:IsA("BasePart") then
					local map = Workspace:FindFirstChild(Constants.MapFolderName)
					local spawns = if map then map:FindFirstChild("Spawns") else nil
					local spawnName = if mine.team == "Red" then "RedFountain" else "BlueFountain"
					local spawn = if spawns then spawns:FindFirstChild(spawnName) else nil
					if spawn and spawn:IsA("BasePart") then
						atFountain = (root.Position - spawn.Position).Magnitude <= 32
					end
				end
				hud.tips.tickContextual(atFountain, if mine then mine.gold else 0, hud.shop.root.Visible)
			end
		elseif latestMatch and latestMatch.phase == "Ended" then
			applyVision()
			hud.endScreen.update(latestMatch, player.UserId)
		end
	end
end)

-- Smooth aim follow while a line/dash is held or a ground AoE is armed.
RunService.RenderStepped:Connect(function()
	if not armedSlot or not latestMatch or latestMatch.phase ~= "InProgress" then
		return
	end
	local ability = currentAbility(armedSlot)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not ability or not root or not root:IsA("BasePart") then
		return
	end
	local mode = Targeting.of(ability)
	if mode == "instant" then
		hideAim()
		return
	end
	TargetingIndicator.show(ability, root.Position, aimPoint())
end)

print("[Meo Meo Meo] Client HUD ready. Fog of war is server-authored. Last-seen ghosts are client-only. 4 trinket, 5 lens, 6 Control Yarn, 7 Yarn Cleave, hold Q for skillshots, click to confirm ground AoE, F recall, B shop.")
