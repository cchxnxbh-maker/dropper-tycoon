--!strict
-- Specs for Scheduler: identical results at 30, 60 and 144 frames per second, the catch-up cap with skipped time paid
-- by formula, name order, render alpha, and that one failing step does not stop the others.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Log = require("../../../src/shared/Util/Log")
local Scheduler = require("../../../src/shared/Util/Scheduler")
local Tuning = require("../../../src/shared/Config/Tuning")

local INCOME_PER_SECOND = 7.5

-- A stand-in for the factory: earns per fixed step, and pays skipped time by the same rate formula.
local function runEconomy(frameTimes: { number }): (number, number)
	Scheduler.reset()
	local cash, ticks = 0, 0
	Scheduler.every("FactorySim", Tuning.Timing.simRate, function(dt)
		ticks += 1
		cash += INCOME_PER_SECOND * dt
	end, function(skipped)
		cash += INCOME_PER_SECOND * skipped
	end)
	for _, frameDt in frameTimes do
		Scheduler.update(frameDt)
	end
	Scheduler.reset()
	return cash, ticks
end

local function steadyFrames(fps: number, seconds: number): { number }
	local frames = {}
	for _ = 1, fps * seconds do
		table.insert(frames, 1 / fps)
	end
	return frames
end

describe("Scheduler.every", function()
	it("gives identical results at 30, 60 and 144 frames per second", function()
		local cash30, ticks30 = runEconomy(steadyFrames(30, 120))
		local cash60, ticks60 = runEconomy(steadyFrames(60, 120))
		local cash144, ticks144 = runEconomy(steadyFrames(144, 120))
		expect(ticks30).toBe(1200)
		expect(ticks60).toBe(1200)
		expect(ticks144).toBe(1200)
		expect(cash60).toBe(cash30)
		expect(cash144).toBe(cash30)
	end)

	it("caps catch-up at the tuned step count and pays the rest by formula", function()
		local cash, ticks = runEconomy({ 10 })
		expect(ticks).toBe(Tuning.Timing.maxCatchUpSteps)
		expect(cash).toBeCloseTo(INCOME_PER_SECOND * 10, 1e-9)
	end)

	it("a stall never costs cash", function()
		local frames = steadyFrames(60, 5)
		table.insert(frames, 45) -- a 45 second freeze
		for _, frameDt in steadyFrames(60, 10) do
			table.insert(frames, frameDt)
		end
		local cash = runEconomy(frames)
		expect(cash).toBeCloseTo(INCOME_PER_SECOND * 60, 1e-6)
	end)

	it("runs steps in name order whatever the registration order", function()
		Scheduler.reset()
		local order: { string } = {}
		for _, name in { "Zeta", "Alpha", "Mid" } do
			Scheduler.every(name, 10, function()
				table.insert(order, name)
			end)
		end
		Scheduler.update(0.1)
		Scheduler.reset()
		expect(order).toEqual({ "Alpha", "Mid", "Zeta" })
	end)

	it("refuses a duplicate name and forgets removed steps", function()
		Scheduler.reset()
		local calls = 0
		Scheduler.every("Once", 10, function()
			calls += 1
		end)
		expect(function()
			Scheduler.every("Once", 10, function() end)
		end).toThrow("already exists")
		Scheduler.remove("Once")
		Scheduler.update(1)
		Scheduler.reset()
		expect(calls).toBe(0)
	end)

	it("keeps running other steps when one fails, and logs the failure once", function()
		Scheduler.reset()
		local lines: { string } = {}
		Log.setSink(function(_, line)
			table.insert(lines, line)
		end)
		local healthy = 0
		Scheduler.every("Broken", 10, function()
			error("boom")
		end)
		Scheduler.every("Healthy", 10, function()
			healthy += 1
		end)
		Scheduler.update(0.1)
		Scheduler.update(0.1)
		Log.setSink(nil)
		Scheduler.reset()
		expect(healthy).toBe(2)
		expect(#lines).toBe(1)
		expect(string.find(lines[1], "step=Broken", 1, true) ~= nil).toBe(true)
	end)
end)

describe("Scheduler.onRender", function()
	it("passes the frame dt and the followed step's alpha", function()
		Scheduler.reset()
		local seenDt, seenAlpha = 0, -1
		Scheduler.every("FactorySim", 10, function() end)
		Scheduler.onRender("ItemVisuals", function(dt, alpha)
			seenDt, seenAlpha = dt, alpha
		end, "FactorySim")
		Scheduler.update(0.025)
		Scheduler.render(0.025)
		Scheduler.reset()
		expect(seenDt).toBe(0.025)
		expect(seenAlpha).toBeCloseTo(0.25)
	end)

	it("passes alpha 0 when it follows no step", function()
		Scheduler.reset()
		local seenAlpha = -1
		Scheduler.onRender("Hud", function(_, alpha)
			seenAlpha = alpha
		end)
		Scheduler.render(1 / 60)
		Scheduler.reset()
		expect(seenAlpha).toBe(0)
	end)
end)
