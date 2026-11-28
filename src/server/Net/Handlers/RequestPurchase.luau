--!strict
-- Handler for `RequestPurchase`: passes the machine ID to PurchaseService, which checks ownership, requirements,
-- distance to the pad and price. ServerNet has already checked the payload, the rate limit and the session.
--
-- State owned: none.
--
-- Usage: registered by `ServerNet.init` from the Handlers index; never called directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PurchaseService = require(script.Parent.Parent.Parent.Services.PurchaseService)
local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)

return {
	remote = Remotes.RequestPurchase,
	handle = function(player: Player, payload: { buildableId: string })
		PurchaseService.tryPurchase(player, payload.buildableId)
	end,
}
