--!strict
-- PingController: says hello to the server once at startup and logs the answer, proving the network layer end to
-- end (task 8). In a Studio playtest it first lets the abuse suite run, so the two never mix.
--
-- State owned: the TestPong listener.
--
-- Usage, in Main:
--     PingController.init()
--     PingController.start()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbuseClient = require(script.Parent.Parent.Dev.AbuseClient)
local ClientNet = require(script.Parent.Parent.Net.ClientNet)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))

local TAG = "Ping"

local PingController = {}

--[[
	Starts listening for the server's answer.
]]
function PingController.init()
	ClientNet.on(Remotes.TestPong, function(payload: { label: string, serverTime: number })
		Log.info(TAG, "pong", { label = payload.label, serverTime = payload.serverTime })
	end)
end

--[[
	Sends the hello, after the Studio abuse suite when one runs.
]]
function PingController.start()
	task.spawn(function()
		AbuseClient.run()
		ClientNet.send(Remotes.RequestTestPing, { label = "hello" })
	end)
end

return PingController
