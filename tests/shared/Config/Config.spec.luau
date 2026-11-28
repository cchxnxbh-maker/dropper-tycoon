--!strict
-- Specs for the config loader and schema: the real config is valid and frozen, and bad values give readable lines.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Config = require("../../../src/shared/Config")
local Schema = require("../../../src/shared/Config/Schema")

-- A valid config to break one value at a time: a copy of the real one, with small known values where tests read them.
local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, inner in value do
		out[key] = copy(inner)
	end
	return out
end

local function good(): any
	local config = copy(require("../../../src/shared/Config/Sources"))
	config.Build = { version = "1.2.3", devPlaceId = 1 }
	config.Flags = { Features = { offlineEarnings = false }, Log = { default = "info", tags = { Purchase = "debug" } } }
	config.Strings.Net = { kicked = "Bye." }
	return config
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

	it("rejects a kick threshold too low to survive one lag spike", function()
		local config = good()
		config.Tuning.Network.kickAfterStrikes = 2
		expect(Schema.validate(config)).toEqual({ "Tuning.Network.kickAfterStrikes: must be at least 5, got 2" })
	end)

	it("rejects empty or badly keyed player text", function()
		local config = good()
		config.Strings.Net.kicked = "  "
		config.Strings.Net.Shout = "Hi"
		expect(Schema.validate(config)).toEqual({
			'Strings.Net.Shout (name): must look like kicked (camelCase), got "Shout"',
			'Strings.Net.kicked: must look like real words (not empty), got "  "',
		})
	end)

	it("rejects plots that would overlap their neighbours", function()
		local config = good()
		config.Plots.baseSize = 200
		expect(Schema.validate(config)).toEqual({
			"Plots.baseSize: neighbouring plots overlap; centres are 250 studs apart but a plot needs 283. Make baseSize"
				.. " smaller or ringRadius larger",
		})
	end)

	it("rejects a colour that is not a hex code", function()
		local config = good()
		config.Plots.colors.base = "green"
		expect(Schema.validate(config)).toEqual({
			'Plots.colors.base: must look like #6E9A5A (a # and six hex digits), got "green"',
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

describe("Schema buildable rules", function()
	it("rejects params that break the kind's rule", function()
		local config = good()
		config.Buildables.CoalDropper.params.interval = 0
		expect(Schema.validate(config)).toEqual({
			"Buildables.CoalDropper.params.interval: must be at least 0.1, got 0",
		})
	end)

	it("rejects an unknown kind and a requirement list with gaps", function()
		local config = good()
		config.Buildables.CoalDropper.kind = "Furnace"
		config.Buildables.Washer.requires = { [2] = "CoalDropper" }
		local problems = Schema.validate(config)
		expect(#problems).toBe(2)
		expect(string.find(problems[1], "Buildables.CoalDropper.kind", 1, true) ~= nil).toBe(true)
		expect(string.find(problems[2], "Buildables.Washer.requires.2", 1, true) ~= nil).toBe(true)
	end)

	it("rejects levels on a kind that has none", function()
		local config = good()
		config.Buildables.StarterConveyor.levelPrice = 5
		expect(Schema.validate(config)).toEqual({
			"Buildables.StarterConveyor.levelPrice: a Conveyor has no levels; remove it",
		})
	end)

	it("rejects a requirement that does not exist and a machine with no name", function()
		local config = good()
		config.Buildables.CoalDropper.requires = { "OnyxDropper" }
		config.Strings.Buildables.washer = nil
		expect(Schema.validate(config)).toEqual({
			'Buildables.CoalDropper.requires: "OnyxDropper" is not a buildable',
			"Strings.Buildables.washer: missing; every machine needs a name",
		})
	end)

	it("rejects requirements that loop, naming every machine caught in the loop", function()
		local config = good()
		config.Buildables.StarterConveyor.requires = { "Washer" }
		expect(Schema.validate(config)).toEqual({
			"Buildables.BasicCollector.requires: the requirements loop back to BasicCollector",
			"Buildables.CoalDropper.requires: the requirements loop back to CoalDropper",
			"Buildables.CopperDropper.requires: the requirements loop back to CopperDropper",
			"Buildables.StarterConveyor.requires: the requirements loop back to StarterConveyor",
			"Buildables.Washer.requires: the requirements loop back to Washer",
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
