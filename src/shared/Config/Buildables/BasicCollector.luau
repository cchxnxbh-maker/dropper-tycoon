--!strict
-- BasicCollector: the bin at the end of the belt that turns items into cash. Free.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Collector.luau`.

local Types = require("../../Types/Config")

local BasicCollector: Types.BuildableDef = {
	id = "BasicCollector",
	kind = "Collector",
	tier = 1,
	price = 0,
	requires = { "StarterConveyor" },
	line = "Main",
	params = { multiplier = 1 },
	pad = { x = -30, z = -10 },
}

return BasicCollector
