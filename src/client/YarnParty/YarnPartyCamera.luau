--!strict

-- High 3/4 courtyard cam so all four cats stay on stream.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local YarnPartyCamera = {}

local bound = false
local enabled = false
local subject: BasePart? = nil

local OFFSET = Vector3.new(16, 24, 22)

local function lookAt(): Vector3
	return Constants.YarnPartyOrigin + Vector3.new(0, 1.2, 0)
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
	local from = if root and root.Parent then root.Position + OFFSET else Constants.YarnPartyOrigin + OFFSET
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(from, lookAt())
	camera.FieldOfView = 58
end

function YarnPartyCamera.setEnabled(on: boolean)
	enabled = on
	local camera = Workspace.CurrentCamera
	if on then
		if not bound then
			RunService:BindToRenderStep("MeoPartyCam", Enum.RenderPriority.Camera.Value + 2, step)
			bound = true
		end
	else
		if bound then
			RunService:UnbindFromRenderStep("MeoPartyCam")
			bound = false
		end
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = 70
		end
	end
end

function YarnPartyCamera.setSubject(root: BasePart?)
	subject = root
end

function YarnPartyCamera.isEnabled(): boolean
	return enabled
end

return YarnPartyCamera
