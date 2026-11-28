--!strict
-- Specs for PlotSlots: lowest free plot first, one plot per player, a full server says so, and released plots are
-- given out again.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local PlotSlots = require("../../../src/shared/Logic/PlotSlots")

describe("PlotSlots", function()
	it("gives plots out lowest first", function()
		local slots = PlotSlots.new(6)
		expect(slots.claim(101)).toBe(1)
		expect(slots.claim(102)).toBe(2)
		expect(slots.claim(103)).toBe(3)
		expect(slots.freeCount()).toBe(3)
	end)

	it("gives a player who claims again the plot they already hold", function()
		local slots = PlotSlots.new(6)
		slots.claim(101)
		expect(slots.claim(102)).toBe(2)
		expect(slots.claim(102)).toBe(2)
		expect(slots.freeCount()).toBe(4)
	end)

	it("says nil when every plot is taken", function()
		local slots = PlotSlots.new(6)
		for key = 1, 6 do
			expect(slots.claim(key)).toBe(key)
		end
		expect(slots.claim(7)).toBeNil()
		expect(slots.freeCount()).toBe(0)
	end)

	it("frees a released plot and gives it to the next player", function()
		local slots = PlotSlots.new(6)
		for key = 1, 6 do
			slots.claim(key)
		end
		expect(slots.release(3)).toBe(3)
		expect(slots.holderOf(3)).toBeNil()
		expect(slots.claim(99)).toBe(3)
		expect(slots.holderOf(3)).toBe(99)
	end)

	it("fills the lowest gap first", function()
		local slots = PlotSlots.new(6)
		for key = 1, 4 do
			slots.claim(key)
		end
		slots.release(4)
		slots.release(2)
		expect(slots.claim(50)).toBe(2)
		expect(slots.claim(51)).toBe(4)
	end)

	it("ignores releasing a player with no plot", function()
		local slots = PlotSlots.new(6)
		expect(slots.release(5)).toBeNil()
		expect(slots.freeCount()).toBe(6)
	end)

	it("knows who holds what", function()
		local slots = PlotSlots.new(6)
		slots.claim(7)
		expect(slots.indexOf(7)).toBe(1)
		expect(slots.indexOf(8)).toBeNil()
		expect(slots.holderOf(1)).toBe(7)
	end)

	it("refuses a count below 1", function()
		expect(function()
			PlotSlots.new(0)
		end).toThrow("at least 1")
	end)
end)
