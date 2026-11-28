--!strict
-- CoalDropper: the first dropper, next to the collector so cash arrives at once. Free.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Dropper.luau`.

local Types = require("../../Types/Config")

local CoalDropper: Types.BuildableDef = {
	id = "CoalDropper",
	kind = "Dropper",
	tier = 1,
	price = 0,
	requires = { "BasicCollector" },
	line = "Main",
	params = { itemValue = 1, interval = 2, at = 385, perLevel = 0.5 },
	pad = { x = -24, z = -36 },
	levelPrice = 7,
}

return CoalDropper
