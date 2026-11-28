--!strict
-- RubyDropper: the last dropper on the middle row.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Dropper.luau`.

local Types = require("../../Types/Config")

local RubyDropper: Types.BuildableDef = {
	id = "RubyDropper",
	kind = "Dropper",
	tier = 1,
	price = 120000,
	requires = { "Painter" },
	line = "Main",
	params = { itemValue = 380, interval = 3.5, at = 160, perLevel = 0.5 },
	levelPrice = 37000,
}

return RubyDropper
