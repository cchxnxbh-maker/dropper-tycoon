--!strict
-- Handler for `RequestDevCommand`: passes the command to DevService, which checks the player may use the dev panel.
-- ServerNet has already checked the payload, the rate limit and the session before this runs.
--
-- State owned: none.
--
-- Usage: registered by `ServerNet.init` from the Handlers index; never called directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevService = require(script.Parent.Parent.Parent.Services.DevService)
local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)

return {
	remote = Remotes.RequestDevCommand,
	handle = function(player: Player, payload: { command: string })
		DevService.run(player, payload.command)
	end,
}
