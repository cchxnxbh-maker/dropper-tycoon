--!strict
-- FastConveyor: a faster belt, so new items reach the collector sooner.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Conveyor.luau`.

local Types = require("../../Types/Config")

local FastConveyor: Types.BuildableDef = {
	id = "FastConveyor",
	kind = "Conveyor",
	tier = 1,
	price = 1200,
	requires = { "IronDropper" },
	line = "Main",
	params = { speed = 14 },
	pad = { x = 56, z = -36 },
}

return FastConveyor
