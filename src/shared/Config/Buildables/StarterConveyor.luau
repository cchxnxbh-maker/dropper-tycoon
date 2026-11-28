--!strict
-- StarterConveyor: the first belt. Free, so the first pad teaches how pads work.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Conveyor.luau`.

local Types = require("../../Types/Config")

local StarterConveyor: Types.BuildableDef = {
	id = "StarterConveyor",
	kind = "Conveyor",
	tier = 1,
	price = 0,
	requires = {},
	line = "Main",
	params = { speed = 8 },
	pad = { x = -50, z = -10 },
}

return StarterConveyor
