--!strict
-- Upgrader: multiplies the value of every item that passes under it, `at` studs along the conveyor. Only items dropped
-- before that point pass it.
--
-- Pure Luau. State owned: none.
--
-- Usage: `params = { multiplier = 1.5, at = 60 }` in a buildable file of kind "Upgrader".

local KindTypes = require("../KindTypes")
local Validate = require("../Validate")

local Upgrader: KindTypes.Kind = {
	kind = "Upgrader",
	params = Validate.record({
		multiplier = Validate.number({ min = 1, max = 1000 }), -- const: sanity limit for config checks, not a tuning value
		at = Validate.number({ min = 0, max = 1000 }), -- const: sanity limit for config checks, not a tuning value
	}),
	apply = function(build, def)
		table.insert(build.upgraders, { id = def.id, at = def.params.at, multiplier = def.params.multiplier })
	end,
}

return Upgrader
