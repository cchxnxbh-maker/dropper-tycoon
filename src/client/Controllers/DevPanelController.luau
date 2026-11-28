--!strict
-- DevPanelController: shows the dev panel when the server says this player may use it, and sends its commands
-- (plan section 4.10, task 10). The server decides who may; the panel appears when the first `DevPanelState`
-- arrives, so other players never see it.
--
-- State owned: the dev panel's ScreenGui and view.
--
-- Usage, in Main:
--     DevPanelController.init()
--     DevPanelController.start()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbuseCases = require(Shared:WaitForChild("Network"):WaitForChild("AbuseCases"))
local ClientNet = require(script.Parent.Parent.Net.ClientNet)
local Config = require(Shared:WaitForChild("Config"))
local DevPanel = require(script.Parent.Parent.UI.Screens.DevPanel)
local NumberFormat = require(Shared:WaitForChild("Logic"):WaitForChild("NumberFormat"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local Text = require(Shared:WaitForChild("Util"):WaitForChild("Text"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local DevPanelController = {}

local trove = Trove.new()
local view: DevPanel.View? = nil

local function show(): DevPanel.View
	if view then
		return view
	end
	local gui = trove:Add(Instance.new("ScreenGui"))
	gui.Name = "DevPanel"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local strings = Config.Strings.DevPanel
	local mounted = DevPanel.mount(gui, {
		buttons = {
			{ text = strings.addCounter, command = "AddTestCounter" },
			{
				text = Text.format(strings.giveCash, { amount = NumberFormat.cash(Config.Economy.devCashGift) }),
				command = "GiveCash",
			},
			{ text = strings.resetFactory, command = "ResetFactory" },
		},
		onCommand = function(command: string)
			-- While the Studio abuse suite runs, the server counts every request it gets; a press would spoil the count.
			if Players.LocalPlayer:GetAttribute(AbuseCases.ATTRIBUTE) == true then
				return
			end
			ClientNet.send(Remotes.RequestDevCommand, { command = command })
		end,
	})
	trove:Add(mounted, "destroy")
	view = mounted
	return mounted
end

--[[
	Starts listening for the panel's state.
]]
function DevPanelController.init()
	trove:Add(ClientNet.on(Remotes.DevPanelState, function(payload: { testCounter: number })
		show().setCounter(payload.testCounter)
	end))
end

--[[
	Nothing to start: the panel appears when the server sends its state.
]]
function DevPanelController.start() end

return DevPanelController
