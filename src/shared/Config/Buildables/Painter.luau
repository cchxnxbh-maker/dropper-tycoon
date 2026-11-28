--!strict
-- Painter: an arch on the middle row.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Upgrader.luau`.

local Types = require("../../Types/Config")

local Painter: Types.BuildableDef = {
	id = "Painter",
	kind = "Upgrader",
	tier = 1,
	price = 75000,
	requires = { "EmeraldDropper" },
	line = "Main",
	params = { multiplier = 1.5, at = 185, perLevel = 0.1 },
	levelPrice = 23000,
}

return Painter
