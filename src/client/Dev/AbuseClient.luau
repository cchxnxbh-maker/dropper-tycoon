--!strict
-- AbuseClient (client half): fires the generated abuse suite through the real remotes in a Studio playtest (plan
-- section 8.2, task 8). The server half, `server/Dev/AbuseSuite.luau`, says when to start and judges the results.
--
-- It fires straight through the RemoteEvents, skipping ClientNet's own checks, because the point is to send exactly
-- what an exploiter could send. Only in Studio, only when `Flags.Features.studioAbuseSuite` is on.
--
-- State owned: none.
--
-- Usage:
--     AbuseClient.run()   -- returns once the server has judged the suite, or at once when it is not running

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbuseCases = require(Shared:WaitForChild("Network"):WaitForChild("AbuseCases"))
local Config = require(Shared:WaitForChild("Config"))
local RemoteFolder = require(Shared:WaitForChild("Network"):WaitForChild("RemoteFolder"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))

-- How long the client waits for the server to start the suite. The server starts it once this player's save has
-- loaded, which can take a few seconds when Studio saves to the real Dev data store.
local START_TIMEOUT_SECONDS = 30
-- How often the client looks at the attribute while it waits. Polling, so a timeout works even if it never changes.
local POLL_SECONDS = 0.1

local AbuseClient = {}

-- Waits until the attribute equals `wanted` or the timeout passes. Returns whether it got there.
local function waitFor(player: Player, wanted: boolean, timeout: number?): boolean
	local started = os.clock()
	while (player:GetAttribute(AbuseCases.ATTRIBUTE) == true) ~= wanted do
		if timeout and os.clock() - started > timeout then
			return false
		end
		task.wait(POLL_SECONDS)
	end
	return true
end

--[[
	Fires every abuse case when the server asks for it, then waits until the server has judged them.
	Returns at once outside Studio or when the flag is off.
]]
function AbuseClient.run()
	if not RunService:IsStudio() or not Config.Flags.Features.studioAbuseSuite then
		return
	end
	local player = Players.LocalPlayer
	if not waitFor(player, true, START_TIMEOUT_SECONDS) then
		return
	end
	local events = RemoteFolder.find(ReplicatedStorage, Remotes)
	for _, case in AbuseCases.all(Remotes) do
		events[case.remote]:FireServer(case.payload)
	end
	waitFor(player, false, nil)
end

return AbuseClient
