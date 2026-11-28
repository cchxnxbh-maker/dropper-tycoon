--!strict
-- Polisher: an arch on the front row.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Upgrader.luau`.

local Types = require("../../Types/Config")

local Polisher: Types.BuildableDef = {
	id = "Polisher",
	kind = "Upgrader",
	tier = 1,
	price = 5700,
	requires = { "SilverDropper" },
	line = "Main",
	params = { multiplier = 1.5, at = 315, perLevel = 0.1 },
	pad = { x = -24, z = -22 },
	levelPrice = 1800,
}

return Polisher
