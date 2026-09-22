--!strict

-- Paints the Cat Rift fight-begin cue. MatchStartJuice decides the beat.
-- The overlay does not take clicks. Fountain glow and the silhouette wash
-- are local and short. Kitty Caster's MatchLive line is unchanged.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MatchStartJuice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("MatchStartJuice"))
local Theme = require(script.Parent.Parent.Theme)
local Sfx = require(script.Parent.Parent.Audio.Sfx)

local MatchStartFx = {}

local wash: Frame? = nil
local label: TextLabel? = nil
local token = 0
local showing: MatchStartJuice.Kind? = nil
local lastText = ""
local fightShownFor: number? = nil
local armedFor: number? = nil
local watchConn: RBXScriptConnection? = nil
local padFolder: Folder? = nil

type Watch = {
	mode: string,
	phase: string?,
	startedAt: number?,
	inRoster: boolean,
	team: string?,
	userId: number,
}

local watch: Watch = {
	mode = "Hub",
	phase = nil,
	startedAt = nil,
	inRoster = false,
	team = nil,
	userId = 0,
}

local function rgb(triple: { number }): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

local function stopWatch()
	local conn = watchConn
	watchConn = nil
	if conn then
		conn:Disconnect()
	end
end

local function dismiss()
	token += 1
	showing = nil
	lastText = ""
	local frame = wash
	local text = label
	if frame then
		frame.BackgroundTransparency = 1
	end
	if text then
		text.TextTransparency = 1
		text.Text = ""
	end
end

function MatchStartFx.bind(gui: ScreenGui)
	if wash and label then
		return
	end
	local frame = Instance.new("Frame")
	frame.Name = "MatchStartWash"
	frame.Active = false
	frame.BackgroundColor3 = rgb(MatchStartJuice.Amber)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 24
	frame.Parent = gui
	wash = frame

	local text = Theme.text(gui, "MatchStartCue", "", 64, rgb(MatchStartJuice.Cream), Theme.fontTitle)
	text.Active = false
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.34)
	text.Size = UDim2.fromOffset(520, 84)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextStrokeTransparency = 0.35
	text.TextStrokeColor3 = rgb(MatchStartJuice.Ink)
	text.TextTransparency = 1
	text.ZIndex = 25
	label = text
end

local function showText(text: string, fight: boolean)
	local frame = wash
	local caption = label
	if not frame or not caption then
		return
	end
	token += 1
	local mine = token
	showing = if fight then "fight" else "count"
	lastText = text
	caption.Text = text
	caption.TextColor3 = rgb(MatchStartJuice.Cream)
	caption.TextTransparency = 1
	caption.TextSize = if fight then 42 else 56
	frame.BackgroundColor3 = rgb(MatchStartJuice.Amber)
	local popSize = if fight then 68 else 80
	TweenService:Create(caption, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		TextSize = popSize,
	}):Play()
	TweenService:Create(frame, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.9,
	}):Play()
	-- Digits stay up until the next beat. Only Fight! fades on its own.
	if not fight then
		return
	end
	task.delay(MatchStartJuice.FightHold, function()
		if mine ~= token then
			return
		end
		TweenService:Create(caption, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			TextSize = popSize - 8,
		}):Play()
		TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.24, function()
			if mine ~= token then
				return
			end
			showing = nil
			lastText = ""
		end)
	end)
end

local function padRoot(): Folder
	if padFolder and padFolder.Parent then
		return padFolder
	end
	local existing = Workspace:FindFirstChild("MeoMatchStart")
	if existing and existing:IsA("Folder") then
		padFolder = existing
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "MeoMatchStart"
	created.Parent = Workspace
	padFolder = created
	return created
end

