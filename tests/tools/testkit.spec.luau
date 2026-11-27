--!strict
-- Specs for the test framework itself: every matcher passes when it should and fails with a readable message when it
-- should not. Also the sample spec that shows the format for later specs.

local testkit = require("../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

describe("testkit.expect", function()
	it("toBe compares with ==", function()
		expect(2 + 2).toBe(4)
		expect(function()
			expect(5).toBe(4)
		end).toThrow("expected 4, got 5")
	end)

	it("toEqual compares tables deeply", function()
		expect({ a = 1, b = { 2, 3 } }).toEqual({ a = 1, b = { 2, 3 } })
		expect(function()
			expect({ a = 1, b = { 2, 4 } }).toEqual({ a = 1, b = { 2, 3 } })
		end).toThrow("value.b.2: expected 3, got 4")
		expect(function()
			expect({ a = 1, extra = true }).toEqual({ a = 1 })
		end).toThrow("unexpected value")
	end)

	it("toEqual treats NaN as equal to NaN", function()
		expect(0 / 0).toEqual(0 / 0)
	end)

	it("toBeCloseTo allows a tolerance", function()
		expect(0.1 + 0.2).toBeCloseTo(0.3)
		expect(1.05).toBeCloseTo(1, 0.1)
		expect(function()
			expect(1.5).toBeCloseTo(1, 0.1)
		end).toThrow("within")
	end)

	it("toBeNil and toBeTruthy", function()
		expect(nil).toBeNil()
		expect(0).toBeTruthy()
		expect(function()
			expect(false).toBeTruthy()
		end).toThrow("truthy")
	end)

	it("toThrow checks the message fragment as plain text", function()
		expect(function()
			error("cost (100) too high")
		end).toThrow("(100)")
		expect(function()
			expect(function() end).toThrow()
		end).toThrow("none was raised")
	end)

	it("never inverts a matcher", function()
		expect(1).never.toBe(2)
		expect({ 1 }).never.toEqual({ 2 })
		expect(false).never.toBeNil()
		expect(function()
			expect(1).never.toBe(1)
		end).toThrow("other than 1")
	end)
end)
