--!strict
-- Tuning: timing numbers (plan section 5.1). Task 7 adds the rest of this file's sections and the config loader that
-- validates and freezes it; until then it is a plain frozen table.
--
-- State owned: none. Read-only data.
--
-- Usage:
--     local Tuning = require("../Config/Tuning")
--     Scheduler.every("FactorySim", Tuning.Timing.simRate, step)

local Tuning = {
	Timing = table.freeze({
		-- Factory simulation steps per second. Results do not depend on frame rate.
		simRate = 10,
		-- Most fixed steps one frame may run. Time beyond this is paid by formula, so stalls never spiral.
		maxCatchUpSteps = 5,
	}),
}

return table.freeze(Tuning)
