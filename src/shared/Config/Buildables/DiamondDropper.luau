--!strict
-- DiamondDropper: the last tier 1 dropper. Its items are worth the most.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Dropper.luau`.

local Types = require("../../Types/Config")

local DiamondDropper: Types.BuildableDef = {
	id = "DiamondDropper",
	kind = "Dropper",
	tier = 1,
	price = 22000,
	requires = { "GoldDropper", "BigCollector" },
	line = "Main",
	params = { itemValue = 250, interval = 5, at = 52 },
	pad = { x = 50, z = -26 },
}

return DiamondDropper
