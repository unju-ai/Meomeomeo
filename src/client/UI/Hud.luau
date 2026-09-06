--!strict

local Players = game:GetService("Players")

local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local AbilityBar = require(script.Parent.AbilityBar)
local ChampionSelect = require(script.Parent.ChampionSelect)
local LobbyPanel = require(script.Parent.LobbyPanel)
local MintPanel = require(script.Parent.MintPanel)
local NpcChatPanel = require(script.Parent.NpcChatPanel)
local KillFeed = require(script.Parent.KillFeed)
local Minimap = require(script.Parent.Minimap)
local Scoreboard = require(script.Parent.Scoreboard)
local ShopPanel = require(script.Parent.ShopPanel)
local VoiceHud = require(script.Parent.VoiceHud)

local Hud = {}

export type HudApi = {
	gui: ScreenGui,
	lobby: LobbyPanel.LobbyApi,
	mint: MintPanel.MintApi,
	select: ChampionSelect.SelectApi,
	abilities: AbilityBar.BarApi,
	voice: VoiceHud.VoiceHudApi,
	chat: NpcChatPanel.ChatApi,
	shop: ShopPanel.ShopApi,
	minimap: Minimap.MinimapApi,
	scoreboard: Scoreboard.BoardApi,
	feed: KillFeed.FeedApi,
	banner: (text: string) -> (),
	ticker: (text: string) -> (),
	applyPhase: (snapshot: Types.MatchSnapshot, localUserId: number) -> (),
}

function Hud.create(): HudApi
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "MeoHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local ticker = Theme.text(gui, "Ticker", "🐾 MEO stocks warming up…", 13, Theme.ink, Theme.fontMono)
	ticker.AnchorPoint = Vector2.new(0.5, 0)
	ticker.Position = UDim2.new(0.5, 0, 0, 8)
	ticker.Size = UDim2.fromOffset(640, 22)
	ticker.BackgroundColor3 = Theme.amber
	ticker.BackgroundTransparency = 0.12
	ticker.TextXAlignment = Enum.TextXAlignment.Center
	Theme.corner(ticker, 8)
	Theme.pad(ticker, 4)

	local banner = Theme.text(gui, "Banner", "", 20, Theme.cream, Theme.fontTitle)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 40)
	banner.Size = UDim2.fromOffset(720, 28)
	banner.TextXAlignment = Enum.TextXAlignment.Center
	banner.TextStrokeTransparency = 0.4
	banner.ZIndex = 10

	local lobby = LobbyPanel.create(gui)
	local mint = MintPanel.create(gui)
	local select = ChampionSelect.create(gui)
	local abilities = AbilityBar.create(gui)
	local voice = VoiceHud.create(gui)
	local chat = NpcChatPanel.create(gui)
	local shop = ShopPanel.create(gui)
	local minimap = Minimap.create(gui)
	local feed = KillFeed.create(gui)
	local scoreboard = Scoreboard.create(gui)

	local function applyPhase(snapshot: Types.MatchSnapshot, localUserId: number)
		local phase = snapshot.phase
		lobby.setVisible(phase == "Lobby")
		if phase ~= "Lobby" then
			mint.setVisible(false)
		end
		select.setVisible(phase == "ChampionSelect")
		abilities.setVisible(phase == "InProgress")
		minimap.setVisible(phase == "InProgress")
		feed.setVisible(phase == "InProgress")
		if phase ~= "InProgress" then
			shop.setVisible(false)
			scoreboard.setVisible(false)
		end
		if phase == "Lobby" then
			lobby.update(snapshot)
			banner.Text = ""
		elseif phase == "ChampionSelect" then
			select.update(snapshot, localUserId)
			banner.Text = if snapshot.practice then "Practice draft" else "Champion select"
		elseif phase == "InProgress" then
			local mine = snapshot.players[tostring(localUserId)]
			banner.Text = if mine then `{mine.team} · Tab score · V camera · B shop` else "Spectating"
		elseif phase == "Ended" then
			abilities.setVisible(false)
			lobby.setVisible(true)
			banner.Text = `{snapshot.winner or "??"} wins — returning to lobby`
		end
	end

	return {
		gui = gui,
		lobby = lobby,
		mint = mint,
		select = select,
		abilities = abilities,
		voice = voice,
		chat = chat,
		shop = shop,
		minimap = minimap,
		scoreboard = scoreboard,
		feed = feed,
		banner = function(text: string)
			banner.Text = text
		end,
		ticker = function(text: string)
			ticker.Text = text
		end,
		applyPhase = applyPhase,
	}
end

return Hud
