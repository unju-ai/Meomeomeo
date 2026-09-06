--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local Minimap = {}

export type MinimapApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	update: (snapshot: Types.MatchSnapshot, vision: Types.VisionFrame, localUserId: number) -> (),
	showPing: (payload: Types.PingPayload) -> (),
	onPing: ((position: Vector3) -> ()) -> (),
	contains: (screenX: number, screenY: number) -> boolean,
}

local function worldToScale(position: Vector3): (number, number)
	local bounds = Constants.MapBounds
	local x = (position.X - bounds.MinX) / (bounds.MaxX - bounds.MinX)
	local z = (position.Z - bounds.MinZ) / (bounds.MaxZ - bounds.MinZ)
	return math.clamp(x, 0, 1), math.clamp(z, 0, 1)
end

local function scaleToWorld(x: number, z: number): Vector3
	local bounds = Constants.MapBounds
	return Vector3.new(
		bounds.MinX + math.clamp(x, 0, 1) * (bounds.MaxX - bounds.MinX),
		4,
		bounds.MinZ + math.clamp(z, 0, 1) * (bounds.MaxZ - bounds.MinZ)
	)
end

local function mark(parent: Instance, name: string, size: number, color: Color3): Frame
	local dot = Instance.new("Frame")
	dot.Name = name
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(size, size)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.ZIndex = 3
	dot.Parent = parent
	Theme.corner(dot, 99)
	return dot
end

