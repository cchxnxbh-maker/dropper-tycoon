--!strict
-- Conveyor: carries items along the line at `speed` studs a second. The line runs at the speed of its fastest owned
-- conveyor, so a better conveyor is an upgrade, not a second belt.
--
-- Pure Luau. State owned: none.
--
-- Usage: `params = { speed = 8 }` in a buildable file of kind "Conveyor".

local KindTypes = require("../KindTypes")
local Validate = require("../Validate")

local Conveyor: KindTypes.Kind = {
	kind = "Conveyor",
	params = Validate.record({
		speed = Validate.number({ min = 0.5, max = 200 }), -- const: sanity limit for config checks, not a tuning value
	}),
	apply = function(build, def)
		build.speed = math.max(build.speed, def.params.speed)
	end,
}

return Conveyor
