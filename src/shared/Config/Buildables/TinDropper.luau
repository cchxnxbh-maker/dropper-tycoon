--!strict
-- TinDropper: a dropper on the front row.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Dropper.luau`.

local Types = require("../../Types/Config")

local TinDropper: Types.BuildableDef = {
	id = "TinDropper",
	kind = "Dropper",
	tier = 1,
	price = 240,
	requires = { "Washer" },
	line = "Main",
	params = { itemValue = 8, interval = 3, at = 350, perLevel = 0.5 },
	pad = { x = 24, z = -36 },
	levelPrice = 97,
}

return TinDropper
