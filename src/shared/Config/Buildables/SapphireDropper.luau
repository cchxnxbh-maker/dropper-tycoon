--!strict
-- SapphireDropper: a dropper on the back row.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Dropper.luau`.

local Types = require("../../Types/Config")

local SapphireDropper: Types.BuildableDef = {
	id = "SapphireDropper",
	kind = "Dropper",
	tier = 1,
	price = 460000,
	requires = { "TurboConveyor" },
	line = "Main",
	params = { itemValue = 850, interval = 4, at = 90, perLevel = 0.5 },
	levelPrice = 130000,
}

return SapphireDropper
