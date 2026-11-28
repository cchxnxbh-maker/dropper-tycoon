--!strict
-- Hud: the always-on display at the top of the screen (plan section 4.5): cash, cash per second under it, and a short
-- message below for a moment when something needs saying. It only draws; `HudController` says what to show.
--
-- State owned: the instances it builds, in its Trove.
--
-- Usage:
--     local view = Hud.mount(screenGui)
--     view.setCash("$1,234")
--     view.setRate("+$12/s")
--     view.toast("Not enough cash yet")
--     view.destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Parent.Kit.Theme)
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Widgets = require(script.Parent.Parent.Kit.Widgets)

export type View = {
	setCash: (text: string) -> (),
	setRate: (text: string) -> (),
	toast: (text: string) -> (),
	destroy: () -> (),
}

-- How long a message stays, in seconds.
local TOAST_SECONDS = 2

local Hud = {}

--[[
	Builds the cash display.
	@param parent the ScreenGui to build it in
	@return the view: `setCash` and `setRate` change the two lines, `destroy` removes everything it built
]]
function Hud.mount(parent: Instance): View
	local trove = Trove.new()
	local panel = trove:Add(Widgets.panel({
		size = UDim2.fromScale(0.18, 0.1),
		position = UDim2.fromScale(0.5, 0.02),
		anchor = Vector2.new(0.5, 0),
	}))
	local cash = Widgets.label({ text = "", heading = true, box = { size = UDim2.fromScale(1, 0.55), order = 1 } })
	cash.TextXAlignment = Enum.TextXAlignment.Center
	cash.Parent = panel
	local rate = Widgets.label({ text = "", box = { size = UDim2.fromScale(1, 0.3), order = 2 } })
	rate.TextXAlignment = Enum.TextXAlignment.Center
	rate.TextColor3 = Theme.colors.button
	rate.Parent = panel
	panel.Parent = parent
	local message = trove:Add(Widgets.label({
		text = "",
		heading = true,
		box = {
			size = UDim2.fromScale(0.3, 0.04),
			position = UDim2.fromScale(0.5, 0.13),
			anchor = Vector2.new(0.5, 0),
		},
	}))
	message.TextXAlignment = Enum.TextXAlignment.Center
	message.TextColor3 = Theme.colors.text
	message.TextStrokeTransparency = 0.3
	message.Visible = false
	message.Parent = parent
	local shown = 0

	local view = {}

	function view.toast(text: string)
		shown += 1
		local mine = shown
		message.Text = text
		message.Visible = true
		task.delay(TOAST_SECONDS, function()
			-- Only the latest message hides itself, so a new one keeps its full time.
			if shown == mine then
				message.Visible = false
			end
		end)
	end

	function view.setCash(text: string)
		if cash.Text ~= text then
			cash.Text = text
		end
	end

	function view.setRate(text: string)
		if rate.Text ~= text then
			rate.Text = text
		end
	end

	function view.destroy()
		trove:Destroy()
	end

	return view
end

return Hud
