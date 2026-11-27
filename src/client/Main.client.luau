--!strict
-- Client entry point. Stays thin: controllers are initialised, then started (plan section 3.1).
-- Here it also drives the Scheduler: fixed steps from Heartbeat, render callbacks every frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log"))
local Scheduler = require(Shared:WaitForChild("Util"):WaitForChild("Scheduler"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local trove = Trove.new()
trove:Add(RunService.Heartbeat:Connect(Scheduler.update))
trove:Add(RunService.RenderStepped:Connect(Scheduler.render))

Log.info("Client", "started")
