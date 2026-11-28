--!strict
-- TurboConveyor: the fastest belt.
-- Every number is a starting value for the balance pass. Rules: `Config/Schema.luau` and the kind's own file in
-- `Logic/Kinds/Conveyor.luau`.

local Types = require("../../Types/Config")

local TurboConveyor: Types.BuildableDef = {
	id = "TurboConveyor",
	kind = "Conveyor",
	tier = 1,
	price = 310000,
	requires = { "Engraver" },
	line = "Main",
	params = { speed = 22 },
	pad = { x = -24, z = -8 },
}

return TurboConveyor
