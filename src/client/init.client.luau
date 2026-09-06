--!strict

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local Hud = require(script.UI.Hud)

local player = Players.LocalPlayer
local hud = Hud.create()

local latestMatch: Types.MatchSnapshot? = nil
local latestCombat: Types.CombatState? = nil
local lastErrorAt = 0

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
	hud.abilities.update(mine.championId, latestCombat, mine.gold, `{mine.kills} / {mine.deaths} / {mine.assists}`)
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

hud.select.onPick(function(championId: string)
	local result = Remotes.function_("SelectChampion"):InvokeServer(championId)
	if result and result.ok == false then
		toast(result.error or "Could not lock that cat")
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

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
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
		end
	end
end)

print("[Meo Meo Meo] Client HUD ready. QWER to brawl, talk to fountain cats.")
