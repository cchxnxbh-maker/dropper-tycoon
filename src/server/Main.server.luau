--!strict
-- Server entry point. Stays thin: services are initialised, then started, in a fixed order (plan section 3.1).
-- Here it also applies the log settings from config, seeds randomness for the session and drives the Scheduler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Rng = require(ReplicatedStorage.Shared.Logic.Rng)
local Scheduler = require(ReplicatedStorage.Shared.Util.Scheduler)
local Trove = require(ReplicatedStorage.Packages.Trove)

Log.configure(Config.Flags.Log)
Log.setBuild(Config.Build.version)

-- The seed is logged so a repro bundle can replay this session (plan section 8.4).
local seed = DateTime.now().UnixTimestampMillis % 4294967296
Rng.seed(seed)

local trove = Trove.new()
trove:Add(RunService.Heartbeat:Connect(Scheduler.update))

Log.info("Server", "started", { seed = seed })
