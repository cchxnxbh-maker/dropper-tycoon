--!strict
-- CopperDropper: the second dropper. Its items are worth more.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Dropper.luau`.

local Types = require("../../Types/Config")

local CopperDropper: Types.BuildableDef = {
	id = "CopperDropper",
	kind = "Dropper",
	tier = 1,
	price = 30,
	requires = { "CoalDropper" },
	line = "Main",
	params = { itemValue = 5, interval = 2.5, at = 15 },
	pad = { x = 10, z = -10 },
}

return CopperDropper
