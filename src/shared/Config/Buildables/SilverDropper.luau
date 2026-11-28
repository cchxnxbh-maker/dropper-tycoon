--!strict
-- SilverDropper: the fourth dropper.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Dropper.luau`.

local Types = require("../../Types/Config")

local SilverDropper: Types.BuildableDef = {
	id = "SilverDropper",
	kind = "Dropper",
	tier = 1,
	price = 1500,
	requires = { "IronDropper" },
	line = "Main",
	params = { itemValue = 30, interval = 3, at = 35 },
	pad = { x = -30, z = -26 },
}

return SilverDropper
