--!strict
-- Specs for Text.format: gaps are filled, whole numbers print without a decimal point, and unknown gaps stay visible.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Config = require("../../../src/shared/Config")
local Text = require("../../../src/shared/Util/Text")

describe("Text.format", function()
	it("fills a named gap", function()
		expect(Text.format("{name}'s factory", { name = "Daniel" })).toBe("Daniel's factory")
	end)

	it("writes whole numbers without a decimal point and keeps fractions", function()
		expect(Text.format("Plot {number}", { number = 3 })).toBe("Plot 3")
		expect(Text.format("{x}", { x = 2.5 })).toBe("2.5")
	end)

	it("fills every gap, the same one more than once", function()
		expect(Text.format("{a} and {b} and {a}", { a = "x", b = "y" })).toBe("x and y and x")
	end)

	it("leaves a gap with no value as it is", function()
		expect(Text.format("Hello {who}", {})).toBe("Hello {who}")
	end)

	it("fills the real sign and panel strings", function()
		expect(Text.format(Config.Strings.Plot.number, { number = 6 })).toBe("Plot 6")
		expect(Text.format(Config.Strings.DevPanel.counter, { value = 0 })).toBe("Test counter: 0")
	end)
end)
