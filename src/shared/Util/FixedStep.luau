--!strict
-- FixedStep: turns uneven frame times into a whole number of fixed-length steps (plan section 4.1).
--
-- Frame time goes into an accumulator. Each call reports how many fixed steps are due, at most `maxSteps`. Time beyond
-- the cap is reported as skipped seconds instead of being run, so a long stall never spirals into a catch-up loop; the
-- caller pays skipped time by formula (for the factory, the income-rate formula). The leftover fraction of a step stays
-- in the accumulator and is exposed as `alpha` so the client can draw between the previous and current state.
--
-- Pure Luau with no Roblox calls, so frame-rate independence is tested in Lune.
--
-- State owned: one accumulator per FixedStep object.
--
-- Usage:
--     local clock = FixedStep.new(10, 5)          -- 10 steps per second, at most 5 per frame
--     local steps, skipped = clock:advance(frameDt)
--     for _ = 1, steps do simulate(clock.dt) end
--     if skipped > 0 then payByFormula(skipped) end

-- Float sums such as 144 frames of 1/144 land a hair under a whole step. This tolerance counts them as a full step, so
-- every frame rate reaches the same step on the same frame time.
local EPSILON = 1e-9

export type FixedStep = {
	dt: number,
	maxSteps: number,
	accumulator: number,
	advance: (self: FixedStep, frameDt: number) -> (number, number),
	alpha: (self: FixedStep) -> number,
	reset: (self: FixedStep) -> (),
}

local FixedStep = {}

local methods = {}
methods.__index = methods

--[[
	Adds one frame's time and reports the work due.
	@param frameDt seconds since the last frame; negative, NaN or infinite values count as 0
	@return steps to run now (0 to maxSteps), and seconds skipped beyond the cap (0 when under it)
]]
function methods.advance(self: FixedStep, frameDt: number): (number, number)
	if frameDt ~= frameDt or frameDt <= 0 or frameDt == math.huge then
		return 0, 0
	end
	self.accumulator += frameDt
	local due = math.floor(self.accumulator / self.dt + EPSILON)
	self.accumulator = math.max(0, self.accumulator - due * self.dt)
	if due <= self.maxSteps then
		return due, 0
	end
	return self.maxSteps, (due - self.maxSteps) * self.dt
end

--[[
	How far the next step has progressed, for drawing between states.
	@return a number in [0, 1)
]]
function methods.alpha(self: FixedStep): number
	return math.clamp(self.accumulator / self.dt, 0, 1 - EPSILON)
end

--[[
	Drops any accumulated time, for example when a plot is cleared.
]]
function methods.reset(self: FixedStep)
	self.accumulator = 0
end

--[[
	Makes a fixed-step clock.
	@param rate steps per second, greater than 0
	@param maxSteps the most steps one `advance` call may return, a whole number of at least 1
	@return the clock; `clock.dt` is the constant step length in seconds
	@error when rate or maxSteps is out of range
]]
function FixedStep.new(rate: number, maxSteps: number): FixedStep
	assert(rate > 0 and rate < math.huge, "FixedStep: rate must be a positive number")
	assert(maxSteps >= 1 and maxSteps == math.floor(maxSteps), "FixedStep: maxSteps must be a whole number >= 1")
	local clock = { dt = 1 / rate, maxSteps = maxSteps, accumulator = 0 }
	return (setmetatable(clock :: any, methods) :: any) :: FixedStep
end

return FixedStep
