--!strict
-- Dev command GiveCash: adds `Config.Economy.devCashGift` cash, to test purchases without waiting (task 12). Works
-- only in Studio and on the Dev place, never on Live.
--
-- State owned: none. Changes cash, which belongs to EconomyService.
--
-- Usage: run by `DevService.run(player, "GiveCash")`; never called directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local EconomyService = require(script.Parent.Parent.Services.EconomyService)

return {
	run = function(player: Player): boolean
		-- The experience owner sees the panel on Live too; free cash must never exist there.
		if not RunService:IsStudio() and game.PlaceId ~= Config.Build.devPlaceId then
			return false
		end
		return EconomyService.add(player, Config.Economy.devCashGift, "dev")
	end,
}
