--!strict
-- Collector: the bin at the end of the line that turns items into cash, times `multiplier`. Without one the line does
-- not run. With several, the best one counts.
--
-- Pure Luau. State owned: none.
--
-- Usage: `params = { multiplier = 1 }` in a buildable file of kind "Collector".

local KindTypes = require("../KindTypes")
local Validate = require("../Validate")

local Collector: KindTypes.Kind = {
	kind = "Collector",
	params = Validate.record({
		multiplier = Validate.number({ min = 1, max = 1000 }), -- const: sanity limit for config checks, not a tuning value
	}),
	apply = function(build, def)
		build.collectorMultiplier = if build.hasCollector
			then math.max(build.collectorMultiplier, def.params.multiplier)
			else def.params.multiplier
		build.hasCollector = true
	end,
}

return Collector
