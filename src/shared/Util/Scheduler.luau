--!strict
-- Scheduler: the game loop. Each system registers its own named step instead of sharing one update function (plan
-- section 4.1).
--
-- `every` registers a fixed-rate step: it always receives the same `dt`, at most
-- `Config.Tuning.Timing.maxCatchUpSteps` of them run in one frame, and time beyond that goes to the step's `onSkipped`
-- handler to be paid by formula. `onRender` registers a per-frame client callback that gets the frame's `dt` and the
-- `alpha` of the fixed step it follows.
--
-- Steps run in name order, so the order never depends on which module was required first. Each step is wrapped in a
-- MicroProfiler label with its name. A step that errors is logged once and keeps being called, so one broken system
-- does not stop the others.
--
-- This module is pure: the two `Main` scripts feed it frame times from RunService, and tests feed it by hand.
--
-- State owned: registered steps, their FixedStep accumulators and render callbacks.
--
-- Usage:
--     Scheduler.every("FactorySim", Config.Tuning.Timing.simRate, function(dt) ... end, function(skipped) ... end)
--     Scheduler.onRender("ItemVisuals", function(dt, alpha) ... end, "FactorySim")
--     RunService.Heartbeat:Connect(Scheduler.update)    -- in Main only

local Config = require("../Config")
local FixedStep = require("./FixedStep")
local Log = require("./Log")

export type StepFn = (dt: number) -> ()
export type SkippedFn = (seconds: number) -> ()
export type RenderFn = (dt: number, alpha: number) -> ()

type FixedEntry = {
	name: string,
	clock: FixedStep.FixedStep,
	step: StepFn,
	onSkipped: SkippedFn?,
	failed: boolean,
}

type RenderEntry = {
	name: string,
	render: RenderFn,
	follows: string?,
	failed: boolean,
}

local Scheduler = {}

local fixed: { FixedEntry } = {}
local renders: { RenderEntry } = {}

-- Roblox has MicroProfiler labels; Lune does not, so they become no-ops there.
local profileBegin: (string) -> () = (debug :: any).profilebegin or function(_: string) end
local profileEnd: () -> () = (debug :: any).profileend or function() end

local function isTaken(name: string): boolean
	for _, entry in fixed do
		if entry.name == name then
			return true
		end
	end
	for _, entry in renders do
		if entry.name == name then
			return true
		end
	end
	return false
end

-- Lists hold FixedEntry or RenderEntry; both have a name, which is all this reads.
local function insertSorted(list: { any }, entry: any)
	local at = #list + 1
	for index, existing in list do
		if entry.name < existing.name then
			at = index
			break
		end
	end
	table.insert(list, at, entry)
end

-- Runs `fn` under a profiler label. Logs the first failure of each step, then stays quiet about it.
local function guarded(entry: { name: string, failed: boolean }, fn: (...any) -> (), ...: any)
	profileBegin(entry.name)
	local ok, problem = pcall(fn :: any, ...)
	profileEnd()
	if not ok and not entry.failed then
		entry.failed = true
		Log.error("Scheduler", "step failed", { step = entry.name, problem = tostring(problem) })
	end
end

--[[
	Registers a fixed-rate step.
	@param name unique step name, shown in the MicroProfiler and in logs
	@param rate steps per second
	@param step called with the constant step length in seconds
	@param onSkipped optional; called once per frame with the seconds that went past the catch-up cap
	@error when the name is already registered or the rate is not positive
]]
function Scheduler.every(name: string, rate: number, step: StepFn, onSkipped: SkippedFn?)
	assert(not isTaken(name), "Scheduler: a step named " .. name .. " already exists")
	local entry: FixedEntry = {
		name = name,
		clock = FixedStep.new(rate, Config.Tuning.Timing.maxCatchUpSteps),
		step = step,
		onSkipped = onSkipped,
		failed = false,
	}
	insertSorted(fixed, entry)
end

--[[
	Registers a per-frame render callback. Client only.
	@param name unique name
	@param render called every frame with the frame's dt and an alpha in [0, 1)
	@param follows optional fixed step whose progress gives `alpha`; alpha is 0 without it
	@error when the name is already registered
]]
function Scheduler.onRender(name: string, render: RenderFn, follows: string?)
	assert(not isTaken(name), "Scheduler: a step named " .. name .. " already exists")
	insertSorted(renders, { name = name, render = render, follows = follows, failed = false })
end

--[[
	Unregisters a fixed step or render callback. Unknown names are ignored.
	@param name the name it was registered with
]]
function Scheduler.remove(name: string)
	for index, entry in fixed do
		if entry.name == name then
			table.remove(fixed, index)
			return
		end
	end
	for index, entry in renders do
		if entry.name == name then
			table.remove(renders, index)
			return
		end
	end
end

--[[
	Runs every fixed step that is due. Main connects this to RunService.Heartbeat.
	@param frameDt seconds since the last frame
]]
function Scheduler.update(frameDt: number)
	for _, entry in fixed do
		local steps, skipped = entry.clock:advance(frameDt)
		for _ = 1, steps do
			guarded(entry, entry.step, entry.clock.dt)
		end
		local onSkipped = entry.onSkipped
		if skipped > 0 and onSkipped then
			guarded(entry, onSkipped, skipped)
		end
	end
end

--[[
	The progress of a fixed step toward its next tick.
	@param name a fixed step's name
	@return alpha in [0, 1), or 0 when no such step exists
]]
function Scheduler.alpha(name: string): number
	for _, entry in fixed do
		if entry.name == name then
			return entry.clock:alpha()
		end
	end
	return 0
end

--[[
	Runs every render callback. The client's Main connects this to RunService.RenderStepped.
	@param frameDt seconds since the last frame
]]
function Scheduler.render(frameDt: number)
	for _, entry in renders do
		local follows = entry.follows
		local alpha = if follows then Scheduler.alpha(follows) else 0
		guarded(entry, entry.render, frameDt, alpha)
	end
end

--[[
	Removes every step and callback. For tests.
]]
function Scheduler.reset()
	table.clear(fixed)
	table.clear(renders)
end

return Scheduler
