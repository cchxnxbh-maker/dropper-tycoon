--!strict
-- Levels: what a machine's next level costs, and the machine definitions with their levels filled in for the
-- simulation (ADR 0023).
--
-- A machine with a `levelPrice` can be raised from level 1 up to `Economy.levels.maxLevel` on its own pad. Level 2
-- costs `levelPrice`; each level after costs `priceGrowth` times the one before, rounded to a whole number. Saves keep
-- only the level of each machine above 1, never a price.
--
-- Pure Luau. State owned: none.
--
-- Usage:
--     local cost = Levels.price(def, Levels.of(levels, def.id), Config.Economy.levels)
--     local defs = Levels.defs(Config.Buildables, ownedIds, levels)

local Types = require("../Types/Config")

export type Rules = { maxLevel: number, priceGrowth: number }

-- A machine definition as the simulation reads it, with its level.
export type LeveledDef = {
	id: string,
	kind: string,
	params: { [string]: number },
	level: number,
}

local Levels = {}

--[[
	@param levels saved levels by machine ID; a machine not listed is at level 1
	@param id the machine
	@return its level, 1 or more
]]
function Levels.of(levels: { [string]: number }, id: string): number
	return levels[id] or 1
end

--[[
	What raising a machine from `level` to the next costs.
	@param def the machine
	@param level its level now
	@param rules `Economy.levels`
	@return the price; nil when the machine has no levels or is at the top level
]]
function Levels.price(def: Types.BuildableDef, level: number, rules: Rules): number?
	local base = def.levelPrice
	if base == nil or level >= rules.maxLevel then
		return nil
	end
	return math.round(base * rules.priceGrowth ^ (level - 1))
end

--[[
	The owned machines as the simulation reads them, each with its level.
	@param buildables the buildable registry
	@param ids the owned machine IDs; an ID with no definition is skipped
	@param levels saved levels by machine ID
	@return one definition per owned machine
]]
function Levels.defs(
	buildables: { [string]: Types.BuildableDef },
	ids: { string },
	levels: { [string]: number }
): { LeveledDef }
	local defs: { LeveledDef } = {}
	for _, id in ids do
		local def = buildables[id]
		if def then
			table.insert(defs, { id = def.id, kind = def.kind, params = def.params, level = Levels.of(levels, id) })
		end
	end
	return defs
end

return Levels
