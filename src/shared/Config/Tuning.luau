--!strict
-- Tuning: simulation timing and network limits; sync rates and distances join as their systems arrive (plan section 5.1).
-- Each remote's own rate limit sits beside it in `Network/Remotes.luau`.
-- Ranges are checked by `Config/Schema.luau`. Read it through `Config`, which validates and freezes it.
--
-- State owned: none. Read-only data.
--
-- Usage:
--     local Config = require("../Config")
--     Scheduler.every("FactorySim", Config.Tuning.Timing.simRate, step)

local Types = require("../Types/Config")

local Tuning: Types.Tuning = {
	Timing = {
		-- Factory simulation steps per second. Results do not depend on frame rate.
		simRate = 10,
		-- Most fixed steps one frame may run. Time beyond this is paid by formula, so stalls never spiral.
		maxCatchUpSteps = 5,
	},
	Network = {
		-- Longest text, in characters, any client request may carry anywhere. Requests carry IDs, so this is generous.
		maxStringLength = 200,
		-- Deepest nesting of tables in a client request. The request itself is level 1.
		maxTableDepth = 3,
		-- Most keys in any one table of a client request.
		maxTableEntries = 32,
		-- Strikes are counted over this many seconds, then the count starts again.
		strikeWindowSeconds = 60,
		-- Strikes inside one window that get a player kicked. One honest lag spike stays far below this.
		kickAfterStrikes = 30,
		-- Share of each remote's limit the client allows itself, so network jitter never makes an honest client
		-- look like it is over the server's limit.
		clientRateShare = 0.8,
	},
}

return Tuning
