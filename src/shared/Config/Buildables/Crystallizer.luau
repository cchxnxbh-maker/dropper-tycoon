--!strict
-- Crystallizer: an arch just past the Diamond Dropper, so only Diamond items pass it.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Upgrader.luau`.

local Types = require("../../Types/Config")

local Crystallizer: Types.BuildableDef = {
	id = "Crystallizer",
	kind = "Upgrader",
	tier = 1,
	price = 1900000,
	requires = { "DiamondDropper" },
	line = "Main",
	params = { multiplier = 1.6, at = 45, perLevel = 0.1 },
	levelPrice = 570000,
}

return Crystallizer
