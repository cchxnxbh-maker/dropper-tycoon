--!strict
-- Specs for PlotLayout: plots sit evenly on the ring, each faces the middle, and layouts that would overlap or put the
-- spawn pad off the plot are reported.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Config = require("../../../src/shared/Config")
local PlotLayout = require("../../../src/shared/Logic/PlotLayout")

local function shape(): PlotLayout.Shape
	return { count = 6, ringRadius = 250, baseSize = 160, spawnInset = 16, spawnSize = 8, signWidth = 24 }
end

describe("PlotLayout.ring", function()
	it("gives one slot per plot, numbered in order", function()
		local slots = PlotLayout.ring(6, 250)
		expect(#slots).toBe(6)
		for index, slot in slots do
			expect(slot.index).toBe(index)
		end
	end)

	it("puts every plot at the ring's radius, with plot 1 on the +X axis", function()
		local slots = PlotLayout.ring(6, 250)
		expect(slots[1].x).toBeCloseTo(250)
		expect(slots[1].z).toBeCloseTo(0)
		for _, slot in slots do
			expect(math.sqrt(slot.x * slot.x + slot.z * slot.z)).toBeCloseTo(250)
		end
	end)

	it("spaces neighbours evenly", function()
		local slots = PlotLayout.ring(6, 250)
		for index = 1, 6 do
			local a = slots[index]
			local b = slots[index % 6 + 1]
			-- Six points on a circle of radius r are r apart.
			expect(math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)).toBeCloseTo(250)
		end
	end)

	it("turns each plot so its look vector points at the origin", function()
		for _, slot in PlotLayout.ring(6, 250) do
			-- The look vector of CFrame.Angles(0, yaw, 0) is (-sin yaw, 0, -cos yaw).
			local lookX, lookZ = -math.sin(slot.yaw), -math.cos(slot.yaw)
			expect(lookX).toBeCloseTo(-slot.x / 250)
			expect(lookZ).toBeCloseTo(-slot.z / 250)
		end
	end)

	it("handles a single plot", function()
		local slots = PlotLayout.ring(1, 0)
		expect(#slots).toBe(1)
		expect(slots[1].x).toBeCloseTo(0)
	end)
end)

describe("PlotLayout.problems", function()
	it("accepts the real plot config, which keeps every plot within 400 studs of the origin", function()
		expect(PlotLayout.problems(Config.Plots)).toEqual({})
		expect(Config.Plots.ringRadius + Config.Plots.baseSize).toBe(410)
	end)

	it("accepts plots that just clear each other", function()
		local config = shape()
		config.baseSize = 176
		expect(PlotLayout.problems(config)).toEqual({})
	end)

	it("reports neighbours that overlap", function()
		local config = shape()
		config.ringRadius = 100
		expect(#PlotLayout.problems(config)).toBe(1)
	end)

	it("never reports overlap for a single plot", function()
		local config = shape()
		config.count = 1
		config.ringRadius = 0
		expect(PlotLayout.problems(config)).toEqual({})
	end)

	it("reports a spawn pad off the front half of the plot, and a sign wider than the plot", function()
		local config = shape()
		config.spawnInset = 100
		config.signWidth = 200
		expect(PlotLayout.problems(config)).toEqual({
			"Plots.signWidth: the sign is wider than the plot",
			"Plots.spawnInset: the spawn pad must sit in the front half of the plot",
		})
	end)
end)
