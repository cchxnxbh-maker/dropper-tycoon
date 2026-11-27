--!strict
-- Specs for Freeze: every nested table is frozen, values pass through, and self-references do not loop.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Freeze = require("../../../src/shared/Util/Freeze")

describe("Freeze.deep", function()
	it("freezes nested tables so writes throw", function()
		local data: any = Freeze.deep({ Timing = { simRate = 10 }, list = { { 1 } } })
		expect(table.isfrozen(data)).toBe(true)
		expect(table.isfrozen(data.Timing)).toBe(true)
		expect(table.isfrozen(data.list[1])).toBe(true)
		expect(function()
			data.Timing.simRate = 20
		end).toThrow("readonly")
	end)

	it("returns non-tables unchanged", function()
		expect(Freeze.deep(5)).toBe(5)
		expect(Freeze.deep("text")).toBe("text")
	end)

	it("stops on a table that contains itself", function()
		local loop: any = {}
		loop.self = loop
		expect(Freeze.deep(loop)).toBe(loop)
		expect(table.isfrozen(loop)).toBe(true)
	end)
end)
