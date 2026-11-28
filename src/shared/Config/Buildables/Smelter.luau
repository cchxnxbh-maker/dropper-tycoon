--!strict
-- Smelter: an arch on the middle row.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Upgrader.luau`.

local Types = require("../../Types/Config")

local Smelter: Types.BuildableDef = {
	id = "Smelter",
	kind = "Upgrader",
	tier = 1,
	price = 16000,
	requires = { "GoldDropper" },
	line = "Main",
	params = { multiplier = 1.5, at = 230, perLevel = 0.1 },
	pad = { x = 8, z = -22 },
	levelPrice = 5000,
}

return Smelter
