--!strict
-- GoldDropper: the fifth dropper.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Dropper.luau`.

local Types = require("../../Types/Config")

local GoldDropper: Types.BuildableDef = {
	id = "GoldDropper",
	kind = "Dropper",
	tier = 1,
	price = 7000,
	requires = { "SilverDropper" },
	line = "Main",
	params = { itemValue = 80, interval = 4, at = 45 },
	pad = { x = 10, z = -26 },
}

return GoldDropper
