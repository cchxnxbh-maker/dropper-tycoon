--!strict
-- GoldDropper: the first dropper on the middle row.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Dropper.luau`.

local Types = require("../../Types/Config")

local GoldDropper: Types.BuildableDef = {
	id = "GoldDropper",
	kind = "Dropper",
	tier = 1,
	price = 9700,
	requires = { "Polisher" },
	line = "Main",
	params = { itemValue = 70, interval = 3, at = 260, perLevel = 0.5 },
	levelPrice = 3100,
}

return GoldDropper
