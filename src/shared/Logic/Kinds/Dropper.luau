--!strict
-- Dropper: makes one item every `interval` seconds, worth `itemValue`, dropped `at` studs along the conveyor. Each
-- level above 1 adds `perLevel` times the base value to every item.
--
-- Pure Luau. State owned: none.
--
-- Usage: `params = { itemValue = 1, interval = 2, at = 10, perLevel = 0.5 }` in a buildable file of kind "Dropper".

local KindTypes = require("../KindTypes")
local Validate = require("../Validate")

local Dropper: KindTypes.Kind = {
	kind = "Dropper",
	params = Validate.record({
		itemValue = Validate.number({ min = 0.01, max = 1e12 }), -- const: sanity limit for config checks, not a tuning value
		-- Rounded to whole simulation steps; faster than 10 a second would only draw a blur.
		interval = Validate.number({ min = 0.1, max = 600 }), -- const: sanity limit for config checks, not a tuning value
		at = Validate.number({ min = 0, max = 1000 }), -- const: sanity limit for config checks, not a tuning value
		perLevel = Validate.number({ min = 0, max = 100 }), -- const: sanity limit for config checks, not a tuning value
	}),
	levels = true,
	apply = function(build, def)
		table.insert(build.droppers, {
			id = def.id,
			at = def.params.at,
			itemValue = def.params.itemValue * (1 + (def.params.perLevel or 0) * ((def.level or 1) - 1)),
			interval = def.params.interval,
		})
	end,
}

return Dropper
