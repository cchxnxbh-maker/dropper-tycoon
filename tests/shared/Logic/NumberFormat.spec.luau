--!strict
-- Specs for NumberFormat: whole numbers with commas, then three digits and a suffix, never rounded up.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local NumberFormat = require("../../../src/shared/Logic/NumberFormat")

describe("NumberFormat.cash", function()
	it("writes small amounts as whole numbers with commas", function()
		expect(NumberFormat.cash(0)).toBe("0")
		expect(NumberFormat.cash(7.9)).toBe("7")
		expect(NumberFormat.cash(999)).toBe("999")
		expect(NumberFormat.cash(1234)).toBe("1,234")
		expect(NumberFormat.cash(9999)).toBe("9,999")
	end)

	it("writes big amounts with three digits and a suffix", function()
		expect(NumberFormat.cash(10000)).toBe("10.0K")
		expect(NumberFormat.cash(15234)).toBe("15.2K")
		expect(NumberFormat.cash(999999)).toBe("999K")
		expect(NumberFormat.cash(4560000)).toBe("4.56M")
		expect(NumberFormat.cash(1e15)).toBe("1.00Q")
	end)

	it("treats negatives and NaN as zero", function()
		expect(NumberFormat.cash(-5)).toBe("0")
		expect(NumberFormat.cash(0 / 0)).toBe("0")
	end)
end)

describe("NumberFormat.rate", function()
	it("keeps one decimal for small rates and drops a zero one", function()
		expect(NumberFormat.rate(0)).toBe("0")
		expect(NumberFormat.rate(2.5)).toBe("2.5")
		expect(NumberFormat.rate(3)).toBe("3")
		expect(NumberFormat.rate(4.35)).toBe("4.3")
		expect(NumberFormat.rate(99.96)).toBe("99.9")
	end)

	it("writes big rates like cash", function()
		expect(NumberFormat.rate(150.7)).toBe("150")
		expect(NumberFormat.rate(25000)).toBe("25.0K")
		expect(NumberFormat.rate(-1)).toBe("0")
	end)
end)
