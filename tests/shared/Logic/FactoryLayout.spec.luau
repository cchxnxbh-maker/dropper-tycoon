--!strict
-- Specs for FactoryLayout: the belt follows its winding path, machines sit on it facing the right way, pads have the
-- right shape and reach, and a factory that does not fit the plot is reported in plain words.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Config = require("../../../src/shared/Config")
local FactoryLayout = require("../../../src/shared/Logic/FactoryLayout")
local Purchase = require("../../../src/shared/Logic/Purchase")

local factory = Config.Factory

-- A small line with one bend: 20 studs along +x, then 10 along +z.
local bent: any = table.clone(Config.Factory)
bent.line = { path = { { x = 0, z = 0 }, { x = 20, z = 0 }, { x = 20, z = 10 } }, height = 3, width = 4 }

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
	it("measures the line along every run of its path", function()
		expect(FactoryLayout.length(bent)).toBe(30)
		expect(FactoryLayout.length(factory)).toBe(420)
	end)

	it("puts a point on the belt's top surface and says which way the belt runs there", function()
		local x, y, z, dx, dz = FactoryLayout.beltPoint(bent, 5)
		expect({ x, y, z, dx, dz }).toEqual({ 5, 3, 0, 1, 0 })
		x, y, z, dx, dz = FactoryLayout.beltPoint(bent, 25)
		expect({ x, y, z, dx, dz }).toEqual({ 20, 3, 5, 0, 1 })
		local endX, _, endZ = FactoryLayout.beltPoint(bent, 99)
		expect({ endX, endZ }).toEqual({ 20, 10 })
		local startX, _, startZ = FactoryLayout.beltPoint(bent, -5)
		expect({ startX, startZ }).toEqual({ 0, 0 })
	end)

	it("draws one belt box per run, filling each bend exactly once", function()
		local belt = FactoryLayout.boxes(def("Belt", "Conveyor", { speed = 8 }, 0, 0), bent)
		expect(#belt).toBe(2)
		-- The first run reaches half a belt past the bend; the second starts half a belt after it.
		expect({ belt[1].x, belt[1].z, belt[1].sx, belt[1].sz }).toEqual({ 11, 0, 22, 4 })
		expect({ belt[2].x, belt[2].z, belt[2].sx, belt[2].sz }).toEqual({ 20, 6, 4, 8 })
	end)

	it("gives every kind a shape, centred on the line where it sits and turned with the belt", function()
		local dropper = FactoryLayout.boxes(
			def("Coal", "Dropper", { itemValue = 1, interval = 1, at = 25, perLevel = 0 }, 0, 0),
			bent
		)
		expect(#dropper).toBe(2)
		expect({ dropper[1].x, dropper[1].z }).toEqual({ 20, 5 })
		expect(dropper[1].y > bent.line.height).toBe(true)
		-- Beside the belt on its right: on a run along +z the post moves along +x.
		expect(dropper[2].x > 20 and dropper[2].z == 5).toBe(true)
		local arch = FactoryLayout.boxes(def("Wash", "Upgrader", { multiplier = 2, at = 25, perLevel = 0 }, 0, 0), bent)
		expect(#arch).toBe(3)
		expect(arch[3].sx > arch[3].sz).toBe(true)
		local straight =
			FactoryLayout.boxes(def("Wash", "Upgrader", { multiplier = 2, at = 5, perLevel = 0 }, 0, 0), bent)
		expect(straight[3].sz > straight[3].sx).toBe(true)
		local bin = FactoryLayout.boxes(def("Bin", "Collector", { multiplier = 1, perLevel = 0 }, 0, 0), bent)
		expect({ bin[1].x, bin[1].z }).toEqual({ 20, 10 + bent.collectorSize / 2 })
		expect(#FactoryLayout.boxes(def("Odd", "Furnace", {}, 0, 0), bent)).toBe(0)
	end)

	it("puts a belt machine's pad beside it on the belt's left, and others where their config says", function()
		local offset = bent.line.width / 2 + bent.padGap + bent.padSize / 2
		local along = FactoryLayout.padPoint(def("Coal", "Dropper", { at = 5 }, 99, 99), bent)
		expect(along).toEqual({ x = 5, z = offset })
		local up = FactoryLayout.padPoint(def("Coal", "Dropper", { at = 25 }, 99, 99), bent)
		expect(up).toEqual({ x = 20 - offset, z = 5 })
		expect(FactoryLayout.padPoint(def("Belt", "Conveyor", { speed = 8 }, 12, -8), bent)).toEqual({ x = 12, z = -8 })
	end)

	it("lets a character buy from just past a pad's corner, not further", function()
		local radius = FactoryLayout.padRadius(factory)
		expect(radius).toBeCloseTo(factory.padSize * math.sqrt(2) / 2 + factory.padReach, 1e-9)
		local pad = FactoryLayout.pad(def("Coal", "Dropper", {}, 12, -8), factory)
		expect(pad.x).toBe(12)
		expect(pad.z).toBe(-8)
		expect(pad.sx).toBe(factory.padSize)
	end)

	it("ranks conveyors by speed and collectors by multiplier, and nothing else", function()
		expect(FactoryLayout.rank(def("Fast", "Conveyor", { speed = 14 }, 0, 0))).toBe(14)
		expect(FactoryLayout.rank(def("Big", "Collector", { multiplier = 1.5 }, 0, 0))).toBe(1.5)
		expect(FactoryLayout.rank(def("Coal", "Dropper", { at = 5 }, 0, 0))).toBeNil()
	end)

	it("finds no problem with the real config", function()
		local ids = Purchase.sortedIds(Config.Buildables)
		expect(FactoryLayout.problems(factory, Config.Plots, Config.Buildables, ids)).toEqual({})
	end)

	it("reports pads off the plot, on the spawn, on the line or on each other, and machines off the belt", function()
		local missing = def("G", "Conveyor", {}, 0, 0)
		missing.pad = nil
		local defs = {
			A = def("A", "Dropper", { at = 500 }, 0, 0),
			B = def("B", "Conveyor", {}, 0, -64),
			C = def("C", "Conveyor", {}, 0, factory.line.path[1].z),
			D = def("D", "Conveyor", {}, -30, -30),
			E = def("E", "Conveyor", {}, -28, -30),
			F = def("F", "Conveyor", {}, 100, -30),
			G = missing,
		}
		expect(FactoryLayout.problems(factory, Config.Plots, defs, { "A", "B", "C", "D", "E", "F", "G" })).toEqual({
			"Buildables.A.params.at: must be on the belt, below 420, got 500",
			"Buildables.G.pad: missing; a machine that is not on the belt needs a pad position",
			"Buildables.B.pad: the pad overlaps the spawn pad",
			"Buildables.C.pad: the pad overlaps the production line",
			"Buildables.D.pad: the pad overlaps the pad of E",
			"Buildables.F.pad: the pad must be on the plot",
		})
	end)

	it("reports machines on a bend or on top of each other, and so their pads", function()
		local defs = {
			A = def("A", "Dropper", { at = 118 }, -56, -36),
			B = def("B", "Upgrader", { at = 50 }, -40, -36),
			C = def("C", "Dropper", { at = 51 }, -24, -36),
		}
		expect(FactoryLayout.problems(factory, Config.Plots, defs, { "A", "B", "C" })).toEqual({
			"Buildables.A.params.at: too close to the bend at 120",
			"Buildables.C.params.at: too close to B on the belt",
			"Buildables.A.pad: the pad overlaps the production line",
			"Buildables.B.pad: the pad overlaps the pad of C",
		})
	end)

	it("reports a path that does not run straight or leaves the plot", function()
		local diagonal: any = table.clone(Config.Factory)
		diagonal.line = { path = { { x = 0, z = 0 }, { x = 10, z = 10 } }, height = 3, width = 4 }
		expect(FactoryLayout.problems(diagonal, Config.Plots, {}, {})).toEqual({
			"Factory.line.path[2]: each run must go straight along x or z from the corner before",
		})
		local far: any = table.clone(Config.Factory)
		far.line = { path = { { x = 0, z = 0 }, { x = 90, z = 0 } }, height = 3, width = 4 }
		expect(FactoryLayout.problems(far, Config.Plots, {}, {})).toEqual({
			"Factory.line: the conveyor and collector must fit on the plot",
		})
		local short: any = table.clone(Config.Factory)
		short.line = { path = { { x = 0, z = 0 } }, height = 3, width = 4 }
		expect(FactoryLayout.problems(short, Config.Plots, {}, {})).toEqual({
			"Factory.line.path: needs at least two corners",
		})
	end)
end)
