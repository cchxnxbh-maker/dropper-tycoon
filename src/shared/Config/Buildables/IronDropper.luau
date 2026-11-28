--!strict
-- IronDropper: a dropper on the front row.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Dropper.luau`.

local Types = require("../../Types/Config")

local IronDropper: Types.BuildableDef = {
	id = "IronDropper",
	kind = "Dropper",
	tier = 1,
	price = 620,
	requires = { "TinDropper" },
	line = "Main",
	params = { itemValue = 16, interval = 3, at = 330, perLevel = 0.5 },
	pad = { x = 40, z = -36 },
	levelPrice = 230,
}

return IronDropper
