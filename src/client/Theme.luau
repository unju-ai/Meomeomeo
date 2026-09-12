--!strict

local Theme = {
	cream = Color3.fromRGB(255, 243, 224),
	foam = Color3.fromRGB(255, 252, 246),
	coral = Color3.fromRGB(255, 122, 98),
	peach = Color3.fromRGB(255, 184, 140),
	amber = Color3.fromRGB(255, 196, 74),
	ink = Color3.fromRGB(52, 36, 32),
	muted = Color3.fromRGB(122, 92, 80),
	blue = Color3.fromRGB(86, 148, 230),
	red = Color3.fromRGB(230, 86, 96),
	mint = Color3.fromRGB(120, 196, 150),
	panel = Color3.fromRGB(44, 30, 28),
	panelAlt = Color3.fromRGB(62, 42, 38),
	strokeColor = Color3.fromRGB(255, 220, 180),
	good = Color3.fromRGB(96, 196, 120),
	warn = Color3.fromRGB(230, 170, 70),
	bad = Color3.fromRGB(220, 80, 80),
	fontTitle = Enum.Font.FredokaOne,
	fontBody = Enum.Font.GothamMedium,
	fontMono = Enum.Font.GothamBold,
}

function Theme.corner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

function Theme.stroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0.25
	stroke.Parent = parent
	return stroke
end

function Theme.pad(parent: Instance, px: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, px)
	padding.PaddingBottom = UDim.new(0, px)
	padding.PaddingLeft = UDim.new(0, px)
	padding.PaddingRight = UDim.new(0, px)
	padding.Parent = parent
	return padding
end

function Theme.list(parent: Instance, padding: number, fill: Enum.FillDirection?)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = fill or Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

function Theme.text(parent: Instance, name: string, text: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = size
	label.TextColor3 = color
	label.Font = font or Theme.fontBody
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Parent = parent
	return label
end

function Theme.button(parent: Instance, name: string, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = true
	button.BackgroundColor3 = color
	button.Text = text
	button.TextColor3 = Theme.ink
	button.TextSize = 18
	button.Font = Theme.fontTitle
	button.AutoLocalize = false
	button.Parent = parent
	Theme.corner(button, 12)
	Theme.stroke(button, Theme.strokeColor, 2, 0.35)
	return button
end

return Theme
