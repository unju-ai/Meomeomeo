--!strict

-- 3/4 stall cam: neon tape wall + yarn bags stay on stream.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local ArcadeCamera = {}

local bound = false
local enabled = false
local subject: BasePart? = nil

local OFFSET = Vector3.new(0, 11, 16)

local function lookAt(): Vector3
	return Constants.MemeArcadeOrigin + Vector3.new(0, 5.4, -8)
end

local function step()
	if not enabled then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local root = subject
	local from = if root and root.Parent then root.Position + OFFSET else Constants.MemeArcadeOrigin + OFFSET
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(from, lookAt())
	camera.FieldOfView = 58
end

function ArcadeCamera.setEnabled(on: boolean)
	enabled = on
	local camera = Workspace.CurrentCamera
	if on then
		if not bound then
			RunService:BindToRenderStep("MeoArcadeCam", Enum.RenderPriority.Camera.Value + 2, step)
			bound = true
		end
	else
		if bound then
			RunService:UnbindFromRenderStep("MeoArcadeCam")
			bound = false
		end
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = 70
		end
	end
end

function ArcadeCamera.setSubject(root: BasePart?)
	subject = root
end

function ArcadeCamera.isEnabled(): boolean
	return enabled
end

return ArcadeCamera
