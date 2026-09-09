--!strict

-- 3/4 chase cam: readable silhouette + lots of track ahead for streams.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local YarnCamera = {}

local bound = false
local enabled = false
local subject: BasePart? = nil

local OFFSET = Vector3.new(8, 11, -18)

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
	local look = root.Position + Vector3.new(0, 3, 18)
	camera.CFrame = CFrame.lookAt(root.Position + OFFSET, look)
	camera.FieldOfView = 68
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
	end
end

function YarnCamera.setSubject(root: BasePart?)
	subject = root
end

function YarnCamera.isEnabled(): boolean
	return enabled
end

return YarnCamera
