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

local kickUntil = 0
local kickAmp = 0

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
	local kick = Vector3.zero
	if os.clock() < kickUntil and kickAmp > 0 then
		kick = Vector3.new(
			(math.random() - 0.5) * 2 * kickAmp,
			(math.random() - 0.5) * 0.8 * kickAmp,
			(math.random() - 0.5) * 1.2 * kickAmp
		)
	end
	camera.CFrame = CFrame.lookAt(root.Position + OFFSET + kick, lookAt())
	camera.FieldOfView = 62
end

-- Cheap legendary punch; pond owns the cam so CameraFollow.shake would no-op.
function KoiCamera.kick(amplitude: number, duration: number)
	kickAmp = math.max(0, amplitude)
	kickUntil = os.clock() + math.max(0, duration)
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
		kickUntil = 0
		kickAmp = 0
	end
end

function KoiCamera.setSubject(root: BasePart?)
	subject = root
end

function KoiCamera.isEnabled(): boolean
	return enabled
end

return KoiCamera
