--!strict
-- Specs for SaveLoad and SaveSchema: every stored fixture migrates and validates, the migration chain is complete,
-- newer saves are refused, bad saves are reported, and the original save is never changed.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Fixtures = require("../../fixtures/saves")
local Migrations = require("../../../src/server/Migrations")
local SaveLoad = require("../../../src/shared/Logic/SaveLoad")
local SaveSchema = require("../../../src/shared/Logic/SaveSchema")

local CURRENT = SaveSchema.CURRENT_VERSION

local function fixtureName(version: number): string
	return string.format("v%03d", version)
end

-- A fake schema at version 3 that accepts any table carrying `steps`, so the runner can be tested on its own.
local fakeSchema: SaveLoad.Schema = {
	CURRENT_VERSION = 3,
	validate = function(data)
		return if type(data.steps) == "table" then {} else { "steps: missing" }
	end,
}

local function step(from: number): SaveLoad.Migration
	return {
		from = from,
		to = from + 1,
		migrate = function(data)
			data.steps = data.steps or {}
			table.insert(data.steps, from)
			return data
		end,
	}
end

local fakeChain: { [string]: SaveLoad.Migration } = { a = step(0), b = step(1), c = step(2) }

describe("Save fixtures", function()
	it("has a stored fixture for every version from 0 to the current one", function()
		for version = 0, CURRENT do
			expect(Fixtures[fixtureName(version)] ~= nil).toBe(true)
		end
	end)

	it("has no fixture newer than the current version", function()
		for name in Fixtures do
			local version = tonumber(string.sub(name, 2))
			expect(version ~= nil and version <= CURRENT).toBe(true)
		end
	end)

	it("migrates and validates every stored fixture", function()
		for version = 0, CURRENT do
			local result = SaveLoad.prepare(Fixtures[fixtureName(version)], Migrations, SaveSchema)
			expect(result.kind).toBe("ready")
			if result.kind == "ready" then
				expect(result.data.schemaVersion).toBe(CURRENT)
				expect(result.fromVersion).toBe(version)
				expect(#SaveSchema.validate(result.data)).toBe(0)
			end
		end
	end)

	it("turns a new player's empty save into a fresh one with zero counts", function()
		local result = SaveLoad.prepare({}, Migrations, SaveSchema)
		expect(result.kind).toBe("ready")
		if result.kind == "ready" then
			expect(result.data).toEqual({
				schemaVersion = CURRENT,
				meta = { joins = 0, firstJoin = 0, lastJoin = 0 },
				dev = { testCounter = 0 },
				economy = { cash = 0 },
				factory = { owned = {} },
			})
		end
	end)

	it("keeps a version 2 save's values and starts it with no cash and no machines", function()
		local result = SaveLoad.prepare(Fixtures.v002, Migrations, SaveSchema)
		expect(result.kind).toBe("ready")
		if result.kind == "ready" then
			expect(result.data.meta).toEqual(Fixtures.v002.meta)
			expect(result.data.dev).toEqual(Fixtures.v002.dev)
			expect(result.data.economy).toEqual({ cash = 0 })
			expect(result.data.factory).toEqual({ owned = {} })
		end
	end)

	it("refuses negative cash and owned entries that are not true or false", function()
		local data = table.clone(Fixtures.v003) :: any
		data.economy = { cash = -1 }
		data.factory = { owned = { CoalDropper = 1 } }
		expect(#SaveSchema.validate(data)).toBe(2)
	end)

	it("keeps a version 1 save's values and starts its test counter at 0", function()
		local result = SaveLoad.prepare(Fixtures.v001, Migrations, SaveSchema)
		expect(result.kind).toBe("ready")
		if result.kind == "ready" then
			expect(result.data.meta).toEqual(Fixtures.v001.meta)
			expect(result.data.dev).toEqual({ testCounter = 0 })
		end
	end)

	it("keeps a current save's values as they are", function()
		local result = SaveLoad.prepare(Fixtures[fixtureName(CURRENT)], Migrations, SaveSchema)
		expect(result.kind).toBe("ready")
		if result.kind == "ready" then
			expect(result.data).toEqual(Fixtures[fixtureName(CURRENT)])
		end
	end)
end)

describe("Migration chain", function()
	it("is complete for the real migrations", function()
		expect(SaveLoad.checkChain(Migrations, CURRENT)).toEqual({})
	end)

	it("reports a missing step", function()
		local problems = SaveLoad.checkChain({ a = step(0), c = step(2) }, 3)
		expect(problems).toEqual({ "no migration from version 1 to 2" })
	end)

	it("reports a step that skips a version", function()
		local skip: SaveLoad.Migration = { from = 0, to = 2, migrate = step(0).migrate }
		local problems = SaveLoad.checkChain({ a = skip, b = step(1) }, 2)
		expect(problems[1]).toBe("a: must go up exactly one version, from 0 to 2")
	end)

	it("reports two migrations from the same version", function()
		local problems = SaveLoad.checkChain({ a = step(0), b = step(0) }, 1)
		expect(problems).toEqual({ "b: version 0 already has a migration, a" })
	end)

	it("reports a migration beyond the current version", function()
		local problems = SaveLoad.checkChain({ a = step(0), b = step(1) }, 1)
		expect(problems).toEqual({ "b: starts at version 1, outside 0 to 0" })
	end)
end)

describe("SaveLoad.prepare", function()
	it("runs every step in order and stamps the version after each", function()
		local result = SaveLoad.prepare({ schemaVersion = 1, steps = {} }, fakeChain, fakeSchema)
		expect(result.kind).toBe("ready")
		if result.kind == "ready" then
			expect(result.data).toEqual({ schemaVersion = 3, steps = { 1, 2 } })
			expect(result.fromVersion).toBe(1)
		end
	end)

	it("refuses a save from a newer build and says which version", function()
		local result = SaveLoad.prepare({ schemaVersion = 4 }, fakeChain, fakeSchema)
		expect(result).toEqual({ kind = "newer", version = 4 })
	end)

	it("never changes the save it was given", function()
		local raw = { schemaVersion = 1, steps = { 9 } }
		SaveLoad.prepare(raw, fakeChain, fakeSchema)
		expect(raw).toEqual({ schemaVersion = 1, steps = { 9 } })
	end)

	it("reports a save that fails validation", function()
		local result = SaveLoad.prepare({ schemaVersion = 1, meta = { joins = -1 } }, Migrations, SaveSchema)
		expect(result.kind).toBe("invalid")
		if result.kind == "invalid" then
			expect(result.problems).toEqual({
				"meta.firstJoin: must be a number, got nil",
				"meta.joins: must be at least 0, got -1",
				"meta.lastJoin: must be a number, got nil",
			})
		end
	end)

	it("reports an unknown field, so a typo in a migration is caught", function()
		local save = { schemaVersion = 1, meta = { joins = 0, firstJoin = 0, lastJoin = 0 }, cahs = 5 }
		local result = SaveLoad.prepare(save, Migrations, SaveSchema)
		expect(result.kind).toBe("invalid")
	end)

	it("reports a version that is not a whole number of 0 or more", function()
		for _, bad in { -1, 1.5, "1", true } :: { any } do
			expect(SaveLoad.prepare({ schemaVersion = bad }, fakeChain, fakeSchema).kind).toBe("invalid")
		end
	end)

	it("reports a save that is not a table", function()
		expect(SaveLoad.prepare("hello", fakeChain, fakeSchema).kind).toBe("invalid")
	end)

	it("reports a migration that throws, without throwing itself", function()
		local broken: SaveLoad.Migration = {
			from = 0,
			to = 1,
			migrate = function(_data)
				error("boom", 0)
			end,
		}
		local result = SaveLoad.prepare({}, { a = broken }, { CURRENT_VERSION = 1, validate = fakeSchema.validate })
		expect(result.kind).toBe("invalid")
		if result.kind == "invalid" then
			expect(result.problems).toEqual({ "migration from version 0 failed: boom" })
		end
	end)

	it("reports a gap in the chain instead of looping", function()
		local result = SaveLoad.prepare({}, { a = step(0) }, fakeSchema)
		expect(result).toEqual({ kind = "invalid", problems = { "no migration from version 1" } })
	end)
end)

describe("SaveLoad.deepCopy", function()
	it("copies nested tables so changing the copy leaves the original alone", function()
		local original = { a = { b = { 1, 2 } }, c = "x" }
		local copy = SaveLoad.deepCopy(original)
		copy.a.b[1] = 99
		expect(original.a.b[1]).toBe(1)
		expect(copy.c).toBe("x")
	end)
end)
