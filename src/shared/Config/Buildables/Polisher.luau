--!strict
-- Polisher: a second arch near the end of the belt that doubles the value of every item passing under it.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Upgrader.luau`.

local Types = require("../../Types/Config")

local Polisher: Types.BuildableDef = {
	id = "Polisher",
	kind = "Upgrader",
	tier = 1,
	price = 3500,
	requires = { "SilverDropper", "Washer" },
	line = "Main",
	params = { multiplier = 2, at = 75 },
	pad = { x = -10, z = -26 },
}

return Polisher
