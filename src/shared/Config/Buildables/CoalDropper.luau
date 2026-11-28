--!strict
-- CoalDropper: the first dropper, at the start of the belt. Free, so cash starts flowing.
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
	params = { itemValue = 2, interval = 2, at = 5 },
	pad = { x = -10, z = -10 },
}

return CoalDropper
