--!strict
-- FactoryMirror: the client's copy of its own factory simulation, built from the last `FactoryState` (ADR 0021).
-- FactoryViewController draws items from it and HudController predicts cash with it, so both use the same numbers
-- the server pays by. It is a picture of the server's sim, never trusted by the server.
--
-- State owned: the client sim and the server time its step count is anchored to.
--
-- Usage, in Main after StateSync.init:
--     FactoryMirror.init()
-- From a controller:
--     local sim = FactoryMirror.sim()
--     local tick = FactoryMirror.tickAt(Workspace:GetServerTimeNow())

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientStore = require(script.Parent.ClientStore)
local Config = require(Shared:WaitForChild("Config"))
local FactoryLayout = require(Shared:WaitForChild("Logic"):WaitForChild("FactoryLayout"))
local FactorySim = require(Shared:WaitForChild("Logic"):WaitForChild("FactorySim"))
local Levels = require(Shared:WaitForChild("Logic"):WaitForChild("Levels"))
local Purchase = require(Shared:WaitForChild("Logic"):WaitForChild("Purchase"))

local FactoryMirror = {}

local current: FactorySim.Sim? = nil
local syncTick = 0
local syncTime = 0

local function onFactory(state: ClientStore.Factory)
	local ids: { string } = {}
	for _, id in Purchase.sortedIds(Config.Buildables) do
		if state.owned[id] then
			table.insert(ids, id)
		end
	end
	local defs: { any } = Levels.defs(Config.Buildables, ids, state.levels)
	current = FactorySim.new(defs, {
		length = FactoryLayout.length(Config.Factory),
		rate = Config.Tuning.Timing.simRate,
		tick = state.tick,
		starts = state.starts,
	})
	syncTick = state.tick
	syncTime = state.serverTime
end

--[[
	Starts following the factory state. Call once, after `StateSync.init`.
]]
function FactoryMirror.init()
	ClientStore.changed("factory", onFactory)
end

--[[
	@return the client sim; nil until the first `FactoryState` arrives. It is replaced on every new state, so read it
	again each time instead of keeping it.
]]
function FactoryMirror.sim(): FactorySim.Sim?
	return current
end

--[[
	The server sim's step at a moment of server time, worked out from the last state.
	@param serverTime seconds on `workspace:GetServerTimeNow()`
	@return the step, with a fraction; 0 before the first state
]]
function FactoryMirror.tickAt(serverTime: number): number
	if current == nil then
		return 0
	end
	return syncTick + (serverTime - syncTime) * current.rate
end

return FactoryMirror
