--!strict
-- AbuseSuite (server half): runs the generated abuse suite through the real remotes in a Studio playtest (plan
-- section 8.2, task 8).
--
-- When the first player joins a Studio playtest, the server puts them in audit mode and sets an attribute on them.
-- Their client (`client/Dev/AbuseClient.luau`) then fires every case from `AbuseCases` through the real RemoteEvents.
-- The server records each outcome in arrival order, compares them with the expected ones and prints one summary
-- line. Audit mode means no handler runs and nobody is kicked, so the suite changes no game state.
--
-- Runs only in Studio and only while `Flags.Features.studioAbuseSuite` is on. Never on a real server.
--
-- State owned: whether the suite has run in this server.
--
-- Usage, in Main:
--     AbuseSuite.start()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbuseCases = require(ReplicatedStorage.Shared.Network.AbuseCases)
local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local ServerNet = require(script.Parent.Parent.Net.ServerNet)
local Trove = require(ReplicatedStorage.Packages.Trove)

local TAG = "AbuseSuite"
-- How long the server waits for every case to arrive before it reports what is missing.
local TIMEOUT_SECONDS = 30
-- How often the server looks at the outcomes while it waits.
local POLL_SECONDS = 0.25

local AbuseSuite = {}

local trove = Trove.new()
local ran = false

local function run(player: Player)
	local cases = AbuseCases.all(Remotes)
	ServerNet.audit(player, true)
	local started = os.clock()
	player:SetAttribute(AbuseCases.ATTRIBUTE, true)
	Log.info(TAG, "started", { userId = player.UserId, cases = #cases })

	while #ServerNet.auditLog(player) < #cases and os.clock() - started < TIMEOUT_SECONDS do
		if player.Parent == nil then
			return
		end
		task.wait(POLL_SECONDS)
	end

	local outcomes = ServerNet.auditLog(player)
	local failures = AbuseCases.evaluate(cases, outcomes, Remotes, os.clock() - started)
	ServerNet.audit(player, false)
	player:SetAttribute(AbuseCases.ATTRIBUTE, nil)

	if #failures == 0 then
		Log.info(TAG, "PASSED: every hostile request was rejected and state is unchanged", { cases = #cases })
	else
		for _, failure in failures do
			Log.error(TAG, failure)
		end
		Log.error(TAG, "FAILED", { failures = #failures, cases = #cases })
	end
end

local function tryRun(player: Player)
	if ran then
		return
	end
	ran = true
	task.spawn(run, player)
end

--[[
	Runs the suite for the first player to join, in Studio only and only when the flag is on. Does nothing otherwise.
]]
function AbuseSuite.start()
	if not RunService:IsStudio() or not Config.Flags.Features.studioAbuseSuite then
		return
	end
	trove:Connect(Players.PlayerAdded, tryRun)
	local present = Players:GetPlayers()
	if #present > 0 then
		tryRun(present[1])
	end
end

return AbuseSuite