function Minimap.create(parent: Instance): MinimapApi
	local root = Instance.new("TextButton")
	root.Name = "Minimap"
	root.AutoButtonColor = false
	root.Text = ""
	root.AnchorPoint = Vector2.new(1, 1)
	root.Position = UDim2.new(1, -16, 1, -16)
	root.Size = UDim2.fromOffset(200, 136)
	root.BackgroundColor3 = Color3.fromRGB(86, 122, 64)
	root.Visible = false
	root.Parent = parent
	Theme.corner(root, 12)
	Theme.stroke(root, Theme.amber, 2, 0.25)

	local river = Instance.new("Frame")
	river.Name = "River"
	river.AnchorPoint = Vector2.new(0.5, 0)
	river.Position = UDim2.fromScale(0.5, 0)
	river.Size = UDim2.fromScale(0.07, 1)
	river.BackgroundColor3 = Color3.fromRGB(90, 160, 210)
	river.BackgroundTransparency = 0.25
	river.BorderSizePixel = 0
	river.ZIndex = 1
	river.Parent = root

	for index, z in { -80, 0, 80 } do
		local sx, sy = worldToScale(Vector3.new(0, 0, z))
		local lane = Instance.new("Frame")
		lane.Name = `Lane{index}`
		lane.AnchorPoint = Vector2.new(0, 0.5)
		lane.Position = UDim2.fromScale(0.04, sy)
		lane.Size = UDim2.fromScale(0.92, 0.03)
		lane.BackgroundColor3 = Color3.fromRGB(196, 176, 132)
		lane.BackgroundTransparency = 0.15
		lane.BorderSizePixel = 0
		lane.ZIndex = 1
		lane.Parent = root
	end

	local title = Theme.text(root, "Title", "Rift  ·  click to ping", 11, Theme.cream, Theme.fontMono)
	title.Position = UDim2.fromOffset(8, 4)
	title.Size = UDim2.new(1, -16, 0, 14)
	title.ZIndex = 4

	local dots = Instance.new("Folder")
	dots.Name = "Dots"
	dots.Parent = root

	local pingDot = mark(root, "Ping", 14, Theme.amber)
	pingDot.Visible = false
	pingDot.ZIndex = 5

	local pingHandler: ((Vector3) -> ())? = nil

	root.MouseButton1Click:Connect(function()
		if not pingHandler then
			return
		end
		local mouse = Players.LocalPlayer:GetMouse()
		local abs = root.AbsolutePosition
		local size = root.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local x = (mouse.X - abs.X) / size.X
		local y = (mouse.Y - abs.Y) / size.Y
		pingHandler(scaleToWorld(x, y))
	end)

	local function place(name: string, position: Vector3, size: number, color: Color3, square: boolean?)
		local existing = dots:FindFirstChild(name)
		local dot = if existing and existing:IsA("Frame") then existing else mark(dots, name, size, color)
		dot.BackgroundColor3 = color
		dot.Size = UDim2.fromOffset(size, size)
		local sx, sy = worldToScale(position)
		dot.Position = UDim2.fromScale(sx, sy)
		if square then
			local corner = dot:FindFirstChildOfClass("UICorner")
			if corner then
				corner.CornerRadius = UDim.new(0, 2)
			end
		end
		dot.Visible = true
		return dot
	end

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if not visible then
				pingDot.Visible = false
			end
		end,
		update = function(snapshot: Types.MatchSnapshot, vision: Types.VisionFrame, localUserId: number)
			local seen: { [string]: boolean } = {}
			local visiblePlayers: { [number]: boolean } = {}
			for _, userId in vision.players do
				visiblePlayers[userId] = true
			end
			visiblePlayers[localUserId] = true
			local visibleMinions: { [string]: boolean } = {}
			for _, id in vision.minions do
				visibleMinions[id] = true
			end
			local map = Workspace:FindFirstChild(Constants.MapFolderName)

			for id, objective in snapshot.objectives do
				local part = nil
				local folder = if map then map:FindFirstChild("Objectives") else nil
				if folder then
					local child = folder:FindFirstChild(id)
					if child and child:IsA("BasePart") then
						part = child
					end
				end
				local pos = if part then part.Position else Vector3.zero
				if part then
					local color = if not objective.alive
						then Color3.fromRGB(50, 50, 50)
						elseif objective.team == "Blue" then Theme.blue
						else Theme.red
					local size = if objective.kind == "Nexus" then 10 else 7
					place(`obj-{id}`, pos, size, color, objective.kind == "Tower")
					seen[`obj-{id}`] = true
				end
			end

			local function placeChampion(userId: number, rootPart: BasePart, matchPlayer: Types.MatchPlayer)
				local mine = snapshot.players[tostring(localUserId)]
				local ally = mine ~= nil and matchPlayer.team == mine.team
				if not (ally or visiblePlayers[userId]) then
					return
				end
				local color = if userId == localUserId
					then Theme.cream
					elseif matchPlayer.team == "Blue" then Theme.blue
					else Theme.red
				local size = if userId == localUserId then 9 elseif matchPlayer.isBot then 6 else 7
				place(`p-{userId}`, rootPart.Position, size, color)
				seen[`p-{userId}`] = true
			end

			for _, other in Players:GetPlayers() do
				local matchPlayer = snapshot.players[tostring(other.UserId)]
				local character = other.Character
				local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
				if matchPlayer and rootPart and rootPart:IsA("BasePart") then
					placeChampion(other.UserId, rootPart, matchPlayer)
				end
			end

			local bots = if map then map:FindFirstChild("Bots") else nil
			if bots then
				for _, child in bots:GetChildren() do
					if child:IsA("Model") then
						local userId = child:GetAttribute(Constants.Attributes.UserId)
						local rootPart = child:FindFirstChild("HumanoidRootPart")
						if typeof(userId) == "number" and rootPart and rootPart:IsA("BasePart") then
							local matchPlayer = snapshot.players[tostring(userId)]
							if matchPlayer then
								placeChampion(userId, rootPart, matchPlayer)
							end
						end
					end
				end
			end

			local minions = if map then map:FindFirstChild("Minions") else nil
			local mine = snapshot.players[tostring(localUserId)]
			if minions then
				for _, child in minions:GetChildren() do
					if child:IsA("BasePart") then
						local team = child:GetAttribute(Constants.Attributes.Team)
						local ally = mine ~= nil and team == mine.team
						if ally or visibleMinions[child.Name] then
							local color = if team == "Blue" then Color3.fromRGB(160, 200, 255) else Color3.fromRGB(255, 170, 170)
							place(`m-{child.Name}`, child.Position, 4, color)
							seen[`m-{child.Name}`] = true
						end
					end
				end
			end

			local visibleJungle: { [string]: boolean } = {}
			for _, id in (vision.jungle or {}) do
				visibleJungle[id] = true
			end
			local jungle = if map then map:FindFirstChild("Jungle") else nil
			if jungle then
				for _, child in jungle:GetChildren() do
					if child:IsA("BasePart") and visibleJungle[child.Name] then
						place(`j-{child.Name}`, child.Position, 5, Theme.amber)
						seen[`j-{child.Name}`] = true
					end
				end
			end

			local visibleWards: { [string]: boolean } = {}
			for _, id in (vision.wards or {}) do
				visibleWards[id] = true
			end
			local wards = if map then map:FindFirstChild("Wards") else nil
			if wards then
				for _, child in wards:GetChildren() do
					if child:IsA("BasePart") and visibleWards[child.Name] then
						local team = child:GetAttribute(Constants.Attributes.Team)
						local color = if team == "Blue" then Color3.fromRGB(140, 210, 255) else Color3.fromRGB(255, 150, 170)
						place(`w-{child.Name}`, child.Position, 4, color, true)
						seen[`w-{child.Name}`] = true
					end
				end
			end

			for _, child in dots:GetChildren() do
				if child:IsA("Frame") and not seen[child.Name] then
					child:Destroy()
				end
			end
		end,
		showPing = function(payload: Types.PingPayload)
			local sx, sy = worldToScale(payload.position)
			pingDot.Position = UDim2.fromScale(sx, sy)
			pingDot.Visible = true
			task.delay(2.4, function()
				if pingDot.Parent then
					pingDot.Visible = false
				end
			end)
		end,
		onPing = function(fn)
			pingHandler = fn
		end,
		contains = function(screenX: number, screenY: number)
			if not root.Visible then
				return false
			end
			local abs = root.AbsolutePosition
			local size = root.AbsoluteSize
			return screenX >= abs.X and screenX <= abs.X + size.X and screenY >= abs.Y and screenY <= abs.Y + size.Y
		end,
	}
end

return Minimap
