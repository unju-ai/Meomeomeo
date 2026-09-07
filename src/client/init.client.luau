--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChampionCatalog = require(Shared:WaitForChild("ChampionCatalog"))
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Targeting = require(Shared:WaitForChild("Targeting"))
local Types = require(Shared:WaitForChild("Types"))

local Sfx = require(script.Audio.Sfx)
local CameraFollow = require(script.CameraFollow)
local CombatFx = require(script.Juice.CombatFx)
local ScreenJuice = require(script.Juice.ScreenJuice)
local Hud = require(script.UI.Hud)
local TargetingIndicator = require(script.TargetingIndicator)

local player = Players.LocalPlayer
local hud = Hud.create()
ScreenJuice.init(hud.gui)
hud.settings.onChange(function(volume: number, muted: boolean)
	Sfx.setVolume(volume)
	Sfx.setMuted(muted)
	player:SetAttribute("MeoSfxVolume", volume)
	player:SetAttribute("MeoSfxMuted", muted)
end)

local latestMatch: Types.MatchSnapshot? = nil
local latestCombat: Types.CombatState? = nil
local juiceCombat: Types.CombatState? = nil
local tutorialDone = player:GetAttribute(Constants.Attributes.TutorialDone) == true

local function tutorialIsDone(): boolean
	return tutorialDone or player:GetAttribute(Constants.Attributes.TutorialDone) == true
end

local lastVision: Types.VisionFrame = { players = {}, minions = {}, jungle = {}, wards = {} }
local armedSlot: Types.AbilitySlot? = nil
local lastErrorAt = 0
local cameraArmed = false

local SLOT_KEYS: { [Enum.KeyCode]: Types.AbilitySlot } = {
	[Enum.KeyCode.Q] = "Q",
	[Enum.KeyCode.W] = "W",
	[Enum.KeyCode.E] = "E",
	[Enum.KeyCode.R] = "R",
}

local function toast(text: string)
	hud.banner(text)
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
	if hud.scoreboard.root.Visible then
		hud.scoreboard.update(latestMatch, player.UserId)
	end
end

local function applySnapshot(snapshot: Types.MatchSnapshot?)
	if snapshot == nil then
		snapshot = Remotes.function_("GetMatchSnapshot"):InvokeServer()
	end
	if typeof(snapshot) ~= "table" then
		return
	end
	latestMatch = snapshot :: Types.MatchSnapshot
	hud.applyPhase(latestMatch, player.UserId)
	hud.tips.sync(latestMatch, player.UserId, tutorialIsDone())
	refreshBars()
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
		TargetingIndicator.hide()
		Sfx.stopLoop("RecallLoop")
	end
end

local function applyCombatJuice(state: Types.CombatState)
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
	else
		hud.lobby.setQueued(true)
		toast("Queued — waiting for more cats")
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
	local result = Remotes.function_("InviteParty"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Invite failed")
	else
		toast("Friend added to your party")
	end
	local queue = Remotes.function_("GetQueueStatus"):InvokeServer()
	if typeof(queue) == "table" then
		hud.lobby.updateQueue(queue :: Types.QueueStatus)
	end
end)

hud.lobby.onPractice(function(difficulty)
	local result = Remotes.function_("StartPractice"):InvokeServer(difficulty)
	if result and result.ok == false then
		toast(result.error or "Practice failed")
	end
end)

hud.lobby.onShowTips(function()
	hud.tips.replay()
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
	hud.mint.toggle()
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

hud.chat.onSend(function(npcId: string, text: string)
	local result = Remotes.function_("ChatWithNpc"):InvokeServer(npcId, text)
	if result and result.ok and result.reply then
		hud.chat.append(result.speaker or "Cat", result.reply)
	elseif result and result.error then
		hud.chat.append("System", result.error)
	end
end)

Remotes.event("MatchStateChanged").OnClientEvent:Connect(function(snapshot)
	applySnapshot(snapshot)
end)

Remotes.event("QueueUpdated").OnClientEvent:Connect(function(status)
	if typeof(status) ~= "table" then
		return
	end
	local queue = status :: Types.QueueStatus
	hud.lobby.updateQueue(queue)
	if queue.phase == "Found" then
		Sfx.play("MatchFound")
		toast("Match found!")
	elseif queue.phase == "Teleporting" then
		toast("Teleporting to the rift…")
	end
end)

Remotes.event("CombatUpdated").OnClientEvent:Connect(function(state)
	if typeof(state) == "table" then
		latestCombat = state :: Types.CombatState
		applyCombatJuice(latestCombat)
		refreshBars()
	end
end)

Remotes.event("VoiceStatusChanged").OnClientEvent:Connect(function(status)
	if typeof(status) == "table" then
		hud.voice.update(status :: Types.VoiceStatus)
	end
end)

Remotes.event("AnnouncerMessage").OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" and typeof((payload :: any).text) == "string" then
		local text = (payload :: any).text :: string
		toast(`{(payload :: any).speaker or "Kitty Caster"}: {text}`)
		local cue = Sfx.cueForAnnouncer(text)
		if cue then
			Sfx.play(cue)
		end
	end
end)

