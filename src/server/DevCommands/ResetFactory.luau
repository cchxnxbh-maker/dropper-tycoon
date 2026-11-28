--!strict
-- Dev command ResetFactory: takes every machine away and sets cash to 0, so the start of the game can be played again
-- (task 12). The save keeps everything else. Works only in Studio and on the Dev place, never on Live.
--
-- State owned: none. Asks PurchaseService and EconomyService, which own the machines and the cash.
--
-- Usage: run by `DevService.run(player, "ResetFactory")`; never called directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local EconomyService = require(script.Parent.Parent.Services.EconomyService)
local PurchaseService = require(script.Parent.Parent.Services.PurchaseService)

return {
	run = function(player: Player): boolean
		-- The experience owner sees the panel on Live too; a real player's progress must never be wiped there.
		if not RunService:IsStudio() and game.PlaceId ~= Config.Build.devPlaceId then
			return false
		end
		local machines = PurchaseService.reset(player)
		local cash = EconomyService.reset(player)
		return machines and cash
	end,
}
