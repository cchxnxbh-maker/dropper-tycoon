--!strict
-- Widgets: the small kit screens are built from: a panel, a label and a button (ADR 0007). Each returns a plain
-- instance, styled from `Theme`. Sizes and positions are scale-based and come from the caller.
--
-- State owned: none. The caller owns what it builds and puts it in its Trove.
--
-- Usage:
--     local panel = Widgets.panel({ size = UDim2.fromScale(0.2, 0.2), position = UDim2.fromScale(0.02, 0.3) })
--     local button = Widgets.button({ text = "Add 1", size = UDim2.fromScale(1, 0.3) })
--     trove:Connect(button.Activated, onPress)

local Theme = require(script.Parent.Theme)

export type Box = { size: UDim2, position: UDim2?, anchor: Vector2?, order: number? }

local Widgets = {}

local function place(instance: GuiObject, box: Box)
	instance.Size = box.size
	instance.Position = box.position or UDim2.new()
	instance.AnchorPoint = box.anchor or Vector2.zero
	instance.LayoutOrder = box.order or 0
end

-- Keeps scaled text between the theme's smallest and largest sizes. The caller turns on TextScaled.
local function limitText(label: Instance)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = Theme.textSize.min
	limit.MaxTextSize = Theme.textSize.max
	limit.Parent = label
end

--[[
	A rounded, padded background that stacks its children top to bottom.
	@param box size and position
	@return the frame; parent children to it
]]
function Widgets.panel(box: Box): Frame
	local frame = Instance.new("Frame")
	place(frame, box)
	frame.BackgroundColor3 = Theme.colors.panel
	frame.BackgroundTransparency = Theme.transparency.panel
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.cornerRadius
	corner.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = Theme.padding
	padding.PaddingBottom = Theme.padding
	padding.PaddingLeft = Theme.padding
	padding.PaddingRight = Theme.padding
	padding.Parent = frame
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = Theme.padding
	list.Parent = frame
	return frame
end

--[[
	A line of text with no background.
	@param props the text, whether it is a heading, and its box
	@return the label
]]
function Widgets.label(props: { text: string, heading: boolean?, box: Box }): TextLabel
	local label = Instance.new("TextLabel")
	place(label, props.box)
	label.BackgroundTransparency = 1
	label.Text = props.text
	label.Font = if props.heading then Theme.fonts.heading else Theme.fonts.body
	label.TextColor3 = if props.heading then Theme.colors.text else Theme.colors.mutedText
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextScaled = true
	limitText(label)
	return label
end

--[[
	A rounded button. Connect to its `Activated` event, which fires for mouse, touch and gamepad alike.
	@param props the text and its box
	@return the button
]]
function Widgets.button(props: { text: string, box: Box }): TextButton
	local button = Instance.new("TextButton")
	place(button, props.box)
	button.BackgroundColor3 = Theme.colors.button
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = props.text
	button.Font = Theme.fonts.heading
	button.TextColor3 = Theme.colors.buttonText
	button.TextScaled = true
	limitText(button)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.cornerRadius
	corner.Parent = button
	return button
end

return Widgets
