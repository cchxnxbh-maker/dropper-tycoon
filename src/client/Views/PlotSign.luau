--!strict
-- PlotSign: the text on a plot's sign (task 10). Two lines on the sign's front face: who owns the plot, and its
-- number. It only draws; `PlotSignController` says what to show.
--
-- State owned: the SurfaceGui it builds, in its Trove.
--
-- Usage:
--     local view = PlotSign.mount(signPart)
--     view.set("Your factory", "Plot 3")
--     view.destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Parent.UI.Kit.Theme)
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

export type View = { set: (owner: string, number: string) -> (), destroy: () -> () }

-- Pixels per stud on the sign. Higher is sharper text and more memory; 50 is Roblox's own default.
local PIXELS_PER_STUD = 50

local PlotSign = {}

local function line(text: string, size: UDim2, position: UDim2, font: Enum.Font, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = font
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Theme.colors.signText
	label.Parent = parent
	return label
end

--[[
	Builds the sign's text on its front face.
	@param sign the plot's Sign part
	@return the view: `set` changes both lines, `destroy` removes the text
]]
function PlotSign.mount(sign: BasePart): View
	local trove = Trove.new()
	local gui = trove:Add(Instance.new("SurfaceGui"))
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	-- The owner line takes the top 60% of the sign, the plot number most of the rest.
	local owner = line("", UDim2.fromScale(0.9, 0.5), UDim2.fromScale(0.05, 0.1), Theme.fonts.heading, gui)
	local number = line("", UDim2.fromScale(0.9, 0.25), UDim2.fromScale(0.05, 0.65), Theme.fonts.body, gui)
	gui.Parent = sign

	local view = {}

	function view.set(ownerText: string, numberText: string)
		owner.Text = ownerText
		number.Text = numberText
	end

	function view.destroy()
		trove:Destroy()
	end

	return view
end

return PlotSign
