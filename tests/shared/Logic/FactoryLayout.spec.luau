--!strict
-- Specs for FactoryLayout: machines sit on the belt, pads have the right shape and reach, and a factory that does not
-- fit the plot is reported in plain words.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Config = require("../../../src/shared/Config")
local FactoryLayout = require("../../../src/shared/Logic/FactoryLayout")
local Purchase = require("../../../src/shared/Logic/Purchase")

local factory = Config.Factory

local function def(id: string, kind: string, params: { [string]: number }, x: number, z: number): any
	return {
		id = id,
		kind = kind,
		tier = 1,
		price = 0,
		requires = {},
		line = "Main",
		params = params,
		pad = {
			x = x,
			z = z,
		},
	}
end

describe("FactoryLayout", function()
	it("puts a point on the belt's top surface", function()
		local x, y, z = FactoryLayout.beltPoint(factory, 10)
		expect(x).toBe(factory.line.start.x + 10)
		expect(y).toBe(factory.line.height)
		expect(z).toBe(factory.line.start.z)
	end)

	it("gives every kind a shape, centred on the line where it sits", function()
		local belt = FactoryLayout.boxes(def("Belt", "Conveyor", { speed = 8 }, 0, 0), factory)
		expect(#belt).toBe(1)
		expect(belt[1].sx).toBe(factory.line.length)
		local dropper =
			FactoryLayout.boxes(def("Coal", "Dropper", { itemValue = 1, interval = 1, at = 20 }, 0, 0), factory)
		expect(#dropper).toBe(2)
		expect(dropper[1].x).toBe(factory.line.start.x + 20)
		expect(dropper[1].y > factory.line.height).toBe(true)
		expect(#FactoryLayout.boxes(def("Wash", "Upgrader", { multiplier = 2, at = 50 }, 0, 0), factory)).toBe(3)
		local bin = FactoryLayout.boxes(def("Bin", "Collector", { multiplier = 1 }, 0, 0), factory)
		expect(bin[1].x).toBe(factory.line.start.x + factory.line.length + factory.collectorSize / 2)
		expect(#FactoryLayout.boxes(def("Odd", "Furnace", {}, 0, 0), factory)).toBe(0)
	end)

	it("lets a character buy from just past a pad's corner, not further", function()
		local radius = FactoryLayout.padRadius(factory)
		expect(radius).toBeCloseTo(factory.padSize * math.sqrt(2) / 2 + factory.padReach, 1e-9)
		local pad = FactoryLayout.pad(def("Coal", "Dropper", {}, 12, -8), factory)
		expect(pad.x).toBe(12)
		expect(pad.z).toBe(-8)
		expect(pad.sx).toBe(factory.padSize)
	end)

	it("finds no problem with the real config", function()
		local ids = Purchase.sortedIds(Config.Buildables)
		expect(FactoryLayout.problems(factory, Config.Plots, Config.Buildables, ids)).toEqual({})
	end)

	it("reports pads off the plot, on the spawn, on the line or on each other, and machines off the belt", function()
		local defs = {
			A = def("A", "Dropper", { at = 500 }, 100, 0),
			B = def("B", "Conveyor", {}, 0, -64),
			C = def("C", "Conveyor", {}, 0, factory.line.start.z),
			D = def("D", "Conveyor", {}, -30, -30),
			E = def("E", "Conveyor", {}, -28, -30),
		}
		expect(FactoryLayout.problems(factory, Config.Plots, defs, { "A", "B", "C", "D", "E" })).toEqual({
			`Buildables.A.params.at: must be on the belt, below {factory.line.length}, got 500`,
			"Buildables.A.pad: the pad must be on the plot",
			"Buildables.B.pad: the pad overlaps the spawn pad",
			"Buildables.C.pad: the pad overlaps the production line",
			"Buildables.D.pad: the pad overlaps the pad of E",
		})
	end)
end)
