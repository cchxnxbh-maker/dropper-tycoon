--!strict
-- Tuning: simulation timing now; sync rates, distances and rate limits join as their systems arrive (plan section 5.1).
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
}

return Tuning
