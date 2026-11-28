--!strict
-- Client entry point. Stays thin: controllers are initialised, then started (plan section 3.1).
-- Here it also applies the log settings from config and drives the Scheduler: fixed steps from Heartbeat, render
-- callbacks every frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientNet = require(script.Parent.Net.ClientNet)
local Config = require(Shared:WaitForChild("Config"))
local DevPanelController = require(script.Parent.Controllers.DevPanelController)
local FactoryMirror = require(script.Parent.Net.FactoryMirror)
local FactoryViewController = require(script.Parent.Controllers.FactoryViewController)
local HudController = require(script.Parent.Controllers.HudController)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log"))
local PadController = require(script.Parent.Controllers.PadController)
local PingController = require(script.Parent.Controllers.PingController)
local PlotSignController = require(script.Parent.Controllers.PlotSignController)
local Scheduler = require(Shared:WaitForChild("Util"):WaitForChild("Scheduler"))
local StateSync = require(script.Parent.Net.StateSync)
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

Log.configure(Config.Flags.Log)
Log.setBuild(Config.Build.version)

-- Init everything, then start everything. ClientNet comes first: controllers talk to the server through it, and
-- StateSync fills ClientStore from what the server sends.
ClientNet.init()
StateSync.init()
FactoryMirror.init()
PingController.init()
PlotSignController.init()
HudController.init()
PadController.init()
FactoryViewController.init()
DevPanelController.init()

PingController.start()
PlotSignController.start()
HudController.start()
PadController.start()
FactoryViewController.start()
DevPanelController.start()

local trove = Trove.new()
trove:Add(RunService.Heartbeat:Connect(Scheduler.update))
trove:Add(RunService.RenderStepped:Connect(Scheduler.render))

Log.info("Client", "started")
