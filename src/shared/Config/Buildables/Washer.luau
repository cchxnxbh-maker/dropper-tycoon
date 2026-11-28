--!strict
-- Washer: the last arch before the collector, so every item passes it.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Upgrader.luau`.

local Types = require("../../Types/Config")

local Washer: Types.BuildableDef = {
	id = "Washer",
	kind = "Upgrader",
	tier = 1,
	price = 88,
	requires = { "CopperDropper" },
	line = "Main",
	params = { multiplier = 1.5, at = 392, perLevel = 0.1 },
	pad = { x = 8, z = -36 },
	levelPrice = 73,
}

return Washer