local function glowPad(team: string)
	local x = MatchStartJuice.padX(team)
	local y = MatchStartJuice.PadY
	local z = MatchStartJuice.PadZ
	local parent = padRoot()
	local amber = rgb(MatchStartJuice.Amber)
	local cream = rgb(MatchStartJuice.Cream)

	local ring = Instance.new("Part")
	ring.Name = "StartPad"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = amber
	ring.Transparency = 0.45
	ring.Size = Vector3.new(0.12, 18, 18)
	ring.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = parent

	local lightPart = Instance.new("Part")
	lightPart.Name = "StartGlow"
	lightPart.Anchored = true
	lightPart.CanCollide = false
	lightPart.CanQuery = false
	lightPart.CanTouch = false
	lightPart.CastShadow = false
	lightPart.Transparency = 1
	lightPart.Size = Vector3.new(0.2, 0.2, 0.2)
	lightPart.CFrame = CFrame.new(x, y + 1.2, z)
	lightPart.Parent = parent

	local light = Instance.new("PointLight")
	light.Color = cream
	light.Brightness = 1.1
	light.Range = 18
	light.Shadows = false
	light.Parent = lightPart

	local life = MatchStartJuice.GlowSeconds
	TweenService:Create(ring, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
		Size = Vector3.new(0.08, 26, 26),
	}):Play()
	TweenService:Create(light, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Brightness = 0,
	}):Play()
	task.delay(life + 0.05, function()
		ring:Destroy()
		lightPart:Destroy()
	end)
end

local function washModel(model: Model)
	local cream = rgb(MatchStartJuice.Cream)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and child.Transparency < 0.95 then
			local part = child :: BasePart
			local baseColor = part.Color
			local baseTransparency = part.Transparency
			part.Color = baseColor:Lerp(cream, 0.28)
			task.delay(MatchStartJuice.WashSeconds, function()
				if not part.Parent then
					return
				end
				TweenService:Create(part, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Color = baseColor,
					Transparency = baseTransparency,
				}):Play()
			end)
		end
	end
end

local function washLocal(userId: number)
	local player = Players.LocalPlayer
	if not player or player.UserId ~= userId then
		return
	end
	local model = player.Character
	if model then
		washModel(model)
		return
	end
	task.delay(0.2, function()
		local later = player.Character
		if later then
			washModel(later)
		end
	end)
end

local function present(cue: MatchStartJuice.Cue)
	if cue.kind == "count" then
		armedFor = cue.startedAt
		if lastText ~= cue.text then
			showText(cue.text, false)
		end
		return
	end
	if fightShownFor == cue.startedAt then
		return
	end
	fightShownFor = cue.startedAt
	armedFor = nil
	showText(cue.text, true)
	local team = watch.team
	if cue.glow and (team == "Blue" or team == "Red") then
		glowPad(team)
	end
	if cue.glow then
		washLocal(watch.userId)
	end
	if cue.sting then
		Sfx.play("PingSoft", 0.78)
	end
end

local function step()
	local cue = MatchStartJuice.decide(
		watch.mode,
		watch.phase,
		watch.startedAt,
		Workspace:GetServerTimeNow(),
		watch.inRoster,
		fightShownFor,
		armedFor
	)
	if cue then
		present(cue)
	elseif not MatchStartJuice.modeAllows(watch.mode, watch.phase) then
		if showing ~= nil then
			dismiss()
		end
	elseif showing == "count" then
		dismiss()
	end
	local keep = MatchStartJuice.shouldWatch(
		watch.mode,
		watch.phase,
		watch.startedAt,
		Workspace:GetServerTimeNow(),
		watch.inRoster,
		fightShownFor
	)
	if keep then
		if not watchConn then
			watchConn = RunService.Heartbeat:Connect(function()
				step()
			end)
		end
	else
		stopWatch()
	end
end

function MatchStartFx.sync(
	gameMode: string,
	phase: string?,
	startedAt: number?,
	inRoster: boolean,
	team: string?,
	userId: number
)
	if startedAt ~= watch.startedAt then
		if showing ~= nil then
			dismiss()
		else
			lastText = ""
		end
		if fightShownFor ~= startedAt then
			armedFor = nil
		end
	end
	watch.mode = gameMode
	watch.phase = phase
	watch.startedAt = startedAt
	watch.inRoster = inRoster
	watch.team = team
	watch.userId = userId
	step()
end

return MatchStartFx
