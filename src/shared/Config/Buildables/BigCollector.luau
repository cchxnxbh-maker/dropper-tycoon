--!strict
-- BigCollector: a bigger bin that pays twice for every item.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Collector.luau`.

local Types = require("../../Types/Config")

local BigCollector: Types.BuildableDef = {
	id = "BigCollector",
	kind = "Collector",
	tier = 1,
	price = 28000,
	requires = { "Smelter" },
	line = "Main",
	params = { multiplier = 2, perLevel = 0.1 },
	pad = { x = -50, z = -18 },
	levelPrice = 8600,
}

return BigCollector