Remotes.event("CombatFx").OnClientEvent:Connect(function(payload)
	CombatFx.playUnknown(payload)
end)

Remotes.event("KillFeed").OnClientEvent:Connect(function(event)
	if typeof(event) == "table" and typeof((event :: any).text) == "string" then
		local feed = event :: Types.FeedEvent
		hud.feed.push(feed)
		local cue = Sfx.cueForFeed(feed.kind)
		if cue then
			Sfx.play(cue)
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

local function applyVision()
	if not latestMatch or latestMatch.phase ~= "InProgress" then
		return
	end
	local mine = latestMatch.players[tostring(player.UserId)]
	local visiblePlayers: { [number]: boolean } = { [player.UserId] = true }
	for _, userId in lastVision.players do
		visiblePlayers[userId] = true
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			local show = visiblePlayers[other.UserId] == true
			for _, inst in other.Character:GetDescendants() do
				if inst:IsA("BasePart") then
					inst.LocalTransparencyModifier = if show then 0 else 1
				end
			end
		end
	end

	local map = Workspace:FindFirstChild(Constants.MapFolderName)

	local botsFolder = if map then map:FindFirstChild("Bots") else nil
	if botsFolder then
		for _, child in botsFolder:GetChildren() do
			if child:IsA("Model") then
				local userId = child:GetAttribute(Constants.Attributes.UserId)
				local otherMatch = if typeof(userId) == "number" then latestMatch.players[tostring(userId)] else nil
				local ally = mine ~= nil and otherMatch ~= nil and otherMatch.team == mine.team
				local show = ally or (typeof(userId) == "number" and visiblePlayers[userId] == true)
				for _, inst in child:GetDescendants() do
					if inst:IsA("BasePart") then
						inst.LocalTransparencyModifier = if show then 0 else 1
					elseif inst:IsA("BillboardGui") then
						inst.Enabled = show
					end
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
				local show = ally or visibleMinions[child.Name] == true
				child.LocalTransparencyModifier = if show then 0 else 1
				local label = child:FindFirstChild("Label")
				if label and label:IsA("BillboardGui") then
					label.Enabled = show
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
				local show = visibleJungle[child.Name] == true
				child.LocalTransparencyModifier = if show then 0 else 1
				local label = child:FindFirstChild("Label")
				if label and label:IsA("BillboardGui") then
					label.Enabled = show
				end
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
				child.LocalTransparencyModifier = if show then 0 else 1
				local label = child:FindFirstChild("Label")
				if label and label:IsA("BillboardGui") then
					label.Enabled = show
				end
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
		lastVision = incoming
		applyVision()
		if latestMatch and latestMatch.phase == "InProgress" then
			hud.minimap.update(latestMatch, lastVision, player.UserId)
		end
	end
end)

hud.minimap.onPing(function(position: Vector3)
	Remotes.function_("MinimapPing"):InvokeServer(position)
end)

Remotes.event("PingReceived").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local ping = payload :: Types.PingPayload
	hud.minimap.showPing(ping)
	toast(`Ping · {if ping.userId == player.UserId then "you" else "ally"}`)
	local marker = Instance.new("Part")
	marker.Name = "MeoPing"
	marker.Anchored = true
	marker.CanCollide = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(255, 196, 74)
	marker.Size = Vector3.new(5, 0.5, 5)
	marker.CFrame = CFrame.new(ping.position)
	marker.Parent = Workspace
	task.delay(2.4, function()
		if marker.Parent then
			marker:Destroy()
		end
	end)
end)

