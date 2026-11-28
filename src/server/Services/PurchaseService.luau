--!strict
-- PurchaseService: which machines each player owns, and buying new ones (plan sections 3.4 and 3.6, ADR 0021).
--
-- When a player gets a plot, their owned machines are placed on it, the pads they can buy next appear, and their
-- factory starts. A purchase request carries only a machine ID. It goes ahead only when `Logic/Purchase` agrees: the
-- machine exists, is not owned, its requirements are owned, the character stands at its pad and the cash is there.
-- Then the cash is spent, the machine is saved as owned, placed, the pads change and the factory is rebuilt. If
-- saving the machine fails after the cash was spent, the cash is given back.
--
-- State owned: the `factory.owned` section of every save (through DataService.mutate).
--
-- Usage, in Main:
--     PurchaseService.init()
--     PurchaseService.start()
-- From the RequestPurchase handler:
--     PurchaseService.tryPurchase(player, payload.buildableId)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local FactoryLayout = require(ReplicatedStorage.Shared.Logic.FactoryLayout)
local FactoryService = require(script.Parent.FactoryService)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local PlotService = require(script.Parent.PlotService)
local Purchase = require(ReplicatedStorage.Shared.Logic.Purchase)
local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local ServerNet = require(script.Parent.Parent.Net.ServerNet)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(ReplicatedStorage.Shared.Types.Config)

local TAG = "Purchase"

local PurchaseService = {}

local trove = Trove.new()
local ids = Purchase.sortedIds(Config.Buildables)

-- What the save says the player owns, without IDs this build does not know (a machine removed from config).
local function ownedOf(player: Player): { [string]: boolean }?
	local data = DataService.get(player)
	if data == nil then
		return nil
	end
	local owned: { [string]: boolean } = {}
	for id, isOwned in data.factory.owned do
		if isOwned and Config.Buildables[id] then
			owned[id] = true
		elseif isOwned then
			Log.warn(TAG, "save owns a machine this build does not know; ignored", { userId = player.UserId, id = id })
		end
	end
	return owned
end

local function ownedList(owned: { [string]: boolean }): { string }
	local list: { string } = {}
	for _, id in ids do
		if owned[id] then
			table.insert(list, id)
		end
	end
	return list
end

local function refreshPads(player: Player, owned: { [string]: boolean })
	local defs: { Types.BuildableDef } = {}
	for _, id in Purchase.available(owned, Config.Buildables, ids) do
		table.insert(defs, Config.Buildables[id])
	end
	PlotService.showPads(player, defs)
end

-- Builds the player's whole factory from their save: machines, pads and the simulation.
local function setUp(player: Player)
	local owned = ownedOf(player)
	if owned == nil then
		return
	end
	local list = ownedList(owned)
	for _, id in list do
		PlotService.placeMachine(player, Config.Buildables[id])
	end
	refreshPads(player, owned)
	FactoryService.rebuild(player, list)
end

-- Ground distance from the player's character to a pad's centre; infinite without a character.
local function distanceToPad(player: Player, def: Types.BuildableDef): number
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local pad = PlotService.toWorld(player, def.pad)
	if root == nil or not root:IsA("BasePart") or pad == nil then
		return math.huge
	end
	local offset = root.Position - pad
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

--[[
	Nothing to prepare; here so Main treats every service the same way.
]]
function PurchaseService.init() end

--[[
	Sets up each player's factory once they have a plot.
]]
function PurchaseService.start()
	trove:Add(PlotService.plotAssigned:Connect(setUp))
	for _, player in Players:GetPlayers() do
		if PlotService.getPlot(player) then
			setUp(player)
		end
	end
end

--[[
	Whether the player owns a machine.
	@param player who
	@param id the machine's ID
	@return true when owned; false when not, or when their save is not loaded
]]
function PurchaseService.owns(player: Player, id: string): boolean
	local owned = ownedOf(player)
	return owned ~= nil and owned[id] == true
end

--[[
	Buys a machine for the player, if every rule allows it. A refusal is sent to the client.
	@param player who asked
	@param id the machine's ID, from the request
	@return nil when bought; otherwise the reason it was not (`Purchase.Reason`, or "failed" when the save could not
	take the change)
]]
function PurchaseService.tryPurchase(player: Player, id: string): string?
	local owned = ownedOf(player)
	local def = Config.Buildables[id]
	if owned == nil or PlotService.getPlot(player) == nil then
		return "failed"
	end
	local reason = Purchase.check({
		id = id,
		owned = owned,
		cash = EconomyService.getCash(player),
		buildables = Config.Buildables,
		distance = if def then distanceToPad(player, def) else 0,
		radius = FactoryLayout.padRadius(Config.Factory),
	})
	if reason then
		if reason ~= "notEnoughCash" then
			-- Only a client asking for something it was never shown gets here.
			Log.warn(TAG, "purchase refused", { userId = player.UserId, id = id, reason = reason })
		end
		ServerNet.send(player, Remotes.PurchaseRefused, { buildableId = id, reason = reason })
		return reason
	end
	if not EconomyService.trySpend(player, def.price, "purchase") then
		return "failed"
	end
	local saved = DataService.mutate(player, "purchase", function(data)
		data.factory.owned[id] = true
	end)
	if not saved then
		EconomyService.add(player, def.price, "refund")
		Log.error(TAG, "purchase could not be saved; cash refunded", { userId = player.UserId, id = id })
		return "failed"
	end
	owned[id] = true
	PlotService.placeMachine(player, def)
	refreshPads(player, owned)
	FactoryService.rebuild(player, ownedList(owned))
	Log.info(TAG, "bought", { userId = player.UserId, id = id, price = def.price })
	return nil
end

--[[
	Takes every machine away and starts the factory from nothing. For the dev panel's reset only; cash is reset by
	EconomyService.
	@param player whose factory
	@return true when done; false when the save could not take the change
]]
function PurchaseService.reset(player: Player): boolean
	local ok = DataService.mutate(player, "devReset", function(data)
		data.factory.owned = {}
	end)
	if ok then
		PlotService.clearFactory(player)
		setUp(player)
	end
	return ok
end

return PurchaseService
