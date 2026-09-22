--!strict

local Players = game:GetService("Players")

local Theme = require(script.Parent.Parent.Theme)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Types = require(Shared:WaitForChild("Types"))

local AbilityBar = require(script.Parent.AbilityBar)
local ChampionSelect = require(script.Parent.ChampionSelect)
local HubPanel = require(script.Parent.HubPanel)
local LobbyPanel = require(script.Parent.LobbyPanel)
local YarnRunHud = require(script.Parent.YarnRunHud)
local KoiPondHud = require(script.Parent.KoiPondHud)
local YarnPartyHud = require(script.Parent.YarnPartyHud)
local ArcadeHud = require(script.Parent.ArcadeHud)
local YarnBoardPanel = require(script.Parent.YarnBoardPanel)
local StallBoardPanel = require(script.Parent.StallBoardPanel)
local MintPanel = require(script.Parent.MintPanel)
local ClosetPanel = require(script.Parent.ClosetPanel)
local NpcChatPanel = require(script.Parent.NpcChatPanel)
local EconomyChip = require(script.Parent.EconomyChip)
local MatchClock = require(script.Parent.MatchClock)
local MemeTape = require(script.Parent.MemeTape)
local EndScreen = require(script.Parent.EndScreen)
local KillFeed = require(script.Parent.KillFeed)
local DeathRecap = require(script.Parent.DeathRecap)
local RespawnCountdown = require(script.Parent.RespawnCountdown)
local Minimap = require(script.Parent.Minimap)
local Scoreboard = require(script.Parent.Scoreboard)
local HelpPanel = require(script.Parent.HelpPanel)
local TutorialTips = require(script.Parent.TutorialTips)
local SettingsPanel = require(script.Parent.SettingsPanel)
local ShopPanel = require(script.Parent.ShopPanel)
local VoiceHud = require(script.Parent.VoiceHud)
local EmoteWheel = require(script.Parent.EmoteWheel)
local PingWheel = require(script.Parent.PingWheel)
local MatchStartFx = require(script.Parent.Parent.Juice.MatchStartFx)

local Hud = {}

export type HudApi = {
	gui: ScreenGui,
	hub: HubPanel.HubApi,
	lobby: LobbyPanel.LobbyApi,
	yarn: YarnRunHud.YarnHudApi,
	koi: KoiPondHud.KoiHudApi,
	party: YarnPartyHud.PartyHudApi,
	arcade: ArcadeHud.ArcadeHudApi,
	board: YarnBoardPanel.BoardApi,
	koiBoard: StallBoardPanel.StallBoardApi,
	arcadeBoard: StallBoardPanel.StallBoardApi,
	mint: MintPanel.MintApi,
	closet: ClosetPanel.ClosetApi,
	select: ChampionSelect.SelectApi,
	abilities: AbilityBar.BarApi,
	voice: VoiceHud.VoiceHudApi,
	chat: NpcChatPanel.ChatApi,
	shop: ShopPanel.ShopApi,
	minimap: Minimap.MinimapApi,
	scoreboard: Scoreboard.BoardApi,
	economy: EconomyChip.ChipApi,
	tape: MemeTape.TapeApi,
	feed: KillFeed.FeedApi,
	recap: DeathRecap.RecapApi,
	respawn: RespawnCountdown.CountdownApi,
	endScreen: EndScreen.EndApi,
	settings: SettingsPanel.SettingsApi,
	help: HelpPanel.HelpApi,
	tips: TutorialTips.TipsApi,
	emotes: EmoteWheel.WheelApi,
	pings: PingWheel.WheelApi,
	banner: (text: string, color: Color3?) -> (),
	callout: (text: string) -> (),
	ticker: (text: string) -> (),
	applyPhase: (snapshot: Types.MatchSnapshot, localUserId: number) -> (),
	applyShell: (mode: Types.GameMode, hubPage: "grid" | "moba", snapshot: Types.MatchSnapshot?, localUserId: number) -> (),
}

