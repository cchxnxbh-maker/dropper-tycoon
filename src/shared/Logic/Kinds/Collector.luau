--!strict
-- Collector: the bin at the end of the line that turns items into cash, times `multiplier`. Without one the line does
-- not run. With several, the best one counts. Each level above 1 adds `perLevel` to the multiplier.
--
-- Pure Luau. State owned: none.
--
-- Usage: `params = { multiplier = 1, perLevel = 0.1 }` in a buildable file of kind "Collector".

local KindTypes = require("../KindTypes")
local Validate = require("../Validate")

local Collector: KindTypes.Kind = {
	kind = "Collector",
	params = Validate.record({
		multiplier = Validate.number({ min = 1, max = 1000 }), -- const: sanity limit for config checks, not a tuning value
		perLevel = Validate.number({ min = 0, max = 100 }), -- const: sanity limit for config checks, not a tuning value
	}),
	levels = true,
	apply = function(build, def)
		local multiplier = def.params.multiplier + (def.params.perLevel or 0) * ((def.level or 1) - 1)
		build.collectorMultiplier = if build.hasCollector
			then math.max(build.collectorMultiplier, multiplier)
			else multiplier
		build.hasCollector = true
	end,
}

return Collector
