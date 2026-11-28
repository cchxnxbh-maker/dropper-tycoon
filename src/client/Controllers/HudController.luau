--!strict
-- HudController: shows the player's cash and income on the HUD (plan section 4.5), and a short message when a purchase
-- was refused for want of cash. Values come from ClientStore, which the server keeps current; the prediction between
-- server updates arrives in task 13.
--
-- State owned: the HUD's ScreenGui and view.
--
-- Usage, in Main:
--     HudController.init()
--     HudController.start()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientNet = require(script.Parent.Parent.Net.ClientNet)
local ClientStore = require(script.Parent.Parent.Net.ClientStore)
local Config = require(Shared:WaitForChild("Config"))
local Hud = require(script.Parent.Parent.UI.Screens.Hud)
local NumberFormat = require(Shared:WaitForChild("Logic"):WaitForChild("NumberFormat"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local Text = require(Shared:WaitForChild("Util"):WaitForChild("Text"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local HudController = {}

local trove = Trove.new()

--[[
	Nothing to prepare; here so Main treats every controller the same way.
]]
function HudController.init() end

--[[
	Builds the HUD and keeps it current.
]]
function HudController.start()
	local strings = Config.Strings.Hud
	local gui = trove:Add(Instance.new("ScreenGui"))
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local view = trove:Add(Hud.mount(gui), "destroy")
	view.setCash(Text.format(strings.cash, { cash = NumberFormat.cash(0) }))
	view.setRate(Text.format(strings.rate, { rate = NumberFormat.rate(0) }))
	trove:Add(ClientStore.changed("cash", function(cash: number)
		view.setCash(Text.format(strings.cash, { cash = NumberFormat.cash(cash) }))
	end))
	trove:Add(ClientStore.changed("factory", function(factory: ClientStore.Factory)
		view.setRate(Text.format(strings.rate, { rate = NumberFormat.rate(factory.incomeRate) }))
	end))
	trove:Add(ClientNet.on(Remotes.PurchaseRefused, function(payload: { buildableId: string, reason: string })
		if payload.reason == "notEnoughCash" then
			view.toast(Config.Strings.Purchase.notEnoughCash)
		end
	end))
end

return HudController
