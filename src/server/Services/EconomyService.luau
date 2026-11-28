--!strict
-- EconomyService: every player's cash (plan section 3.4, ADR 0002, ADR 0021).
--
-- Cash is held here while the player plays, so the factory can add to it every step without copying the whole save
-- each time. It is written to the save through `DataService.mutate` every `Tuning.Sync.cashSaveSeconds`, at once on
-- every spend, and when the session is about to stop. ProfileStore then saves it on its own schedule. The client gets
-- the number at most `Tuning.Sync.cashPerSecond` times a second, only when it changed.
--
-- Cash never goes above `Config.Economy.maxCash` (ADR 0009). Amounts are never negative.
--
-- State owned: cash per player.
--
-- Usage, in Main:
--     EconomyService.init()
--     EconomyService.start()
-- From a later service:
--     if EconomyService.trySpend(player, def.price, "purchase") then ... end
--     EconomyService.add(player, earned, "factory")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Scheduler = require(ReplicatedStorage.Shared.Util.Scheduler)
local ServerNet = require(script.Parent.Parent.Net.ServerNet)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

-- Spelled out here because Wally's package link files do not re-export the Signal package's types.
export type CashSignal = {
	Connect: (self: any, listener: (player: Player, cash: number) -> ()) -> { Disconnect: (self: any) -> () },
	Fire: (self: any, player: Player, cash: number) -> (),
}

type Wallet = { cash: number, unsent: boolean, unsaved: boolean }

local TAG = "Economy"

local EconomyService = {}

--[[
	Fires whenever a player's cash changes. Carries the player and the new amount.
]]
EconomyService.cashChanged = (Signal.new() :: any) :: CashSignal

local trove = Trove.new()
local wallets: { [Player]: Wallet } = {}
local stepsSinceSave = 0

-- The player's wallet, read from their save the first time it is needed. Nil until their save has loaded.
local function walletOf(player: Player): Wallet?
	local wallet = wallets[player]
	if wallet == nil and DataService.isPlaying(player) then
		local data = DataService.get(player)
		if data then
			wallet = { cash = data.economy.cash, unsent = true, unsaved = false }
			wallets[player] = wallet
		end
	end
	return wallet
end

local function save(player: Player, wallet: Wallet)
	if not wallet.unsaved then
		return
	end
	local cash = wallet.cash
	if DataService.mutate(player, "cash", function(data)
		data.economy.cash = cash
	end) then
		wallet.unsaved = false
	end
end

local function changed(player: Player, wallet: Wallet)
	wallet.unsent = true
	wallet.unsaved = true
	EconomyService.cashChanged:Fire(player, wallet.cash)
end

-- One sync step: sends changed cash to each client, and every few seconds writes changed cash to the save.
local function sync()
	local saveNow = false
	stepsSinceSave += 1
	if stepsSinceSave >= Config.Tuning.Sync.cashSaveSeconds * Config.Tuning.Sync.cashPerSecond then
		stepsSinceSave = 0
		saveNow = true
	end
	for player, wallet in wallets do
		if wallet.unsent then
			wallet.unsent = false
			ServerNet.send(player, Remotes.CashSync, { cash = wallet.cash, serverTime = Workspace:GetServerTimeNow() })
		end
		if saveNow then
			save(player, wallet)
		end
	end
end

--[[
	Nothing to prepare; here so Main treats every service the same way.
]]
function EconomyService.init() end

--[[
	Starts the sync step and keeps the save current when a session stops.
]]
function EconomyService.start()
	Scheduler.every("CashSync", Config.Tuning.Sync.cashPerSecond, sync)
	trove:Add(function()
		Scheduler.remove("CashSync")
	end)
	trove:Add(DataService.profileLoaded:Connect(function(player: Player)
		walletOf(player)
	end))
	trove:Add(DataService.profileReleasing:Connect(function(player: Player)
		local wallet = wallets[player]
		if wallet then
			save(player, wallet)
		end
	end))
	trove:Connect(Players.PlayerRemoving, function(player: Player)
		wallets[player] = nil
	end)
end

--[[
	The player's cash.
	@return the amount; 0 while their save is not loaded
]]
function EconomyService.getCash(player: Player): number
	local wallet = walletOf(player)
	return if wallet then wallet.cash else 0
end

--[[
	Adds cash, up to the cap.
	@param player who gets it
	@param amount how much, more than 0
	@param reason a short word for the log, such as "factory"
	@return true when added; false when the amount is not a positive number or the save is not loaded
]]
function EconomyService.add(player: Player, amount: number, reason: string): boolean
	local wallet = walletOf(player)
	if wallet == nil or not (amount > 0) or amount == math.huge then
		return false
	end
	local before = wallet.cash
	wallet.cash = math.min(Config.Economy.maxCash, before + amount)
	if wallet.cash ~= before then
		changed(player, wallet)
	elseif reason ~= "factory" then
		Log.info(TAG, "cash is at the cap", { userId = player.UserId, reason = reason })
	end
	return true
end

--[[
	Spends cash if the player has enough, and saves at once so a purchase and its cost are never split by a crash.
	@param player who pays
	@param cost how much, 0 or more
	@param reason a short word for the log, such as "purchase"
	@return true when paid; false when the player has too little, the cost is not a number of 0 or more, or the save
	is not loaded or could not take the change
]]
function EconomyService.trySpend(player: Player, cost: number, reason: string): boolean
	local wallet = walletOf(player)
	if wallet == nil or not (cost >= 0) or cost == math.huge or wallet.cash < cost then
		return false
	end
	local cash = wallet.cash - cost
	local ok = DataService.mutate(player, reason, function(data)
		data.economy.cash = cash
	end)
	if not ok then
		return false
	end
	wallet.cash = cash
	changed(player, wallet)
	wallet.unsaved = false
	return true
end

--[[
	Sets the player's cash to 0. For the dev panel's reset only.
	@param player whose cash
	@return true when done; false when the save is not loaded
]]
function EconomyService.reset(player: Player): boolean
	local wallet = walletOf(player)
	if wallet == nil then
		return false
	end
	wallet.cash = 0
	changed(player, wallet)
	save(player, wallet)
	return true
end

return EconomyService
