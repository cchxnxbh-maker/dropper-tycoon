--!strict
-- Specs for FactorySim: items arrive when the formula says, upgraders and the collector multiply, the income rate is
-- the exact average of what steps pay, a rebuild keeps items on the belt, skipped time is paid by formula, results do
-- not depend on the order machines are listed, and the drawn items sit where the cash says they are.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local FactorySim = require("../../../src/shared/Logic/FactorySim")

local RATE = 10
local LENGTH = 90

local conveyor = { id = "Belt", kind = "Conveyor", params = { speed = 9 } }
local collector = { id = "Bin", kind = "Collector", params = { multiplier = 1 } }
-- Drops every 2 seconds (20 steps) at 0 studs; travels 90 studs at 9 a second, so 100 steps.
local coal = { id = "Coal", kind = "Dropper", params = { itemValue = 2, interval = 2, at = 0 } }
local washer = { id = "Washer", kind = "Upgrader", params = { multiplier = 1.5, at = 45 } }

local function options(tick: number?, starts: { [string]: number }?): FactorySim.Options
	return { length = LENGTH, rate = RATE, tick = tick or 0, starts = starts }
end

local function run(sim: FactorySim.Sim, steps: number): { number }
	local paid = {}
	for _ = 1, steps do
		local earned = FactorySim.step(sim)
		if earned > 0 then
			table.insert(paid, sim.tick)
		end
	end
	return paid
end

