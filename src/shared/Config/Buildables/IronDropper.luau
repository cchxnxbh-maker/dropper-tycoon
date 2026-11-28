--!strict
-- IronDropper: the third dropper, heavier items.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Dropper.luau`.

local Types = require("../../Types/Config")

local IronDropper: Types.BuildableDef = {
	id = "IronDropper",
	kind = "Dropper",
	tier = 1,
	price = 500,
	requires = { "CopperDropper" },
	line = "Main",
	params = { itemValue = 12, interval = 3, at = 25 },
	pad = { x = 50, z = -10 },
}

return IronDropper
