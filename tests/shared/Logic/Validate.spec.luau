--!strict
-- Specs for Validate: each rule's messages, full paths, sorted order, and misspelled-field detection.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Validate = require("../../../src/shared/Logic/Validate")

local function check(value: any, rule: Validate.Rule): { string }
	return Validate.run(value, rule, "Root")
end

describe("Validate.number", function()
	local rule = Validate.number({ integer = true, min = 1, max = 60 })

	it("accepts a number inside the range", function()
		expect(check(10, rule)).toEqual({})
		expect(check(1, rule)).toEqual({})
		expect(check(60, rule)).toEqual({})
	end)

	it("names the limit and the bad value", function()
		expect(check(0, rule)).toEqual({ "Root: must be at least 1, got 0" })
		expect(check(61, rule)).toEqual({ "Root: must be at most 60, got 61" })
		expect(check(2.5, rule)).toEqual({ "Root: must be a whole number, got 2.5" })
	end)

	it("rejects text, nil and NaN", function()
		expect(check("10", rule)).toEqual({ 'Root: must be a number, got "10"' })
		expect(check(nil, rule)).toEqual({ "Root: must be a number, got nil" })
		expect(#check(0 / 0, rule)).toBe(1)
	end)
end)

describe("Validate.string and Validate.boolean", function()
	it("lists the allowed values", function()
		local rule = Validate.string({ oneOf = { "debug", "info" } })
		expect(check("info", rule)).toEqual({})
		expect(check("loud", rule)).toEqual({ 'Root: must be one of debug, info, got "loud"' })
	end)

	it("uses the hint when a pattern does not match", function()
		local rule = Validate.string({ pattern = "^%d+$", hint = "like 12" })
		expect(check("12", rule)).toEqual({})
		expect(check("x", rule)).toEqual({ 'Root: must look like 12, got "x"' })
	end)

	it("shows a table as its type, not an address", function()
		expect(check({}, Validate.string())).toEqual({ "Root: must be text, got a table" })
		expect(check("yes", Validate.boolean())).toEqual({ 'Root: must be true or false, got "yes"' })
	end)
end)

describe("Validate.record", function()
	local rule = Validate.record({
		b = Validate.number(),
		a = Validate.optional(Validate.boolean()),
	})

	it("checks each field with its full path, in sorted order", function()
		expect(check({ b = "x", a = 1 }, rule)).toEqual({
			"Root.a: must be true or false, got 1",
			'Root.b: must be a number, got "x"',
		})
	end)

	it("reports a missing required field and allows a missing optional one", function()
		expect(check({}, rule)).toEqual({ "Root.b: must be a number, got nil" })
	end)

	it("reports a misspelled field", function()
		expect(check({ b = 1, bb = 2 }, rule)).toEqual({ "Root.bb: is not a known field (check the spelling), got 2" })
	end)

	it("starts paths at the field name when the root is empty", function()
		expect(Validate.run({ b = false }, rule, "")).toEqual({ "b: must be a number, got false" })
		expect(Validate.run(5, rule, "")).toEqual({ "(root): must be a table, got 5" })
	end)
end)

describe("Validate.map", function()
	it("checks every key and value", function()
		local rule = Validate.map(Validate.string({ pattern = "^%u" }), Validate.boolean())
		expect(check({ On = true }, rule)).toEqual({})
		expect(check({ off = 3 }, rule)).toEqual({
			'Root.off (name): must look like ^%u, got "off"',
			"Root.off: must be true or false, got 3",
		})
	end)
end)

describe("Validate.registry", function()
	it("requires each entry's id to match its file name", function()
		local rule = Validate.registry(nil)
		expect(check({ CoalDropper = { id = "CoalDropper" } }, rule)).toEqual({})
		expect(check({ CoalDropper = { id = "Coal" }, Belt = 4 }, rule)).toEqual({
			"Root.Belt: must be a table, got 4",
			'Root.CoalDropper.id: must match the file name "CoalDropper", got "Coal"',
		})
	end)

	it("applies the entry rule to each entry", function()
		local rule =
			Validate.registry(Validate.record({ id = Validate.string(), price = Validate.number({ min = 0 }) }))
		expect(check({ A = { id = "A", price = -5 } }, rule)).toEqual({ "Root.A.price: must be at least 0, got -5" })
	end)
end)
