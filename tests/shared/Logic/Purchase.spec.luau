--!strict
-- Specs for Purchase: which pads show, and the order of the reasons a purchase is refused.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Purchase = require("../../../src/shared/Logic/Purchase")

local function def(id: string, price: number, requires: { string }): any
	return {
		id = id,
		kind = "Dropper",
		tier = 1,
		price = price,
		requires = requires,
		line = "Main",
		params = {},
		pad = {
			x = 0,
			z = 0,
		},
	}
end

local defs = {
	Belt = def("Belt", 0, {}),
	Bin = def("Bin", 0, { "Belt" }),
	Coal = def("Coal", 30, { "Bin" }),
	Wash = def("Wash", 100, { "Bin", "Coal" }),
}
local ids = Purchase.sortedIds(defs)

local function request(id: string, owned: { [string]: boolean }, cash: number, distance: number?): Purchase.Request
	return { id = id, owned = owned, cash = cash, buildables = defs, distance = distance or 0, radius = 10 }
end

describe("Purchase", function()
	it("sorts the registry's IDs", function()
		expect(ids).toEqual({ "Belt", "Bin", "Coal", "Wash" })
	end)

	it("shows only pads whose requirements are all owned", function()
		expect(Purchase.available({}, defs, ids)).toEqual({ "Belt" })
		expect(Purchase.available({ Belt = true, Bin = true }, defs, ids)).toEqual({ "Coal" })
		expect(Purchase.available({ Belt = true, Bin = true, Coal = true }, defs, ids)).toEqual({ "Wash" })
		expect(Purchase.available({ Belt = true, Bin = true, Coal = true, Wash = true }, defs, ids)).toEqual({})
	end)

	it("allows a purchase that passes every rule", function()
		expect(Purchase.check(request("Coal", { Belt = true, Bin = true }, 30, 10))).toBeNil()
		expect(Purchase.check(request("Belt", {}, 0))).toBeNil()
	end)

	it("gives the first reason that fails, in order", function()
		expect(Purchase.check(request("Gold", {}, 1e9))).toBe("unknown")
		expect(Purchase.check(request("Belt", { Belt = true }, 1e9))).toBe("owned")
		expect(Purchase.check(request("Coal", { Belt = true }, 1e9))).toBe("locked")
		expect(Purchase.check(request("Coal", { Belt = true, Bin = true }, 0, 11))).toBe("tooFar")
		expect(Purchase.check(request("Coal", { Belt = true, Bin = true }, 29.9))).toBe("notEnoughCash")
	end)
end)
