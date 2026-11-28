--!strict
-- SaveLoad: decides what happens to a save when it is loaded (plan sections 4.7 and 12.1, ADR 0019).
--
-- A loaded save is brought up to the current schema version by running each migration in turn on a copy, then
-- checked against `SaveSchema`. The original is never changed, so a save that fails is still exactly as it was and
-- can be quarantined and fixed later. A save written by a newer build is refused without touching it, which keeps it
-- safe while old and new servers run side by side.
--
-- A brand-new player's data is an empty table, which counts as version 0. Migration `v001` turns it into a version 1
-- save, so every new save goes through the same path as an old one.
--
-- Pure Luau: no Roblox APIs and no clock, so Lune tests it with stored fixtures of every past version.
--
-- State owned: none.
--
-- Usage:
--     local result = SaveLoad.prepare(profile.Data, Migrations, SaveSchema)
--     if result.kind == "ready" then profile.Data = result.data end

local Validate = require("./Validate")

-- One step of the save format. `migrate` gets a private copy at version `from` and returns it at version `to`.
-- `SaveLoad` sets `schemaVersion` itself after each step.
export type Migration = {
	from: number,
	to: number,
	migrate: (data: any) -> any,
}

-- What `prepare` needs to know about the schema. `SaveSchema` fits it; tests pass small fakes.
export type Schema = {
	CURRENT_VERSION: number,
	validate: (data: any) -> Validate.Problems,
}

-- ready: `data` is a migrated, valid copy to use. `fromVersion` is the version it was saved at.
-- newer: the save is from a newer build; leave it alone and ask the player to rejoin.
-- invalid: the save could not be migrated or failed validation; quarantine it and never overwrite it.
export type Result =
	{ kind: "ready", data: any, fromVersion: number }
	| { kind: "newer", version: number }
	| { kind: "invalid", problems: { string } }

local SaveLoad = {}

-- Keys of a table in sorted order, so nothing here depends on hash order (Logic rule in CLAUDE.md).
local function sortedKeys(value: { [any]: any }): { any }
	local keys = {}
	for key in value do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for _, key in sortedKeys(value) do
		copy[key] = deepCopy(value[key])
	end
	return copy
end

--[[
	A deep copy of plain data: tables are copied all the way down, other values are kept. Used so a migration or a
	mutation never writes into data someone else holds.
	@param value plain data with no cycles
	@return the copy
]]
SaveLoad.deepCopy = deepCopy

--[[
	Checks that the migrations form one unbroken chain from version 0 to the current version: one step per version,
	each going up by exactly one.
	@param migrations the migration files by name, from `server/Migrations`
	@param current the schema's current version
	@return one line per problem, empty when the chain is complete
]]
function SaveLoad.checkChain(migrations: { [string]: Migration }, current: number): { string }
	local problems = {}
	local byFrom: { [number]: string } = {}
	local names = sortedKeys(migrations)
	for _, name in names do
		local migration = migrations[name]
		if type(migration.from) ~= "number" or migration.to ~= migration.from + 1 then
			table.insert(problems, `{name}: must go up exactly one version, from {migration.from} to {migration.to}`)
		elseif byFrom[migration.from] ~= nil then
			table.insert(problems, `{name}: version {migration.from} already has a migration, {byFrom[migration.from]}`)
		else
			byFrom[migration.from] = name
		end
	end
	for version = 0, current - 1 do
		if byFrom[version] == nil then
			table.insert(problems, `no migration from version {version} to {version + 1}`)
		end
	end
	for _, name in names do
		local from = migrations[name].from
		if type(from) == "number" and (from < 0 or from >= current) then
			table.insert(problems, `{name}: starts at version {from}, outside 0 to {current - 1}`)
		end
	end
	return problems
end

--[[
	Brings a loaded save up to the current version and checks it. Never changes `raw`.
	@param raw the save as loaded; an empty table for a new player
	@param migrations the migration files by name; the chain must be complete (see `checkChain`)
	@param schema the current version and its validator
	@return ready with a migrated copy, newer when the save's version is above the current one, or invalid with the
	reasons. A migration that throws gives invalid, not an error.
]]
function SaveLoad.prepare(raw: any, migrations: { [string]: Migration }, schema: Schema): Result
	if type(raw) ~= "table" then
		return { kind = "invalid", problems = { `the save must be a table, got a {type(raw)}` } }
	end
	local version = if raw.schemaVersion == nil then 0 else raw.schemaVersion
	if type(version) ~= "number" or version % 1 ~= 0 or version < 0 then
		return { kind = "invalid", problems = { `schemaVersion must be a whole number of 0 or more, got {version}` } }
	end
	if version > schema.CURRENT_VERSION then
		return { kind = "newer", version = version }
	end

	local byFrom: { [number]: Migration } = {}
	for _, name in sortedKeys(migrations) do
		byFrom[migrations[name].from] = migrations[name]
	end

	local data = deepCopy(raw)
	local fromVersion = version
	while version < schema.CURRENT_VERSION do
		local migration = byFrom[version]
		if migration == nil then
			return { kind = "invalid", problems = { `no migration from version {version}` } }
		end
		local ok, migrated = pcall(migration.migrate, data)
		if not ok then
			return { kind = "invalid", problems = { `migration from version {version} failed: {migrated}` } }
		end
		if type(migrated) ~= "table" then
			return { kind = "invalid", problems = { `migration from version {version} returned no table` } }
		end
		data = migrated
		version = migration.to
		data.schemaVersion = version
	end

	local problems = schema.validate(data)
	if #problems > 0 then
		return { kind = "invalid", problems = problems }
	end
	return { kind = "ready", data = data, fromVersion = fromVersion }
end

return SaveLoad
