--!strict
-- DiamondDropper: the best dropper, at the very start of the belt, so its items pass every arch.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Dropper.luau`.

local Types = require("../../Types/Config")

local DiamondDropper: Types.BuildableDef = {
	id = "DiamondDropper",
	kind = "Dropper",
	tier = 1,
	price = 1200000,
	requires = { "Plater" },
	line = "Main",
	params = { itemValue = 1900, interval = 4, at = 30, perLevel = 0.5 },
	pad = { x = 24, z = -8 },
	levelPrice = 360000,
}

return DiamondDropper
