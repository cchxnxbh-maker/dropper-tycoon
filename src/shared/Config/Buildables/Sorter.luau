--!strict
-- Sorter: an arch on the front row; items from droppers before it pass under.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Upgrader.luau`.

local Types = require("../../Types/Config")

local Sorter: Types.BuildableDef = {
	id = "Sorter",
	kind = "Upgrader",
	tier = 1,
	price = 1900,
	requires = { "FastConveyor" },
	line = "Main",
	params = { multiplier = 1.5, at = 360, perLevel = 0.1 },
	levelPrice = 640,
}

return Sorter
