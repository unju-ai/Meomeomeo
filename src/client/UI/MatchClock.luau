--!strict

-- Cat Rift match clock and Canal Levi line. Shown only while the fight is
-- InProgress. startedAt and riverEpic.nextAt come from the snapshot; this paints.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RiverEpic = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RiverEpic"))
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local MatchClock = {}

export type ClockApi = {
	root: Frame,
	setVisible: (visible: boolean) -> (),
	show: (startedAt: number?, epic: Types.RiverEpicView?) -> (),
}

local TONE_COLOR: { [RiverEpic.HudTone]: Color3 } = {
	wait = Theme.amber,
	up = Theme.mint,
	spent = Theme.muted,
}

function MatchClock.create(parent: Instance): ClockApi
	local root = Instance.new("Frame")
	root.Name = "MatchClock"
	root.AnchorPoint = Vector2.new(0, 0)
	root.Position = UDim2.fromOffset(16, 12)
	root.Size = UDim2.fromOffset(156, 52)
	root.BackgroundColor3 = Theme.panel
	root.Visible = false
	root.ZIndex = 12
	root.Parent = parent
	Theme.corner(root, 12)
	Theme.stroke(root, Theme.amber, 1.5, 0.2)
	Theme.pad(root, 6)

	local clock = Theme.text(root, "Clock", "0:00", 18, Theme.cream, Theme.fontMono)
	clock.Size = UDim2.new(1, 0, 0, 20)
	clock.TextXAlignment = Enum.TextXAlignment.Center
	clock.TextWrapped = false
	clock.ZIndex = 13

	local objective = Theme.text(root, "Levi", "", 13, Theme.amber, Theme.fontTitle)
	objective.Position = UDim2.fromOffset(0, 20)
	objective.Size = UDim2.new(1, 0, 0, 18)
	objective.TextXAlignment = Enum.TextXAlignment.Center
	objective.TextWrapped = false
	objective.ZIndex = 13

	local startedAt: number? = nil
	local epic: Types.RiverEpicView? = nil
	local painted = ""

	local function paint()
		if not root.Visible then
			return
		end
		local phase = if epic then epic.phase else nil
		local nextAt = if epic then epic.nextAt else nil
		local read = RiverEpic.hudRead(Workspace:GetServerTimeNow(), startedAt, phase, nextAt)
		local key = `{read.clock}|{read.objective}|{read.tone}`
		if key == painted then
			return
		end
		painted = key
		clock.Text = read.clock
		objective.Text = read.objective
		objective.Visible = read.objective ~= ""
		objective.TextColor3 = TONE_COLOR[read.tone]
	end

	RunService.Heartbeat:Connect(function()
		paint()
	end)

	return {
		root = root,
		setVisible = function(visible: boolean)
			root.Visible = visible
			if visible then
				painted = ""
				paint()
			end
		end,
		show = function(nextStarted: number?, nextEpic: Types.RiverEpicView?)
			startedAt = nextStarted
			epic = nextEpic
			painted = ""
			paint()
		end,
	}
end

return MatchClock
