--!strict

-- Client paint for champion MeoNameplate HP fills. Reuses server BillboardGui
-- structure; only updates dirty plates. Fog / ally rules live in Shared.ChampionPlate.
-- Does not touch BillboardHpBars (structures / kittens / camps).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ChampionPlate = require(Shared:WaitForChild("ChampionPlate"))
local Constants = require(Shared:WaitForChild("Constants"))

local ChampionPlates = {}

export type SyncCtx = {
	active: boolean,
	localUserId: number,
	localTeam: string?,
	-- userId -> visible (from VisionUpdated players list + self).
	playerVisible: { [number]: boolean }?,
	-- userId -> MatchPlayer fields we need.
	players: {
		[string]: {
			team: string?,
			isBot: boolean?,
			respawnAt: number?,
		},
	}?,
}

type PlateRefs = {
	gui: BillboardGui,
	fill: Frame,
	champ: TextLabel,
	role: TextLabel,
	lastKey: string,
}

local plates: { [BillboardGui]: PlateRefs } = {}

local function rgb(triplet: { number }): Color3
	return Color3.fromRGB(triplet[1], triplet[2], triplet[3])
end

local function findPlate(model: Model): BillboardGui?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		local onRoot = root:FindFirstChild(ChampionPlate.GuiName)
		if onRoot and onRoot:IsA("BillboardGui") then
			return onRoot
		end
	end
	local nested = model:FindFirstChild(ChampionPlate.GuiName, true)
	if nested and nested:IsA("BillboardGui") then
		return nested
	end
	return nil
end

local function ensureRefs(gui: BillboardGui): PlateRefs?
	local existing = plates[gui]
	if existing and existing.gui.Parent then
		return existing
	end
	local track = gui:FindFirstChild(ChampionPlate.TrackName)
	local fill = if track then track:FindFirstChild(ChampionPlate.FillName) else nil
	local champ = gui:FindFirstChild(ChampionPlate.ChampName)
	local role = gui:FindFirstChild(ChampionPlate.RoleName)
	if
		not (
			track
			and track:IsA("Frame")
			and fill
			and fill:IsA("Frame")
			and champ
			and champ:IsA("TextLabel")
			and role
			and role:IsA("TextLabel")
		)
	then
		return nil
	end
	local refs: PlateRefs = {
		gui = gui,
		fill = fill :: Frame,
		champ = champ :: TextLabel,
		role = role :: TextLabel,
		lastKey = "",
	}
	plates[gui] = refs
	return refs
end

local function readHp(model: Model): (number, number)
	local healthAttr = model:GetAttribute("Health")
	local maxAttr = model:GetAttribute("MaxHealth")
	if typeof(healthAttr) == "number" and typeof(maxAttr) == "number" and maxAttr > 0 then
		return healthAttr, maxAttr
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid.Health, humanoid.MaxHealth
	end
	return 0, 0
end

local function paint(
	refs: PlateRefs,
	health: number,
	maxHealth: number,
	show: boolean,
	nameText: string,
	tagText: string,
	team: string?
)
	local key = ChampionPlate.paintKey(health, maxHealth, show, nameText, tagText, team)
	if key == refs.lastKey then
		return
	end
	refs.lastKey = key
	local ratio = ChampionPlate.ratio(health, maxHealth)
	local tone = ChampionPlate.fillTone(ratio)
	refs.fill.Size = UDim2.fromScale(ratio, 1)
	refs.fill.BackgroundColor3 = rgb(ChampionPlate.teamFillRgb(tone, team))
	refs.champ.Text = nameText
	refs.role.Text = tagText
	-- hideTree also toggles Enabled for fog; force-off when the plate rule says hide.
	if not show then
		refs.gui.Enabled = false
	elseif refs.gui.Enabled == false then
		refs.gui.Enabled = true
	end
end

local function syncModel(model: Model, ctx: SyncCtx, userId: number, seen: { [BillboardGui]: boolean }, count: number): number
	if count >= ChampionPlate.MaxPlates then
		return count
	end
	local plate = findPlate(model)
	if not plate then
		return count
	end
	local refs = ensureRefs(plate)
	if not refs then
		return count
	end
	seen[plate] = true

	local row = if ctx.players then ctx.players[tostring(userId)] else nil
	local team = if row and (row.team == "Blue" or row.team == "Red") then row.team else nil
	local ally = ctx.localTeam ~= nil and team == ctx.localTeam
	local alive = row == nil or row.respawnAt == nil
	local inVision = ctx.playerVisible ~= nil and ctx.playerVisible[userId] == true
	if userId == ctx.localUserId then
		inVision = true
		ally = true
	end
	local show = ctx.active
		and ChampionPlate.show({
			alive = alive,
			ally = ally == true,
			inVision = inVision,
		})
	local health, maxHealth = readHp(model)
	if not alive then
		health = 0
	end

	local champAttr = plate:GetAttribute("ChampName")
	local botAttr = plate:GetAttribute("IsBot")
	local tagAttr = plate:GetAttribute("RoleTag")
	local champName = if typeof(champAttr) == "string" and champAttr ~= "" then champAttr else "Cat"
	local isBot = botAttr == true or (row ~= nil and row.isBot == true)
	local tagText = if typeof(tagAttr) == "string" and tagAttr ~= "" then tagAttr else refs.role.Text
	local nameText = ChampionPlate.nameLine(champName, isBot, userId == ctx.localUserId)
	paint(refs, health, maxHealth, show, nameText, tagText, team)
	return count + 1
end

function ChampionPlates.clear()
	table.clear(plates)
end

function ChampionPlates.sync(ctx: SyncCtx)
	if not ctx.active then
		ChampionPlates.clear()
		return
	end

	local seen: { [BillboardGui]: boolean } = {}
	local count = 0

	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character then
			count = syncModel(character, ctx, other.UserId, seen, count)
		end
	end

	local map = Workspace:FindFirstChild(Constants.MapFolderName)
	local bots = if map then map:FindFirstChild("Bots") else nil
	if bots then
		for _, child in bots:GetChildren() do
			if child:IsA("Model") then
				local userId = child:GetAttribute(Constants.Attributes.UserId)
				if typeof(userId) == "number" then
					count = syncModel(child, ctx, userId, seen, count)
				end
			end
		end
	end

	local stale: { BillboardGui } = {}
	for gui in plates do
		if not seen[gui] or gui.Parent == nil then
			table.insert(stale, gui)
		end
	end
	for _, gui in stale do
		plates[gui] = nil
	end
end

return ChampionPlates
