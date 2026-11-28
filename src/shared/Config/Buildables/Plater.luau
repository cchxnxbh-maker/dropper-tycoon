--!strict
-- Plater: an arch on the back row; Diamond items pass it.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Upgrader.luau`.

local Types = require("../../Types/Config")

local Plater: Types.BuildableDef = {
	id = "Plater",
	kind = "Upgrader",
	tier = 1,
	price = 740000,
	requires = { "SapphireDropper" },
	line = "Main",
	params = { multiplier = 1.6, at = 60, perLevel = 0.1 },
	levelPrice = 220000,
}

return Plater
