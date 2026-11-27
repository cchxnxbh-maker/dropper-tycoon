--!strict
-- Handler for `RequestTestPing`, the test remote from task 8. Answers with `TestPong` and changes no state.
-- ServerNet has already checked the payload, the rate limit and the session before this runs.
--
-- State owned: none.
--
-- Usage: registered by `ServerNet.init` from the Handlers index; never called directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local ServerNet = require(script.Parent.Parent.ServerNet)

return {
	remote = Remotes.RequestTestPing,
	handle = function(player: Player, payload: { label: string })
		ServerNet.send(player, Remotes.TestPong, { label = payload.label, serverTime = os.time() })
	end,
}
