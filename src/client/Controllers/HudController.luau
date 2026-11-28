--!strict
-- HudController: shows the player's cash and income on the HUD (plan section 4.5), and a short message when a purchase
-- was refused for want of cash. Between server updates the counter is predicted: the last cash the server sent, plus
-- what the client's copy of the factory says has arrived since (`FactorySim.earnedBetween`). `Logic/CashDisplay`
-- eases small gaps and snaps big ones, so a server correction or a purchase shows at once.
--
-- State owned: the HUD's ScreenGui and view.
--
-- Usage, in Main:
--     HudController.init()
--     HudController.start()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CashDisplay = require(Shared:WaitForChild("Logic"):WaitForChild("CashDisplay"))
local ClientNet = require(script.Parent.Parent.Net.ClientNet)
local ClientStore = require(script.Parent.Parent.Net.ClientStore)
local Config = require(Shared:WaitForChild("Config"))
local FactoryMirror = require(script.Parent.Parent.Net.FactoryMirror)
local FactorySim = require(Shared:WaitForChild("Logic"):WaitForChild("FactorySim"))
local Hud = require(script.Parent.Parent.UI.Screens.Hud)
local NumberFormat = require(Shared:WaitForChild("Logic"):WaitForChild("NumberFormat"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local Scheduler = require(Shared:WaitForChild("Util"):WaitForChild("Scheduler"))
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
	local sync = Config.Tuning.Sync
	local counter = CashDisplay.new()
	-- The label changes at most `cashPerSecond` times a second (plan section 4.5).
	Scheduler.every("CashCounter", sync.cashPerSecond, function(dt: number)
		local last: ClientStore.Cash? = ClientStore.get("cash")
		if last == nil then
			return
		end
		local target = last.cash
		local sim = FactoryMirror.sim()
		if sim then
			local from = FactoryMirror.tickAt(last.serverTime)
			local now = FactoryMirror.tickAt(Workspace:GetServerTimeNow())
			target += FactorySim.earnedBetween(sim, from, now)
		end
		local shown = CashDisplay.update(counter, target, dt, sync.cashEaseShare, sync.cashEaseSeconds)
		view.setCash(Text.format(strings.cash, { cash = NumberFormat.cash(shown) }))
	end)
	trove:Add(function()
		Scheduler.remove("CashCounter")
	end)
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
