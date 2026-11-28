--!strict
-- Engraver: the first arch on the back row.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Upgrader.luau`.

local Types = require("../../Types/Config")

local Engraver: Types.BuildableDef = {
	id = "Engraver",
	kind = "Upgrader",
	tier = 1,
	price = 200000,
	requires = { "RubyDropper" },
	line = "Main",
	params = { multiplier = 1.5, at = 110, perLevel = 0.1 },
	levelPrice = 61000,
}

return Engraver
