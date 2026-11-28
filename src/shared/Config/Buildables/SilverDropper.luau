--!strict
-- SilverDropper: a dropper on the front row.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Dropper.luau`.

local Types = require("../../Types/Config")

local SilverDropper: Types.BuildableDef = {
	id = "SilverDropper",
	kind = "Dropper",
	tier = 1,
	price = 3300,
	requires = { "Sorter" },
	line = "Main",
	params = { itemValue = 35, interval = 3, at = 300, perLevel = 0.5 },
	pad = { x = -40, z = -22 },
	levelPrice = 1100,
}

return SilverDropper
