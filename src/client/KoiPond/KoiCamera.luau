--!strict

-- Cozy 3/4 pond cam: dock silhouette + canal lanterns for streams.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local KoiCamera = {}

local bound = false
local enabled = false
local subject: BasePart? = nil

local OFFSET = Vector3.new(10, 13, -16)

local function lookAt(): Vector3
	return Constants.KoiPondOrigin + Vector3.new(0, 1.4, 4)
end

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
	camera.CFrame = CFrame.lookAt(root.Position + OFFSET, lookAt())
	camera.FieldOfView = 62
end

function KoiCamera.setEnabled(on: boolean)
	enabled = on
	local camera = Workspace.CurrentCamera
	if on then
		if not bound then
			RunService:BindToRenderStep("MeoKoiCam", Enum.RenderPriority.Camera.Value + 2, step)
			bound = true
		end
	else
		if bound then
			RunService:UnbindFromRenderStep("MeoKoiCam")
			bound = false
		end
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = 70
		end
	end
end

function KoiCamera.setSubject(root: BasePart?)
	subject = root
end

function KoiCamera.isEnabled(): boolean
	return enabled
end

return KoiCamera
