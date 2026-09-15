--!strict

-- 3/4 chase cam: readable silhouette + lots of track ahead for streams.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local YarnCamera = {}

local bound = false
local enabled = false
local subject: BasePart? = nil

local OFFSET = Vector3.new(8, 11, -18)
local DEATH_OFFSET = Vector3.new(16, 18, -6)

local death = false
local deathT = 0

local function step()
	if not enabled then
		return
	end
	local camera = Workspace.CurrentCamera
	local root = subject
	if not camera or not root or not root.Parent then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local look = root.Position + Vector3.new(0, 3, if death then 8 else 18)
	local offset = OFFSET
	local fov = 68
	if death then
		deathT = math.clamp(deathT + 0.045, 0, 1)
		offset = OFFSET:Lerp(DEATH_OFFSET, deathT)
		fov = 68 - 16 * deathT
	else
		deathT = 0
	end
	camera.CFrame = CFrame.lookAt(root.Position + offset, look)
	camera.FieldOfView = fov
end

function YarnCamera.setDeath(on: boolean)
	death = on
	if not on then
		deathT = 0
	end
end

function YarnCamera.setEnabled(on: boolean)
	enabled = on
	local camera = Workspace.CurrentCamera
	if on then
		if not bound then
			RunService:BindToRenderStep("MeoYarnCam", Enum.RenderPriority.Camera.Value + 2, step)
			bound = true
		end
	else
		if bound then
			RunService:UnbindFromRenderStep("MeoYarnCam")
			bound = false
		end
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = 70
		end
		death = false
		deathT = 0
	end
end

function YarnCamera.setSubject(root: BasePart?)
	subject = root
end

function YarnCamera.isEnabled(): boolean
	return enabled
end

return YarnCamera
