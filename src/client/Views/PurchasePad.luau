--!strict
-- PurchasePad: the floating label over a purchase pad (task 12): the machine's name and its price. It only draws;
-- `PadController` says what to show.
--
-- State owned: the BillboardGui it builds, in its Trove.
--
-- Usage:
--     local view = PurchasePad.mount(padPart, "Coal Dropper", "$30")
--     view.destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Parent.UI.Kit.Theme)
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

export type View = { destroy: () -> () }

-- Size of the label in studs, and how high above the pad it floats.
local SIZE = UDim2.fromScale(8, 3)
local LIFT = Vector3.new(0, 3, 0)
-- Beyond this many studs the label hides, so a plot full of pads stays readable.
local MAX_DISTANCE = 80

local PurchasePad = {}

local function line(text: string, height: number, top: number, font: Enum.Font, color: Color3, parent: Instance)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, height)
	label.Position = UDim2.fromScale(0, top)
	label.Font = font
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Parent = parent
end

--[[
	Builds the label over a pad.
	@param pad the pad part
	@param name the machine's name
	@param price the formatted price, or the word for free
	@return the view: `destroy` removes the label
]]
function PurchasePad.mount(pad: BasePart, name: string, price: string): View
	local trove = Trove.new()
	local gui = trove:Add(Instance.new("BillboardGui"))
	gui.Size = SIZE
	gui.StudsOffsetWorldSpace = LIFT
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	line(name, 0.55, 0, Theme.fonts.heading, Theme.colors.text, gui)
	line(price, 0.45, 0.55, Theme.fonts.body, Theme.colors.signText, gui)
	gui.Adornee = pad
	gui.Parent = pad

	return {
		destroy = function()
			trove:Destroy()
		end,
	}
end

return PurchasePad
