--!strict
-- CopperDropper: the second dropper.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Dropper.luau`.

local Types = require("../../Types/Config")

local CopperDropper: Types.BuildableDef = {
	id = "CopperDropper",
	kind = "Dropper",
	tier = 1,
	price = 27,
	requires = { "CoalDropper" },
	line = "Main",
	params = { itemValue = 3, interval = 2.5, at = 390, perLevel = 0.5 },
	levelPrice = 27,
}

return CopperDropper
