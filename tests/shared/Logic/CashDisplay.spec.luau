--!strict
-- Specs for CashDisplay: the first value shows at once, small gaps ease over the ease time, big gaps snap.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local CashDisplay = require("../../../src/shared/Logic/CashDisplay")

describe("CashDisplay", function()
	it("shows the first target at once", function()
		local counter = CashDisplay.new()
		expect(CashDisplay.update(counter, 500, 0.1, 0.01, 0.3)).toBe(500)
	end)

	it("eases a gap under the share over the ease time", function()
		local counter = CashDisplay.new()
		CashDisplay.update(counter, 1000, 0.1, 0.01, 0.3)
		-- 1006 is 0.6% away: a third of the gap closes in 0.1 of 0.3 seconds, all of it by 0.3.
		expect(CashDisplay.update(counter, 1006, 0.1, 0.01, 0.3)).toBeCloseTo(1002, 1e-9)
		expect(CashDisplay.update(counter, 1006, 0.3, 0.01, 0.3)).toBeCloseTo(1006, 1e-9)
	end)

	it("snaps a bigger gap, such as a purchase", function()
		local counter = CashDisplay.new()
		CashDisplay.update(counter, 1000, 0.1, 0.01, 0.3)
		expect(CashDisplay.update(counter, 970, 0.1, 0.01, 0.3)).toBe(970)
		-- Near zero the share is taken of 1, so the first cash after nothing still snaps cleanly.
		local small = CashDisplay.new()
		CashDisplay.update(small, 0, 0.1, 0.01, 0.3)
		expect(CashDisplay.update(small, 2, 0.1, 0.01, 0.3)).toBe(2)
	end)
end)
