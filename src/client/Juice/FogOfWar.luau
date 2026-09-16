--!strict

-- Client-only ground overlay. The server owns the bit mask; this just paints it.

local Workspace = game:GetService("Workspace")

local VisionLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("VisionLogic"))

local FogOfWar = {}

local FOLDER_NAME = "MeoFog"
local COLOR = Color3.fromRGB(10, 12, 22)
local Y = 0.58
local THICKNESS = 0.22

local folder: Folder? = nil
local cells: { BasePart } = {}
local explored: { boolean } = table.create(VisionLogic.CellCount, false)
local enabled = false
local built = false

local function ensureExplored()
	if #explored ~= VisionLogic.CellCount then
		explored = table.create(VisionLogic.CellCount, false)
	end
	return explored
end

local function makeFolder(): Folder
	if folder then
		if folder.Parent ~= Workspace then
			folder.Parent = Workspace
		end
		return folder
	end
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = Workspace
	folder = created
	return created
end

local function neighborLit(words: { number }, index: number): boolean
	local i = index - 1
	local col = i % VisionLogic.Cols
	local row = math.floor(i / VisionLogic.Cols)
	local offsets = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	for _, d in offsets do
		local cc = col + d[1]
		local rr = row + d[2]
		if cc >= 0 and cc < VisionLogic.Cols and rr >= 0 and rr < VisionLogic.Rows then
			if VisionLogic.bitOn(words, rr * VisionLogic.Cols + cc + 1) then
				return true
			end
		end
	end
	return false
end

local function build()
	if built then
		return
	end
	local root = makeFolder()
	local size = VisionLogic.CellSize
	for index = 1, VisionLogic.CellCount do
		local cx, cz = VisionLogic.center(index)
		local part = Instance.new("Part")
		part.Name = `Cell{index}`
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = COLOR
		part.Size = Vector3.new(size * 1.04, THICKNESS, size * 1.04)
		part.CFrame = CFrame.new(cx, Y, cz)
		part.Transparency = 0.2
		part.Parent = root
		cells[index] = part
	end
	built = true
end

function FogOfWar.resetExplored()
	local flags = ensureExplored()
	for i = 1, VisionLogic.CellCount do
		flags[i] = false
	end
end

function FogOfWar.isExplored(index: number): boolean
	return ensureExplored()[index] == true
end

function FogOfWar.setEnabled(on: boolean)
	enabled = on
	if not on then
		if folder then
			folder.Parent = nil
		end
		return
	end
	build()
	makeFolder()
end

function FogOfWar.apply(words: { number }?)
	if not enabled then
		return
	end
	if typeof(words) ~= "table" or #words < 1 then
		return
	end
	build()
	local flags = ensureExplored()
	local mask = words
	for index = 1, VisionLogic.CellCount do
		local part = cells[index]
		if part then
			local lit = VisionLogic.bitOn(mask, index)
			if lit then
				flags[index] = true
				part.Transparency = 1
			elseif flags[index] then
				part.Transparency = if neighborLit(mask, index) then 0.7 else 0.42
			else
				part.Transparency = 0.16
			end
		end
	end
end

return FogOfWar
