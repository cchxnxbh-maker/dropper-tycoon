--!strict
-- DevPanel: the developer panel's view (plan section 4.10, task 10). A small box on the left of the screen with the
-- saved test counter and one button per dev command. It only draws; `DevPanelController` decides when it shows and
-- what each button does.
--
-- State owned: the instances it builds, in its Trove.
--
-- Usage:
--     local view = DevPanel.mount(screenGui, { buttons = { { text = "Add 1", command = "AddTestCounter" } },
--         onCommand = function(command) ... end })
--     view.setCounter(3)
--     view.destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Text = require(Shared:WaitForChild("Util"):WaitForChild("Text"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Widgets = require(script.Parent.Parent.Kit.Widgets)

export type Button = { text: string, command: string }
export type Actions = { buttons: { Button }, onCommand: (command: string) -> () }
export type View = { setCounter: (value: number) -> (), destroy: () -> () }

local DevPanel = {}

--[[
	Builds the panel.
	@param parent the ScreenGui to build it in
	@param actions the buttons, top to bottom, and what a press calls with the button's command
	@return the view: `setCounter` shows a new value, `destroy` removes everything it built
]]
function DevPanel.mount(parent: Instance, actions: Actions): View
	local strings = Config.Strings.DevPanel
	local trove = Trove.new()

	-- Each row is about a twentieth of the screen high, so the panel grows with the number of buttons.
	local rows = 2 + #actions.buttons
	local panel = trove:Add(Widgets.panel({
		size = UDim2.fromScale(0.16, 0.065 * rows),
		position = UDim2.fromScale(0.01, 0.5),
		anchor = Vector2.new(0, 0.5),
	}))
	local rowHeight = UDim2.new(1, 0, 0.8 / rows, 0)
	Widgets.label({ text = strings.title, heading = true, box = { size = rowHeight, order = 1 } }).Parent = panel
	local counter = Widgets.label({ text = "", box = { size = rowHeight, order = 2 } })
	counter.Parent = panel
	for index, spec in actions.buttons do
		local button = Widgets.button({ text = spec.text, box = { size = rowHeight, order = 2 + index } })
		button.Parent = panel
		trove:Connect(button.Activated, function()
			actions.onCommand(spec.command)
		end)
	end
	panel.Parent = parent

	local view = {}

	function view.setCounter(value: number)
		counter.Text = Text.format(strings.counter, { value = value })
	end

	function view.destroy()
		trove:Destroy()
	end

	return view
end

return DevPanel
