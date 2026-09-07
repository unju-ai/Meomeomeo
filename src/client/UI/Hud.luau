--!strict

local Players = game:GetService("Players")

local Theme = require(script.Parent.Parent.Theme)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Types = require(Shared:WaitForChild("Types"))

local AbilityBar = require(script.Parent.AbilityBar)
local ChampionSelect = require(script.Parent.ChampionSelect)
local LobbyPanel = require(script.Parent.LobbyPanel)
local MintPanel = require(script.Parent.MintPanel)
local NpcChatPanel = require(script.Parent.NpcChatPanel)
local EndScreen = require(script.Parent.EndScreen)
local KillFeed = require(script.Parent.KillFeed)
local Minimap = require(script.Parent.Minimap)
local Scoreboard = require(script.Parent.Scoreboard)
local HelpPanel = require(script.Parent.HelpPanel)
local TutorialTips = require(script.Parent.TutorialTips)
local SettingsPanel = require(script.Parent.SettingsPanel)
local ShopPanel = require(script.Parent.ShopPanel)
local VoiceHud = require(script.Parent.VoiceHud)
local EmoteWheel = require(script.Parent.EmoteWheel)
local PingWheel = require(script.Parent.PingWheel)

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
	endScreen: EndScreen.EndApi,
	settings: SettingsPanel.SettingsApi,
	help: HelpPanel.HelpApi,
	tips: TutorialTips.TipsApi,
	emotes: EmoteWheel.WheelApi,
	pings: PingWheel.WheelApi,
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
	local endScreen = EndScreen.create(gui)
	local startVolume = player:GetAttribute(Constants.Attributes.SfxVolume)
	local startMuted = player:GetAttribute(Constants.Attributes.SfxMuted)
	local startMuteOthers = player:GetAttribute(Constants.Attributes.MuteOthersEmotes)
	local startMusic = player:GetAttribute(Constants.Attributes.MusicVolume)
	local startMusicMuted = player:GetAttribute(Constants.Attributes.MusicMuted)
	local settings = SettingsPanel.create(gui, {
		sfxVolume = if typeof(startVolume) == "number" then startVolume :: number else 0.8,
		sfxMuted = startMuted == true,
		muteOthersEmotes = startMuteOthers == true,
		musicVolume = if typeof(startMusic) == "number" then startMusic :: number else 0.35,
		musicMuted = startMusicMuted == true,
	})
	local emotes = EmoteWheel.create(gui)
	local pings = PingWheel.create(gui)
	local help = HelpPanel.create(gui)
	local tips = TutorialTips.create(gui)

	local function applyPhase(snapshot: Types.MatchSnapshot, localUserId: number)
		local phase = snapshot.phase
		lobby.setVisible(phase == "Lobby")
		if phase ~= "Lobby" then
			mint.setVisible(false)
		end
		select.setVisible(phase == "ChampionSelect")
		abilities.setVisible(phase == "InProgress")
		minimap.setVisible(phase == "InProgress")
		feed.setVisible(phase == "InProgress" or phase == "Ended")
		endScreen.setVisible(phase == "Ended")
		if phase ~= "InProgress" then
			shop.setVisible(false)
			scoreboard.setVisible(false)
		end
		if phase == "Lobby" then
			lobby.update(snapshot)
			banner.Text = "Hold H or click ? for controls"
		elseif phase == "ChampionSelect" then
			select.update(snapshot, localUserId)
			banner.Text = if snapshot.practice then "Practice draft" else "Champion select"
		elseif phase == "InProgress" then
			local mine = snapshot.players[tostring(localUserId)]
			banner.Text = if mine
				then `{mine.team} · H help · Tab · V cam · B shop · F recall · T emote · G ping · 4 ward · 5 lens`
				else "Spectating"
		elseif phase == "Ended" then
			endScreen.update(snapshot, localUserId)
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
		endScreen = endScreen,
		settings = settings,
		help = help,
		tips = tips,
		emotes = emotes,
		pings = pings,
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
