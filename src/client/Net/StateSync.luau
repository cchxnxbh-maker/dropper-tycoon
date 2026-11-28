--!strict
-- StateSync: writes what the server sends about the player's state into ClientStore (plan section 4.8). The only
-- writer of ClientStore.
--
-- State owned: none.
--
-- Usage, in Main after ClientNet.init:
--     StateSync.init()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientNet = require(script.Parent.ClientNet)
local ClientStore = require(script.Parent.ClientStore)
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))

local StateSync = {}

--[[
	Starts listening. Call once, after `ClientNet.init`.
]]
function StateSync.init()
	ClientNet.on(Remotes.CashSync, function(payload: { cash: number })
		ClientStore.write("cash", payload.cash)
	end)
	ClientNet.on(Remotes.FactoryState, function(payload: ClientStore.Factory)
		ClientStore.write("factory", payload)
	end)
end

return StateSync
