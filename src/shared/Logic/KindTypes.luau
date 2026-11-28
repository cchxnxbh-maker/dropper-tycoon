--!strict
-- KindTypes: what every machine kind provides, and the line it adds itself to (plan sections 4.3 and 6, recipe B).
--
-- A kind is one file in `Logic/Kinds/` named after it. It has a rule for its `params` and an `apply` that adds the
-- machine to a `LineBuild`: the numbers `FactorySim` needs, collected before the simulation runs. Adding a kind is
-- adding a file; `FactorySim` asks each kind to add itself and never names one.
--
-- Pure Luau. State owned: none.
--
-- Usage:
--     local KindTypes = require("./KindTypes")
--     local kind: KindTypes.Kind = { kind = "Dropper", params = rule, apply = function(build, def) ... end }

local Validate = require("./Validate")

export type Def = {
	id: string,
	kind: string,
	params: { [string]: number },
}

export type DropperSpec = { id: string, at: number, itemValue: number, interval: number }
export type UpgraderSpec = { id: string, at: number, multiplier: number }

-- Everything the kinds report about one line. The line runs only with a conveyor (speed above 0) and a collector.
export type LineBuild = {
	speed: number,
	hasCollector: boolean,
	collectorMultiplier: number,
	droppers: { DropperSpec },
	upgraders: { UpgraderSpec },
}

export type Kind = {
	kind: string,
	-- Checks a machine's `params` table.
	params: Validate.Rule,
	-- Adds the machine to the line. Called once per owned machine, in ID order.
	apply: (build: LineBuild, def: Def) -> (),
}

return {}
