--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraFollow = {}

local bound = false
local enabled = false
local subject: BasePart? = nil

local OFFSET = Vector3.new(0, 28, 22)

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
	local lookAt = root.Position + Vector3.new(0, 3, 0)
	camera.CFrame = CFrame.lookAt(root.Position + OFFSET, lookAt)
end

function CameraFollow.setEnabled(on: boolean)
	enabled = on
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if on then
		if not bound then
			RunService:BindToRenderStep("MeoCamera", Enum.RenderPriority.Camera.Value + 1, step)
			bound = true
		end
	else
		if bound then
			RunService:UnbindFromRenderStep("MeoCamera")
			bound = false
		end
		camera.CameraType = Enum.CameraType.Custom
	end
end

function CameraFollow.setSubject(root: BasePart?)
	subject = root
end

function CameraFollow.isEnabled(): boolean
	return enabled
end

return CameraFollow
