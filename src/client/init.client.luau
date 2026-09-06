--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local CameraFollow = require(script.CameraFollow)
local Hud = require(script.UI.Hud)

local player = Players.LocalPlayer
local hud = Hud.create()

local latestMatch: Types.MatchSnapshot? = nil
local latestCombat: Types.CombatState? = nil

local lastVision: Types.VisionFrame = { players = {}, minions = {}, jungle = {} }
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
	Remotes.function_("LeaveQueue"):InvokeServer()
	hud.lobby.setQueued(false)
	applySnapshot(Remotes.function_("GetMatchSnapshot"):InvokeServer())
end)

hud.lobby.onPractice(function()
	local result = Remotes.function_("StartPractice"):InvokeServer()
	if result and result.ok == false then
		toast(result.error or "Practice failed")
	end
end)

hud.lobby.onMint(function()
	hud.mint.toggle()
end)

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
	local nextStatus = Remotes.function_("GetMintStatus"):InvokeServer()
	if typeof(nextStatus) == "table" then
		hud.mint.update(nextStatus :: Types.MintStatus)
	end
end)

hud.mint.onLink(function(address: string)
	local result = Remotes.function_("LinkWallet"):InvokeServer(address)
	if result and result.ok == false then
		toast(result.error or "Wallet link failed")
	else
		toast("Wallet saved on the game server (ownership proof is a later TODO)")
	end
end)

hud.mint.onClaim(function(purchaseId: string)
	local result = Remotes.function_("ClaimMeo404"):InvokeServer(purchaseId)
	if result and result.ok == false then
		toast(result.error or "Claim failed")
	else
		toast("Claim submitted. Mock tx in Studio; live mint is hosted.")
	end
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

Remotes.event("CombatUpdated").OnClientEvent:Connect(function(state)
	if typeof(state) == "table" then
		latestCombat = state :: Types.CombatState
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
		toast(`{(payload :: any).speaker or "Kitty Caster"}: {(payload :: any).text}`)
	end
end)

Remotes.event("KillFeed").OnClientEvent:Connect(function(event)
	if typeof(event) == "table" and typeof((event :: any).text) == "string" then
		hud.feed.push(event :: Types.FeedEvent)
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
end

Remotes.event("VisionUpdated").OnClientEvent:Connect(function(frame)
	if typeof(frame) == "table" then
		local incoming = frame :: Types.VisionFrame
		if incoming.jungle == nil then
			incoming.jungle = {}
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
	return nil
end

local function reportAttack(result: any)
	if result and result.ok == false and result.error then
		if os.clock() - lastErrorAt > 0.4 then
			lastErrorAt = os.clock()
			toast(result.error)
		end
	elseif result and result.combat then
		latestCombat = result.combat
		refreshBars()
	end
end

local attackMoveArmed = false

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Tab then
		hud.scoreboard.setVisible(false)
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
			reportAttack(Remotes.function_("IssueAttack"):InvokeServer({ kind = "stop" }))
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
	local slot = SLOT_KEYS[input.KeyCode]
	if not slot then
		return
	end
	if not latestMatch or latestMatch.phase ~= "InProgress" then
		return
	end
	local result = Remotes.function_("UseAbility"):InvokeServer({
		slot = slot,
		aimPosition = aimPoint(),
	})
	if result and result.ok == false and result.error then
		if os.clock() - lastErrorAt > 0.4 then
			lastErrorAt = os.clock()
			toast(result.error)
		end
	elseif result and result.combat then
		latestCombat = result.combat
		refreshBars()
	end
end)

task.spawn(function()
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
		end
	end
end)

print("[Meo Meo Meo] Client HUD ready. Tab scoreboard, V camera, LMB attack, QWER to brawl.")
