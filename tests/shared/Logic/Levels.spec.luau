--!strict
-- Specs for Levels: what each level costs, where levels stop, and how a level changes what a machine makes.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local FactorySim = require("../../../src/shared/Logic/FactorySim")
local Levels = require("../../../src/shared/Logic/Levels")

local rules = { maxLevel = 4, priceGrowth = 1.5 }

local function def(id: string, kind: string, params: { [string]: number }, levelPrice: number?): any
	return {
		id = id,
		kind = kind,
		tier = 1,
		price = 0,
		requires = {},
		line = "Main",
		params = params,
		pad = { x = 0, z = 0 },
		levelPrice = levelPrice,
	}
end

local buildables = {
	Belt = def("Belt", "Conveyor", { speed = 10 }),
	Bin = def("Bin", "Collector", { multiplier = 1, perLevel = 0.5 }, 10),
	Coal = def("Coal", "Dropper", { itemValue = 2, interval = 1, at = 0, perLevel = 0.5 }, 10),
	Wash = def("Wash", "Upgrader", { multiplier = 2, at = 5, perLevel = 1 }, 10),
}

describe("Levels", function()
	it("treats a machine with no saved level as level 1", function()
		expect(Levels.of({}, "Coal")).toBe(1)
		expect(Levels.of({ Coal = 3 }, "Coal")).toBe(3)
	end)

	it("prices level 2 at levelPrice and each next level by priceGrowth, rounded", function()
		expect(Levels.price(buildables.Coal, 1, rules)).toBe(10)
		expect(Levels.price(buildables.Coal, 2, rules)).toBe(15)
		expect(Levels.price(buildables.Coal, 3, rules)).toBe(23)
	end)

	it("sells nothing at the top level or for a machine with no levels", function()
		expect(Levels.price(buildables.Coal, 4, rules)).toBeNil()
		expect(Levels.price(buildables.Belt, 1, rules)).toBeNil()
	end)

	it("fills in each owned machine's level for the simulation", function()
		local defs = Levels.defs(buildables, { "Belt", "Coal", "Gone" }, { Coal = 3 })
		expect(#defs).toBe(2)
		expect(defs[1].level).toBe(1)
		expect(defs[2].level).toBe(3)
	end)

	it("raises dropper value, upgrader and collector multipliers by perLevel for each level above 1", function()
		local ids = { "Belt", "Bin", "Coal", "Wash" }
		local function rate(levels: { [string]: number }): number
			local defs: { any } = Levels.defs(buildables, ids, levels)
			return FactorySim.incomeRate(FactorySim.new(defs, { length = 100, rate = 10, tick = 0, starts = nil }))
		end
		-- Base: 2 a second, times 2 under the arch, times 1 at the bin.
		expect(rate({})).toBeCloseTo(4, 1e-9)
		-- Coal level 3: 2 * (1 + 0.5 * 2) = 4 per item.
		expect(rate({ Coal = 3 })).toBeCloseTo(8, 1e-9)
		-- Wash level 2: multiplier 3.
		expect(rate({ Wash = 2 })).toBeCloseTo(6, 1e-9)
		-- Bin level 3: multiplier 2.
		expect(rate({ Bin = 3 })).toBeCloseTo(8, 1e-9)
	end)
end)
