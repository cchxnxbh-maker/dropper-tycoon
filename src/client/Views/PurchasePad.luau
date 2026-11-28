--!strict
-- PurchasePad: the floating label over a purchase pad (task 12): what it sells and the price. It only draws;
-- `PadController` says what to show, and changes it when the pad starts selling the next level.
--
-- State owned: the BillboardGui it builds, in its Trove.
--
-- Usage:
--     local view = PurchasePad.mount(padPart, "Coal Dropper", "$30")
--     view.set("Coal Dropper Lv 2", "$6")
--     view.destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Parent.UI.Kit.Theme)
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

export type View = { set: (name: string, price: string) -> (), destroy: () -> () }

-- Size of the label in studs, and how high above the pad it floats.
local SIZE = UDim2.fromScale(8, 3)
local LIFT = Vector3.new(0, 3, 0)
-- Beyond this many studs the label hides, so a plot full of pads stays readable.
local MAX_DISTANCE = 80

local PurchasePad = {}

local function line(
	text: string,
	height: number,
	top: number,
	font: Enum.Font,
	color: Color3,
	parent: Instance
): TextLabel
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
	return label
end

--[[
	Builds the label over a pad.
	@param pad the pad part
	@param name what the pad sells: the machine's name, or its name and next level
	@param price the formatted price, or the word for free
	@return the view: `set` changes both lines, `destroy` removes the label
]]
function PurchasePad.mount(pad: BasePart, name: string, price: string): View
	local trove = Trove.new()
	local gui = trove:Add(Instance.new("BillboardGui"))
	gui.Size = SIZE
	gui.StudsOffsetWorldSpace = LIFT
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local nameLabel = line(name, 0.55, 0, Theme.fonts.heading, Theme.colors.text, gui)
	local priceLabel = line(price, 0.45, 0.55, Theme.fonts.body, Theme.colors.signText, gui)
	gui.Adornee = pad
	gui.Parent = pad

	return {
		set = function(newName: string, newPrice: string)
			nameLabel.Text = newName
			priceLabel.Text = newPrice
		end,
		destroy = function()
			trove:Destroy()
		end,
	}
end

return PurchasePad
