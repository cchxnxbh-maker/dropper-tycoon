--!strict
-- Specs for Purchase: what each pad sells (a machine, then its levels), and the order of the reasons a purchase is
-- refused.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Purchase = require("../../../src/shared/Logic/Purchase")

local function def(id: string, price: number, requires: { string }, levelPrice: number?): any
	return {
		levelPrice = levelPrice,
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
	Coal = def("Coal", 30, { "Bin" }, 10),
	Wash = def("Wash", 100, { "Bin", "Coal" }),
}
local ids = Purchase.sortedIds(defs)
local rules = { maxLevel = 3, priceGrowth = 2 }

local function request(
	id: string,
	owned: { [string]: boolean },
	cash: number,
	distance: number?,
	levels: { [string]: number }?
): Purchase.Request
	return {
		id = id,
		owned = owned,
		levels = levels or {},
		cash = cash,
		buildables = defs,
		rules = rules,
		distance = distance or 0,
		radius = 10,
	}
end

local function offered(owned: { [string]: boolean }, levels: { [string]: number }): { string }
	local list: { string } = {}
	for _, offer in Purchase.offers(owned, levels, defs, ids, rules) do
		table.insert(list, `{offer.id}:{offer.level}:{offer.price}`)
	end
	return list
end

describe("Purchase", function()
	it("sorts the registry's IDs", function()
		expect(ids).toEqual({ "Belt", "Bin", "Coal", "Wash" })
	end)

	it("shows pads whose requirements are all owned, then a level pad for an owned machine with levels", function()
		expect(offered({}, {})).toEqual({ "Belt:1:0" })
		expect(offered({ Belt = true, Bin = true }, {})).toEqual({ "Coal:1:30" })
		expect(offered({ Belt = true, Bin = true, Coal = true }, {})).toEqual({ "Coal:2:10", "Wash:1:100" })
		expect(offered({ Belt = true, Bin = true, Coal = true }, { Coal = 2 })).toEqual({ "Coal:3:20", "Wash:1:100" })
		expect(offered({ Belt = true, Bin = true, Coal = true, Wash = true }, { Coal = 3 })).toEqual({})
	end)

	it("allows a level that passes every rule", function()
		local owned = { Belt = true, Bin = true, Coal = true }
		expect(Purchase.check(request("Coal", owned, 10))).toBeNil()
		expect(Purchase.check(request("Coal", owned, 20, 0, { Coal = 2 }))).toBeNil()
		expect(Purchase.check(request("Coal", owned, 19, 0, { Coal = 2 }))).toBe("notEnoughCash")
		expect(Purchase.check(request("Coal", owned, 1e9, 11))).toBe("tooFar")
		expect(Purchase.check(request("Coal", owned, 1e9, 0, { Coal = 3 }))).toBe("maxLevel")
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
