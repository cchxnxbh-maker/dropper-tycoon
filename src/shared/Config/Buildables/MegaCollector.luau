--!strict
-- MegaCollector: the best bin, paying three times for every item. The last machine of tier 1.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Collector.luau`.

local Types = require("../../Types/Config")

local MegaCollector: Types.BuildableDef = {
	id = "MegaCollector",
	kind = "Collector",
	tier = 1,
	price = 3000000,
	requires = { "Crystallizer" },
	line = "Main",
	params = { multiplier = 3, perLevel = 0.1 },
	pad = { x = 56, z = -8 },
	levelPrice = 900000,
}

return MegaCollector