function Hud.create(): HudApi
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "MeoHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	MatchStartFx.bind(gui)

	local ticker = Theme.text(gui, "Ticker", "", 13, Theme.ink, Theme.fontMono)
	ticker.AnchorPoint = Vector2.new(0.5, 0)
	ticker.Position = UDim2.new(0.5, 0, 0, 8)
	ticker.Size = UDim2.fromOffset(640, 22)
	ticker.BackgroundColor3 = Theme.amber
	ticker.BackgroundTransparency = 0.12
	ticker.TextXAlignment = Enum.TextXAlignment.Center
	ticker.Visible = false
	Theme.corner(ticker, 8)
	Theme.pad(ticker, 4)
	local tickerSerial = 0

	local banner = Theme.text(gui, "Banner", "", 20, Theme.cream, Theme.fontTitle)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 40)
	banner.Size = UDim2.fromOffset(720, 28)
	banner.TextXAlignment = Enum.TextXAlignment.Center
	banner.TextStrokeTransparency = 0.4
	banner.ZIndex = 10
	local bannerHoldUntil = 0

	local function paintBanner(text: string, color: Color3?)
		banner.Text = text
		banner.TextColor3 = color or Theme.cream
	end

	local function forceBanner(text: string)
		bannerHoldUntil = 0
		paintBanner(text)
	end

	local function writeBanner(text: string)
		if os.clock() < bannerHoldUntil then
			return
		end
		paintBanner(text)
	end

	local hub = HubPanel.create(gui)
	local yarn = YarnRunHud.create(gui)
	local koi = KoiPondHud.create(gui)
	local party = YarnPartyHud.create(gui)
	local arcade = ArcadeHud.create(gui)
	local board = YarnBoardPanel.create(gui)
	local koiBoard = StallBoardPanel.create(gui, {
		name = "KoiBoard",
		title = "Canal Daily · Best Catch",
		empty = "No catches logged today. Land a cream loaf.",
		accent = Theme.mint,
	})
	local arcadeBoard = StallBoardPanel.create(gui, {
		name = "ArcadeBoard",
		title = "Arcade Daily",
		empty = "No tape settled today. Print some yarn.",
		accent = Theme.amber,
	})
	local lobby = LobbyPanel.create(gui)
	hub.setVisible(true)
	lobby.setVisible(false)
	yarn.setVisible(false)
	koi.setVisible(false)
	party.setVisible(false)
	arcade.setVisible(false)
	board.setVisible(false)
	koiBoard.setVisible(false)
	arcadeBoard.setVisible(false)
	local mint = MintPanel.create(gui)
	local closet = ClosetPanel.create(gui)
	local select = ChampionSelect.create(gui)
	local abilities = AbilityBar.create(gui)
	local voice = VoiceHud.create(gui)
	local chat = NpcChatPanel.create(gui)
	local shop = ShopPanel.create(gui)
	local minimap = Minimap.create(gui)
	local feed = KillFeed.create(gui)
	local recap = DeathRecap.create(gui)
	local respawn = RespawnCountdown.create(gui)
	local scoreboard = Scoreboard.create(gui)
	local economy = EconomyChip.create(gui)
	local clock = MatchClock.create(gui)
	local tape = MemeTape.create(gui)
	local endScreen = EndScreen.create(gui)
	local startVolume = player:GetAttribute(Constants.Attributes.SfxVolume)
	local startMuted = player:GetAttribute(Constants.Attributes.SfxMuted)
	local startMuteOthers = player:GetAttribute(Constants.Attributes.MuteOthersEmotes)
	local startHideName = player:GetAttribute(Constants.Attributes.HideBoardName)
	local startMusic = player:GetAttribute(Constants.Attributes.MusicVolume)
	local startMusicMuted = player:GetAttribute(Constants.Attributes.MusicMuted)
	local settings = SettingsPanel.create(gui, {
		sfxVolume = if typeof(startVolume) == "number" then startVolume :: number else 0.8,
		sfxMuted = startMuted == true,
		muteOthersEmotes = startMuteOthers == true,
		hideBoardName = startHideName == true,
		musicVolume = if typeof(startMusic) == "number" then startMusic :: number else 0.35,
		musicMuted = startMusicMuted == true,
	})
	local emotes = EmoteWheel.create(gui)
	local pings = PingWheel.create(gui)
	local help = HelpPanel.create(gui)
	local tips = TutorialTips.create(gui)

	local function hideMobaPlay()
		select.setVisible(false)
		abilities.setVisible(false)
		minimap.setVisible(false)
		feed.setVisible(false)
		recap.hide()
		respawn.hide()
		endScreen.setVisible(false)
		shop.setVisible(false)
		scoreboard.setVisible(false)
		economy.setVisible(false)
		clock.setVisible(false)
	end

	local function applyPhase(snapshot: Types.MatchSnapshot, localUserId: number)
		local phase = snapshot.phase
		lobby.setVisible(phase == "Lobby")
		hub.setVisible(false)
		yarn.setVisible(false)
		koi.setVisible(false)
		party.setVisible(false)
		arcade.setVisible(false)
		board.setVisible(false)
		koiBoard.setVisible(false)
		arcadeBoard.setVisible(false)
		if phase ~= "Lobby" then
			mint.setVisible(false)
			closet.setVisible(false)
		end
		select.setVisible(phase == "ChampionSelect")
		local mine = snapshot.players[tostring(localUserId)]
		abilities.setVisible(phase == "InProgress")
		economy.setVisible(phase == "InProgress" and mine ~= nil)
		if phase == "InProgress" and mine then
			economy.update(mine, snapshot.riverEpic)
		end
		if phase == "InProgress" then
			clock.show(snapshot.startedAt, snapshot.riverEpic)
			clock.setVisible(true)
		else
			clock.setVisible(false)
		end
		minimap.setVisible(phase == "InProgress")
		feed.setVisible(phase == "InProgress" or phase == "Ended")
		if phase ~= "InProgress" then
			recap.hide()
			respawn.hide()
		end
		endScreen.setVisible(phase == "Ended")
		if phase ~= "InProgress" then
			shop.setVisible(false)
			scoreboard.setVisible(false)
		end
		if phase == "Lobby" then
			lobby.update(snapshot)
			forceBanner("Cat Rift · ← Hub to change stalls")
		elseif phase == "ChampionSelect" then
			select.update(snapshot, localUserId)
			writeBanner(if snapshot.practice then "Practice draft" else "Champion select")
		elseif phase == "InProgress" then
			writeBanner(if mine
				then `{mine.team} · H help · Tab · V cam · B shop · F recall · T emote · G ping · 4 ward · 5 lens · 7 cleave`
				else "Spectating")
		elseif phase == "Ended" then
			endScreen.update(snapshot, localUserId)
		end
	end

	local function applyShell(
		mode: Types.GameMode,
		hubPage: "grid" | "moba",
		snapshot: Types.MatchSnapshot?,
		localUserId: number
	)
		local startPhase: string? = if snapshot then snapshot.phase else nil
		local startedAt = if snapshot then snapshot.startedAt else nil
		local inRoster = false
		local startTeam: string? = nil
		if snapshot then
			local mine = snapshot.players[tostring(localUserId)]
			if mine then
				inRoster = true
				startTeam = mine.team
			end
		end
		MatchStartFx.sync(mode, startPhase, startedAt, inRoster, startTeam, localUserId)
		if mode ~= "Hub" or (snapshot ~= nil and snapshot.phase ~= "Lobby") then
			chat.close()
		end
		if mode == "YarnRun" then
			hub.setVisible(false)
			lobby.setVisible(false)
			yarn.setVisible(true)
			koi.setVisible(false)
			party.setVisible(false)
			arcade.setVisible(false)
			koiBoard.setVisible(false)
			arcadeBoard.setVisible(false)
			hideMobaPlay()
			mint.setVisible(false)
			closet.setVisible(false)
			forceBanner("Yarn Run · chase the ghost · SPD MAG SHD 2X")
			return
		end
		if mode == "KoiPond" then
			hub.setVisible(false)
			lobby.setVisible(false)
			yarn.setVisible(false)
			koi.setVisible(true)
			party.setVisible(false)
			arcade.setVisible(false)
			board.setVisible(false)
			arcadeBoard.setVisible(false)
			hideMobaPlay()
			mint.setVisible(false)
			closet.setVisible(false)
			forceBanner("Koi Pond · Space cast · reel in the cream window")
			return
		end
		if mode == "YarnParty" then
			hub.setVisible(false)
			lobby.setVisible(false)
			yarn.setVisible(false)
			koi.setVisible(false)
			party.setVisible(true)
			arcade.setVisible(false)
			board.setVisible(false)
			koiBoard.setVisible(false)
			arcadeBoard.setVisible(false)
			hideMobaPlay()
			mint.setVisible(false)
			closet.setVisible(false)
			forceBanner("Yarn Party · WASD · Space hop · lit pillows")
			return
		end
		if mode == "MemeArcade" then
			hub.setVisible(false)
			lobby.setVisible(false)
			yarn.setVisible(false)
			koi.setVisible(false)
			party.setVisible(false)
			arcade.setVisible(true)
			board.setVisible(false)
			koiBoard.setVisible(false)
			hideMobaPlay()
			mint.setVisible(false)
			closet.setVisible(false)
			forceBanner("Meme Arcade · play yarn only · tap the tape")
			return
		end
		yarn.setVisible(false)
		koi.setVisible(false)
		party.setVisible(false)
		arcade.setVisible(false)
		if mode == "Hub" and hubPage == "grid" and (snapshot == nil or snapshot.phase == "Lobby") then
			hub.setVisible(true)
			lobby.setVisible(false)
			hideMobaPlay()
			forceBanner("Night-market hub · pick a stall")
			return
		end
		if snapshot then
			applyPhase(snapshot, localUserId)
		else
			hub.setVisible(true)
			lobby.setVisible(false)
			hideMobaPlay()
			forceBanner("Night-market hub · pick a stall")
		end
	end

	return {
		gui = gui,
		hub = hub,
		yarn = yarn,
		koi = koi,
		party = party,
		arcade = arcade,
		board = board,
		koiBoard = koiBoard,
		arcadeBoard = arcadeBoard,
		lobby = lobby,
		mint = mint,
		closet = closet,
		select = select,
		abilities = abilities,
		voice = voice,
		chat = chat,
		shop = shop,
		minimap = minimap,
		scoreboard = scoreboard,
		economy = economy,
		tape = tape,
		feed = feed,
		recap = recap,
		respawn = respawn,
		endScreen = endScreen,
		settings = settings,
		help = help,
		tips = tips,
		emotes = emotes,
		pings = pings,
		banner = function(text: string, color: Color3?)
			paintBanner(text, color)
		end,
		callout = function(text: string)
			paintBanner(text)
			bannerHoldUntil = os.clock() + 5
		end,
		aside = function(text: string)
			writeBanner(text)
		end,
		ticker = function(text: string)
			tickerSerial += 1
			local serial = tickerSerial
			ticker.Text = text
			ticker.Visible = text ~= ""
			if text ~= "" then
				task.delay(4.5, function()
					if tickerSerial == serial then
						ticker.Text = ""
						ticker.Visible = false
					end
				end)
			end
		end,
		applyPhase = applyPhase,
		applyShell = applyShell,
	}
end

return Hud