Remotes.event("MarketUpdated").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local tickers = (payload :: any).tickers
	if typeof(tickers) ~= "table" then
		return
	end
	local bits = { "🧶" }
	for _, ticker in tickers do
		if typeof(ticker) == "table" then
			table.insert(bits, `{ticker.symbol} {string.format("%.1f", ticker.price)}`)
		end
	end
	hud.ticker(table.concat(bits, "   ·   "))
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
		if latestMatch and latestMatch.phase == "InProgress" and string.find(npcId, "Pawmart") then
			local status = Remotes.function_("GetShopStatus"):InvokeServer()
			if typeof(status) == "table" then
				hud.shop.update(status :: Types.ShopStatus)
			end
			hud.shop.setVisible(true)
		end
		hud.chat.open(npcId, prompt.ObjectText)
	end
end)

local function aimPoint(): Vector3
	local camera = Workspace.CurrentCamera
	if not camera then
		return Vector3.zero
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if player.Character then
		params.FilterDescendantsInstances = { player.Character }
	end
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	if hit then
		return hit.Position
	end
	return ray.Origin + ray.Direction * 80
end

local function pickAttack(): Types.AttackRequest?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if player.Character then
		params.FilterDescendantsInstances = { player.Character }
	end
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	if not hit then
		return nil
	end
	local inst = hit.Instance
	local model = inst:FindFirstAncestorOfClass("Model")
	if model then
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local other = Players:GetPlayerFromCharacter(model)
			if other and other ~= player then
				return { kind = "player", userId = other.UserId }
			end
			local botId = model:GetAttribute(Constants.Attributes.UserId)
			if typeof(botId) ~= "number" then
				botId = inst:GetAttribute(Constants.Attributes.UserId)
			end
			if typeof(botId) == "number" and botId ~= player.UserId then
				return { kind = "player", userId = botId }
			end
		end
	end
	local minionId = inst:GetAttribute(Constants.Attributes.MinionId)
	if typeof(minionId) == "string" then
		return { kind = "minion", minionId = minionId }
	end
	local objectiveId = inst:GetAttribute(Constants.Attributes.ObjectiveId)
	if typeof(objectiveId) == "string" then
		return { kind = "objective", objectiveId = objectiveId }
	end
	local jungleId = inst:GetAttribute(Constants.Attributes.JungleId)
	if typeof(jungleId) == "string" then
		return { kind = "jungle", jungleId = jungleId }
	end
	local wardId = inst:GetAttribute(Constants.Attributes.WardId)
	if typeof(wardId) == "string" then
		return { kind = "ward", wardId = wardId }
	end
	return nil
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
		Sfx.play("AbilityCast")
		if result.combat then
			latestCombat = result.combat
			applyCombatJuice(latestCombat)
			refreshBars()
		end
	end
end

local function hideAim()
	armedSlot = nil
	TargetingIndicator.hide()
end

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Tab then
		hud.scoreboard.setVisible(false)
	end
	if input.KeyCode == Enum.KeyCode.H then
		hud.help.setHeld(false)
	end
	local slot = SLOT_KEYS[input.KeyCode]
	if slot and armedSlot == slot then
		castAbility(slot)
		hideAim()
	end
end)

player.CharacterAdded:Connect(function(character)
	task.defer(function()
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			CameraFollow.setSubject(root)
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
	if processed then
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
		if not latestMatch or latestMatch.phase ~= "InProgress" then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		if hud.minimap.contains(mouse.X, mouse.Y) then
			return
		end
		local target = pickAttack()
		if target then
			attackMoveArmed = false
			reportAttack(Remotes.function_("IssueAttack"):InvokeServer(target))
		elseif attackMoveArmed then
			attackMoveArmed = false
			reportAttack(Remotes.function_("AttackMove"):InvokeServer(aimPoint()))
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
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			TargetingIndicator.show(ability, root.Position, aimPoint())
		end
		return
	end
	castAbility(slot)
end)

task.spawn(function()
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
	local market = Remotes.function_("GetMemeMarket"):InvokeServer()
	if typeof(market) == "table" and typeof((market :: any).tickers) == "table" then
		local bits = { "🧶" }
		for _, ticker in (market :: any).tickers do
			table.insert(bits, `{ticker.symbol} {string.format("%.1f", ticker.price)}`)
		end
		hud.ticker(table.concat(bits, "   ·   "))
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
			if armedSlot then
				local ability = currentAbility(armedSlot)
				local character = player.Character
				local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
				if ability and root and root:IsA("BasePart") then
					TargetingIndicator.show(ability, root.Position, aimPoint())
				end
			end
		elseif latestMatch and latestMatch.phase == "Ended" then
			hud.endScreen.update(latestMatch, player.UserId)
		end
	end
end)

print("[Meo Meo Meo] Client HUD ready. 4 ward, 5 lens, hold Q for skillshots, F recall, B shop.")
