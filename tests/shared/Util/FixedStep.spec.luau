--!strict
-- Specs for FixedStep: frame-rate independence at 30, 60 and 144 frames per second, the catch-up cap, and alpha.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local FixedStep = require("../../../src/shared/Util/FixedStep")

-- Runs `seconds` of frames at `fps` and returns the steps run and the seconds skipped.
local function play(clock: FixedStep.FixedStep, fps: number, seconds: number): (number, number)
	local totalSteps, totalSkipped = 0, 0
	for _ = 1, math.round(fps * seconds) do
		local steps, skipped = clock:advance(1 / fps)
		totalSteps += steps
		totalSkipped += skipped
	end
	return totalSteps, totalSkipped
end

describe("FixedStep", function()
	it("runs the same number of steps at 30, 60 and 144 frames per second", function()
		for _, fps in { 30, 60, 144 } do
			local steps, skipped = play(FixedStep.new(10, 5), fps, 60)
			expect(steps).toBe(600)
			expect(skipped).toBe(0)
		end
	end)

	it("keeps dt constant", function()
		expect(FixedStep.new(10, 5).dt).toBe(0.1)
	end)

	it("runs at most maxSteps in one frame and reports the rest as skipped", function()
		local clock = FixedStep.new(10, 5)
		local steps, skipped = clock:advance(2)
		expect(steps).toBe(5)
		expect(skipped).toBeCloseTo(1.5)
	end)

	it("loses no time across a stall: run plus skipped equals elapsed", function()
		local clock = FixedStep.new(10, 5)
		local before = play(clock, 60, 1)
		local stallSteps, stallSkipped = clock:advance(30)
		local after = play(clock, 60, 1)
		local accounted = (before + stallSteps + after) * clock.dt + stallSkipped + clock.accumulator
		expect(accounted).toBeCloseTo(32, 1e-6)
		expect(stallSteps).toBe(5)
	end)

	it("ignores negative, NaN and infinite frame times", function()
		local clock = FixedStep.new(10, 5)
		for _, bad in { -1, 0 / 0, math.huge } do
			local steps, skipped = clock:advance(bad)
			expect(steps).toBe(0)
			expect(skipped).toBe(0)
		end
		expect(clock.accumulator).toBe(0)
	end)

	it("reports alpha as the fraction of the next step", function()
		local clock = FixedStep.new(10, 5)
		clock:advance(0.05)
		expect(clock:alpha()).toBeCloseTo(0.5)
		clock:advance(0.05)
		expect(clock:alpha()).toBeCloseTo(0)
		clock:reset()
		expect(clock.accumulator).toBe(0)
	end)

	it("rejects a bad rate or cap", function()
		expect(function()
			FixedStep.new(0, 5)
		end).toThrow("rate")
		expect(function()
			FixedStep.new(10, 0)
		end).toThrow("maxSteps")
	end)
end)
