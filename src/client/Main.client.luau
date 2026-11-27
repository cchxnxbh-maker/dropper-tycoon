--!strict
-- Client entry point. Stays thin: controllers are initialised, then started (plan section 3.1).
-- Here it also applies the log settings from config and drives the Scheduler: fixed steps from Heartbeat, render
-- callbacks every frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientNet = require(script.Parent.Net.ClientNet)
local Config = require(Shared:WaitForChild("Config"))
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log"))
local PingController = require(script.Parent.Controllers.PingController)
local Scheduler = require(Shared:WaitForChild("Util"):WaitForChild("Scheduler"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

Log.configure(Config.Flags.Log)
Log.setBuild(Config.Build.version)

-- Init everything, then start everything. ClientNet comes first: controllers talk to the server through it.
ClientNet.init()
PingController.init()

PingController.start()

local trove = Trove.new()
trove:Add(RunService.Heartbeat:Connect(Scheduler.update))
trove:Add(RunService.RenderStepped:Connect(Scheduler.render))

Log.info("Client", "started")
