--!strict
-- FastConveyor: a faster belt. Items reach the collector sooner, so new droppers pay off sooner.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Conveyor.luau`.

local Types = require("../../Types/Config")

local FastConveyor: Types.BuildableDef = {
	id = "FastConveyor",
	kind = "Conveyor",
	tier = 1,
	price = 900,
	requires = { "Washer" },
	line = "Main",
	params = { speed = 14 },
	pad = { x = -50, z = -26 },
}

return FastConveyor
