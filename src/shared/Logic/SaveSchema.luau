--!strict
-- SaveSchema: the shape of saved player data at the current version, and the rule that checks it (plan sections 4.7
-- and 12.1, ADR 0019).
--
-- Every save carries `schemaVersion`. Data saved at an older version is brought up to `CURRENT_VERSION` by the
-- migrations in `server/Migrations` (see `SaveLoad`), then checked here before the player enters the game. Saves hold
-- IDs and counts, never prices or rates, so a rebalance never needs a migration.
--
-- Changing the shape means: raise `CURRENT_VERSION`, update `SaveData` and `rule`, add one migration file and one
-- fixture of the old version under `tests/fixtures/saves/`. Published migrations and fixtures are never edited.
--
-- Pure Luau: no Roblox APIs, so Lune tests it. Exploiters can read it; it holds no secrets.
--
-- State owned: none.
--
-- Usage:
--     local problems = SaveSchema.validate(data)
--     if #problems > 0 then ... end -- one line per problem, such as `meta.joins: must be a whole number, got 1.5`

local Validate = require("./Validate")

-- Facts the game keeps about the player's sessions. Times are server Unix seconds; 0 means not set yet.
export type Meta = {
	-- Sessions started on any server, counting this one.
	joins: number,
	-- When the first session started.
	firstJoin: number,
	-- When the most recent session started.
	lastJoin: number,
}

-- Developer test values, changed only through the dev panel (`DevService` owns them). Version 2 adds the counter that
-- the Phase 0 exit test raises and checks after a rejoin.
export type Dev = {
	testCounter: number,
}

export type SaveData = {
	schemaVersion: number,
	meta: Meta,
	dev: Dev,
}

local SaveSchema = {}

-- The version this build writes. A save with a higher number was written by a newer build and is refused.
SaveSchema.CURRENT_VERSION = 2

local count = Validate.number({ integer = true, min = 0 })

SaveSchema.rule = Validate.record({
	schemaVersion = Validate.number({
		integer = true,
		min = SaveSchema.CURRENT_VERSION,
		max = SaveSchema.CURRENT_VERSION,
	}),
	meta = Validate.record({
		joins = count,
		firstJoin = count,
		lastJoin = count,
	}),
	dev = Validate.record({
		testCounter = count,
	}),
})

--[[
	Checks data against the current schema. Unknown fields count as problems, so a typo in a migration is caught.
	@param data the data to check, usually just migrated
	@return one line per problem, empty when the data is valid
]]
function SaveSchema.validate(data: any): Validate.Problems
	return Validate.run(data, SaveSchema.rule, "")
end

return SaveSchema
