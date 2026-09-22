--!strict

-- Brief Closet equip / unlock flash on welded MeoCosmetics parts (client juice only).

local TweenService = game:GetService("TweenService")

local CosmeticJuice = {}

local FOLDER_NAME = "MeoCosmetics"
local token = 0

function CosmeticJuice.flashAvatar(character: Model?, tint: Color3?)
	if not character then
		return
	end
	local folder = character:FindFirstChild(FOLDER_NAME)
	if not folder then
		return
	end
	token += 1
	local serial = token
	local color = tint or Color3.fromRGB(255, 196, 74)
	for _, child in folder:GetDescendants() do
		if child:IsA("BasePart") then
			local part = child :: BasePart
			local baseTransparency = part.Transparency
			local baseColor = part.Color
			local baseMaterial = part.Material
			part.Color = color
			if baseMaterial ~= Enum.Material.Neon and baseMaterial ~= Enum.Material.ForceField then
				part.Material = Enum.Material.Neon
			end
			TweenService:Create(part, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = math.max(0, baseTransparency - 0.15),
			}):Play()
			task.delay(0.28, function()
				if serial ~= token or not part.Parent then
					return
				end
				part.Material = baseMaterial
				TweenService:Create(part, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Transparency = baseTransparency,
					Color = baseColor,
				}):Play()
			end)
		elseif child:IsA("PointLight") then
			local light = child :: PointLight
			local base = light.Brightness
			local baseColor = light.Color
			light.Color = color
			light.Brightness = base + 0.55
			task.delay(0.35, function()
				if serial ~= token or not light.Parent then
					return
				end
				TweenService:Create(light, TweenInfo.new(0.28), {
					Brightness = base,
					Color = baseColor,
				}):Play()
			end)
		end
	end
end

return CosmeticJuice
