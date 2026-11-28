--!strict
-- EmeraldDropper: a dropper on the middle row.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Dropper.luau`.

local Types = require("../../Types/Config")

local EmeraldDropper: Types.BuildableDef = {
	id = "EmeraldDropper",
	kind = "Dropper",
	tier = 1,
	price = 46000,
	requires = { "BigCollector" },
	line = "Main",
	params = { itemValue = 180, interval = 3.5, at = 200, perLevel = 0.5 },
	pad = { x = 40, z = -22 },
	levelPrice = 14000,
}

return EmeraldDropper
