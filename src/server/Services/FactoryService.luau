--!strict
-- FactoryService: runs every player's factory simulation and pays what it makes (plan section 3.4, ADR 0021).
--
-- Each player with a plot has one `FactorySim`, built from the machines they own. It steps at
-- `Config.Tuning.Timing.simRate` through the Scheduler; each step's arrivals are added to their cash through
-- EconomyService, and time past the catch-up cap is paid by the income rate. After every rebuild the client is sent
-- the numbers it needs to run the same simulation and draw the items (`FactoryState`); no item is ever sent.
--
-- It does not decide what a player owns. PurchaseService, later in the start order, passes the owned list to
-- `rebuild`.
--
-- State owned: the running simulation of each player.
--
-- Usage, in Main:
--     FactoryService.init()
--     FactoryService.start()
-- From PurchaseService:
--     FactoryService.rebuild(player, ownedIds, levels)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local EconomyService = require(script.Parent.EconomyService)
local FactoryLayout = require(ReplicatedStorage.Shared.Logic.FactoryLayout)
local FactorySim = require(ReplicatedStorage.Shared.Logic.FactorySim)
local Levels = require(ReplicatedStorage.Shared.Logic.Levels)
local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Scheduler = require(ReplicatedStorage.Shared.Util.Scheduler)
local ServerNet = require(script.Parent.Parent.Net.ServerNet)
local Trove = require(ReplicatedStorage.Packages.Trove)

type Running = {
	player: Player,
	sim: FactorySim.Sim,
	owned: { [string]: boolean },
	levels: { [string]: number },
}

local STEP_NAME = "FactorySim"

local FactoryService = {}

local trove = Trove.new()
-- An array, so every step walks the players in the same order without building a table.
local running: { Running } = {}

local function find(player: Player): (number?, Running?)
	for index, entry in running do
		if entry.player == player then
			return index, entry
		end
	end
	return nil, nil
end

local function step()
	for _, entry in running do
		local earned = FactorySim.step(entry.sim)
		if earned > 0 then
			EconomyService.add(entry.player, earned, "factory")
		end
	end
end

local function skipped(seconds: number)
	for _, entry in running do
		local paid = FactorySim.skip(entry.sim, seconds)
		if paid > 0 then
			EconomyService.add(entry.player, paid, "factory")
		end
	end
end

local function sendState(entry: Running)
	ServerNet.send(entry.player, Remotes.FactoryState, {
		owned = entry.owned,
		levels = entry.levels,
		starts = FactorySim.starts(entry.sim),
		tick = entry.sim.tick,
		serverTime = Workspace:GetServerTimeNow(),
		incomeRate = FactorySim.incomeRate(entry.sim),
	})
end

--[[
	Nothing to prepare; here so Main treats every service the same way.
]]
function FactoryService.init() end

--[[
	Starts the simulation step and forgets players who leave.
]]
function FactoryService.start()
	Scheduler.every(STEP_NAME, Config.Tuning.Timing.simRate, step, skipped)
	trove:Add(function()
		Scheduler.remove(STEP_NAME)
	end)
	trove:Connect(Players.PlayerRemoving, function(player: Player)
		FactoryService.remove(player)
	end)
end

--[[
	Builds the player's simulation again from the machines they own and their levels, keeping its step count and the
	start of every dropper already running, so items on the belt still arrive. Then tells their client.
	@param player whose factory
	@param ownedIds the IDs of every machine they own; IDs with no buildable file are skipped
	@param levels saved levels by machine ID; a machine not listed is level 1
]]
function FactoryService.rebuild(player: Player, ownedIds: { string }, levels: { [string]: number })
	local defs: { any } = Levels.defs(Config.Buildables, ownedIds, levels)
	local owned: { [string]: boolean } = {}
	local shownLevels: { [string]: number } = {}
	for _, def in defs do
		owned[def.id] = true
		if def.level > 1 then
			shownLevels[def.id] = def.level
		end
	end
	local _, previous = find(player)
	local options: FactorySim.Options = {
		length = FactoryLayout.length(Config.Factory),
		rate = Config.Tuning.Timing.simRate,
		tick = if previous then previous.sim.tick else 0,
		starts = if previous then FactorySim.starts(previous.sim) else nil,
	}
	local sim = FactorySim.new(defs, options)
	local entry: Running
	if previous then
		previous.sim = sim
		previous.owned = owned
		previous.levels = shownLevels
		entry = previous
	else
		entry = { player = player, sim = sim, owned = owned, levels = shownLevels }
		table.insert(running, entry)
	end
	sendState(entry)
end

--[[
	Stops the player's simulation. Safe to call when none is running.
	@param player whose factory
]]
function FactoryService.remove(player: Player)
	local index = find(player)
	if index then
		table.remove(running, index)
	end
end

--[[
	@param player whose factory
	@return cash per second the factory makes; 0 when it is not running
]]
function FactoryService.getIncomeRate(player: Player): number
	local _, entry = find(player)
	return if entry then FactorySim.incomeRate(entry.sim) else 0
end

return FactoryService