describe("FactorySim", function()
	it("pays nothing without a conveyor or without a collector", function()
		local noBelt = FactorySim.new({ collector, coal }, options())
		local noBin = FactorySim.new({ conveyor, coal }, options())
		expect(#run(noBelt, 300)).toBe(0)
		expect(#run(noBin, 300)).toBe(0)
		expect(FactorySim.incomeRate(noBin)).toBe(0)
	end)

	it("pays each item when it reaches the collector, one interval apart", function()
		local sim = FactorySim.new({ conveyor, collector, coal }, options())
		-- Dropped at step 0, 20, 40...; each travels 100 steps.
		expect(run(sim, 160)).toEqual({ 100, 120, 140, 160 })
	end)

	it("multiplies only items dropped before an upgrader, and by the collector", function()
		local late = { id = "Late", kind = "Dropper", params = { itemValue = 10, interval = 2, at = 60 } }
		local bin = { id = "Bin", kind = "Collector", params = { multiplier = 2 } }
		local sim = FactorySim.new({ conveyor, bin, coal, late, washer }, options())
		local byId = {}
		for _, dropper in sim.droppers do
			byId[dropper.id] = dropper.value
		end
		expect(byId.Coal).toBe(2 * 1.5 * 2)
		expect(byId.Late).toBe(10 * 2)
	end)

	it("has an income rate equal to what the steps pay on average", function()
		local copper = { id = "Copper", kind = "Dropper", params = { itemValue = 5, interval = 2.5, at = 30 } }
		local sim = FactorySim.new({ conveyor, collector, coal, copper, washer }, options())
		local total = 0
		for _ = 1, 100 do
			FactorySim.step(sim)
		end
		-- After the belt fills, 100 seconds (a whole number of both intervals) pay exactly rate times 100.
		for _ = 1, 1000 do
			total += FactorySim.step(sim)
		end
		expect(total).toBeCloseTo(FactorySim.incomeRate(sim) * 100, 1e-9)
		expect(FactorySim.incomeRate(sim)).toBeCloseTo(2 * 1.5 / 2 + 5 * 1.5 / 2.5, 1e-9)
	end)

	it("gives the same results whatever order the machines are listed in", function()
		local a = FactorySim.new({ conveyor, collector, coal, washer }, options())
		local b = FactorySim.new({ washer, coal, collector, conveyor }, options())
		expect(run(a, 400)).toEqual(run(b, 400))
		expect(FactorySim.incomeRate(a)).toBe(FactorySim.incomeRate(b))
	end)

	it("starts a new dropper from the step it joined, and keeps the earlier ones after a rebuild", function()
		local first = FactorySim.new({ conveyor, collector, coal }, options())
		run(first, 50)
		-- Items dropped at 0, 20 and 40 are on the belt. A new dropper joins at step 50.
		local copper = { id = "Copper", kind = "Dropper", params = { itemValue = 5, interval = 2, at = 0 } }
		local rebuilt =
			FactorySim.new({ conveyor, collector, coal, copper }, options(first.tick, FactorySim.starts(first)))
		expect(FactorySim.starts(rebuilt)).toEqual({ Coal = 0, Copper = 50 })
		local coalPaid, copperPaid = 0, 0
		for _ = 1, 110 do
			FactorySim.step(rebuilt)
			local dropped = rebuilt.tick - rebuilt.droppers[1].travelTicks
			if dropped >= 0 and dropped % 20 == 0 then
				coalPaid += 1
			end
			if dropped >= 50 and dropped % 20 == 0 then
				copperPaid += 1
			end
		end
		-- Coal's items from steps 0, 20, 40 and 60 arrive by step 160; Copper's first drop is at step 60.
		expect(coalPaid).toBe(4)
		expect(copperPaid).toBe(1)
	end)

	it("forgets start steps when the line stops, and starts afresh when it runs again", function()
		local stopped = FactorySim.new({ conveyor, coal }, options(30))
		expect(FactorySim.starts(stopped)).toEqual({})
		local running = FactorySim.new({ conveyor, collector, coal }, options(30, FactorySim.starts(stopped)))
		expect(FactorySim.starts(running)).toEqual({ Coal = 30 })
		-- The first drop at or after step 30 on a 20-step interval is step 40; it arrives at 140.
		expect(run(running, 120)[1]).toBe(140)
	end)

	it("pays skipped time by the income rate and carries fractions of a step", function()
		local sim = FactorySim.new({ conveyor, collector, coal }, options())
		expect(FactorySim.skip(sim, 0.25)).toBeCloseTo(FactorySim.incomeRate(sim) * 0.2, 1e-9)
		expect(sim.tick).toBe(2)
		-- The 0.05 seconds left over joins the next skip: 0.3 seconds is three whole steps.
		expect(FactorySim.skip(sim, 0.25)).toBeCloseTo(FactorySim.incomeRate(sim) * 0.3, 1e-9)
		expect(sim.tick).toBe(5)
		local stopped = FactorySim.new({ coal }, options())
		expect(FactorySim.skip(stopped, 10)).toBe(0)
	end)

	it("draws items between the dropper and the collector, matching the steps that pay", function()
		local sim = FactorySim.new({ conveyor, collector, coal }, options())
		local out = {}
		-- At step 50, items dropped at 0, 20 and 40 are 45, 27 and 9 studs along.
		expect(FactorySim.itemsAt(sim, 50, out, 40)).toBe(3)
		expect(out[1]).toBeCloseTo(9, 1e-9)
		expect(out[2]).toBeCloseTo(27, 1e-9)
		expect(out[3]).toBeCloseTo(45, 1e-9)
		-- At step 100 the first item arrives and is paid, so it is no longer drawn; a new one has just dropped.
		expect(FactorySim.itemsAt(sim, 100, out, 40)).toBe(5)
		expect(out[1]).toBeCloseTo(0, 1e-9)
		expect(out[5]).toBeCloseTo(72, 1e-9)
		expect(FactorySim.itemsAt(sim, 50, out, 2)).toBe(2)
	end)

	it("draws nothing before a dropper's start or on a stopped line", function()
		local sim = FactorySim.new({ conveyor, collector, coal }, options(35))
		local out = {}
		expect(FactorySim.itemsAt(sim, 39, out, 40)).toBe(0)
		expect(FactorySim.itemsAt(sim, 41, out, 40)).toBe(1)
		local stopped = FactorySim.new({ conveyor, coal }, options())
		expect(FactorySim.itemsAt(stopped, 50, out, 40)).toBe(0)
	end)

	it("rejects a machine whose kind has no file", function()
		expect(function()
			FactorySim.new({ { id = "Odd", kind = "Furnace", params = {} } }, options())
		end).toThrow("no kind file")
	end)
end)
