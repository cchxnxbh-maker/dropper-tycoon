--!strict
-- BigCollector: a bigger bin that pays 1.5 times for everything it collects.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Collector.luau`.

local Types = require("../../Types/Config")

local BigCollector: Types.BuildableDef = {
	id = "BigCollector",
	kind = "Collector",
	tier = 1,
	price = 16000,
	requires = { "Polisher" },
	line = "Main",
	params = { multiplier = 1.5 },
	pad = { x = 30, z = -26 },
}

return BigCollector
