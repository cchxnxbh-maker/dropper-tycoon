--!strict
-- Washer: an arch over the belt that makes every item passing under it worth 1.5 times as much.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Upgrader.luau`.

local Types = require("../../Types/Config")

local Washer: Types.BuildableDef = {
	id = "Washer",
	kind = "Upgrader",
	tier = 1,
	price = 150,
	requires = { "CopperDropper" },
	line = "Main",
	params = { multiplier = 1.5, at = 60 },
	pad = { x = 40, z = -10 },
}

return Washer
