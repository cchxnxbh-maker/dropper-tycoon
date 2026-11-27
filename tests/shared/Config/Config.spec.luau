--!strict
-- Specs for the config loader and schema: the real config is valid and frozen, and bad values give readable lines.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Config = require("../../../src/shared/Config")
local Schema = require("../../../src/shared/Config/Schema")

-- A valid config to break one value at a time.
local function good(): any
	return {
		Build = { version = "1.2.3" },
		Flags = { Features = { offlineEarnings = false }, Log = { default = "info", tags = { Purchase = "debug" } } },
		Tuning = { Timing = { simRate = 10, maxCatchUpSteps = 5 } },
		Buildables = { CoalDropper = { id = "CoalDropper" } },
	}
end

describe("Config", function()
	it("loads the real config files, which pass the schema", function()
		expect(Config.Tuning.Timing.simRate).toBe(10)
		expect(Schema.validate(require("../../../src/shared/Config/Sources"))).toEqual({})
	end)

	it("is frozen all the way down", function()
		expect(table.isfrozen(Config)).toBe(true)
		expect(table.isfrozen(Config.Tuning.Timing)).toBe(true)
		expect(table.isfrozen(Config.Flags.Log.tags)).toBe(true)
		expect(function()
			(Config.Tuning.Timing :: any).simRate = 1
		end).toThrow("readonly")
	end)
end)

describe("Schema.validate", function()
	it("accepts a valid config", function()
		expect(Schema.validate(good())).toEqual({})
	end)

	it("rejects a simulation rate out of range", function()
		local config = good()
		config.Tuning.Timing.simRate = 0
		expect(Schema.validate(config)).toEqual({ "Tuning.Timing.simRate: must be at least 1, got 0" })
	end)

	it("rejects an unknown log level", function()
		local config = good()
		config.Flags.Log.tags.Purchase = "loud"
		expect(Schema.validate(config)).toEqual({
			'Flags.Log.tags.Purchase: must be one of debug, info, warn, error, got "loud"',
		})
	end)

	it("rejects a malformed version and a badly named flag", function()
		local config = good()
		config.Build.version = "1.2"
		config.Flags.Features.OfflineEarnings = "yes"
		expect(Schema.validate(config)).toEqual({
			'Build.version: must look like 1.2.3 (three whole numbers), got "1.2"',
			'Flags.Features.OfflineEarnings (name): must look like offlineEarnings (camelCase), got "OfflineEarnings"',
			'Flags.Features.OfflineEarnings: must be true or false, got "yes"',
		})
	end)

	it("rejects a misspelled tuning field", function()
		local config = good()
		config.Tuning.Timing.simrate = 10
		expect(Schema.validate(config)).toEqual({
			"Tuning.Timing.simrate: is not a known field (check the spelling), got 10",
		})
	end)

	it("rejects a buildable whose id is not its file name", function()
		local config = good()
		config.Buildables.CoalDropper.id = "IronDropper"
		expect(Schema.validate(config)).toEqual({
			'Buildables.CoalDropper.id: must match the file name "CoalDropper", got "IronDropper"',
		})
	end)
end)

describe("Schema.report", function()
	it("gives a heading and one indented line per problem", function()
		expect(Schema.report({ "a: bad", "b: bad" })).toBe(
			"Config has 2 problems. Fix these in src/shared/Config:\n  a: bad\n  b: bad"
		)
		expect(Schema.report({ "a: bad" })).toBe("Config has 1 problem. Fix these in src/shared/Config:\n  a: bad")
	end)
end)
