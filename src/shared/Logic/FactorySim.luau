--!strict
-- FactorySim: the factory as numbers (plan sections 4.1 and 4.3, ADR 0002, ADR 0021).
--
-- One sim is one player's production line. It is built from the machines they own: each kind adds itself to the line
-- (`Logic/Kinds/`), then the sim works out, per dropper, what one item is worth when it reaches the collector and how
-- many steps it travels. Items are never stored. A dropper drops on every step that is a multiple of its interval
-- (counted from step 0, so every machine with the same interval drops together), and the item arrives a fixed number
-- of steps later. So the step at which cash arrives is a formula, a step costs no tables, and the client can draw the
-- same items from the same numbers without the server sending any.
--
-- The line runs only with a conveyor and a collector. A dropper that joins a running line starts dropping from the
-- step it joined, recorded in `starts`; rebuilding after a purchase keeps the earlier machines' starts, so items
-- already on the belt still arrive.
--
-- Pure Luau: no Roblox APIs and no clock. The caller counts steps. Lune tests it.
--
-- State owned: each sim's step counter and its built line.
--
-- Usage:
--     local sim = FactorySim.new(defs, { length = 90, rate = 10, tick = 0, starts = nil })
--     local earned = FactorySim.step(sim)          -- once per fixed step
--     local paid = FactorySim.skip(sim, seconds)    -- time past the catch-up cap, paid by formula

local KindTypes = require("./KindTypes")
local Kinds = require("./Kinds")

export type Dropper = {
	id: string,
	-- Studs along the conveyor where it drops.
	at: number,
	-- What one of its items is worth on arrival, after upgraders and the collector.
	value: number,
	intervalTicks: number,
	travelTicks: number,
	-- Step from which it drops. It drops on steps at or after this that are multiples of `intervalTicks`.
	startTick: number,
}

export type Sim = {
	rate: number,
	length: number,
	tick: number,
	running: boolean,
	speed: number,
	droppers: { Dropper },
	-- Cash per second while running, the exact average of what `step` pays.
	incomeRate: number,
	-- Fraction of a step left over by `skip`, carried to the next call.
	skipCarry: number,
}

export type Options = {
	-- Conveyor length in studs. Items arrive at its end.
	length: number,
	-- Steps per second.
	rate: number,
	-- The step the sim starts at. A rebuild passes the old sim's tick.
	tick: number,
	-- Start steps of droppers that were already running, by ID, from `FactorySim.starts` of the previous sim.
	starts: { [string]: number }?,
}

local FactorySim = {}

local function byId(a: KindTypes.Def, b: KindTypes.Def): boolean
	return a.id < b.id
end

--[[
	Builds a sim from the machines one player owns on one line.
	@param defs the owned buildable definitions, in any order
	@param options line length, step rate, starting step and earlier start steps
	@return the sim
	@error when a definition names a kind with no file in `Logic/Kinds/`
]]
function FactorySim.new(defs: { KindTypes.Def }, options: Options): Sim
	local sorted = table.clone(defs)
	table.sort(sorted, byId)
	local build: KindTypes.LineBuild = {
		speed = 0,
		hasCollector = false,
		collectorMultiplier = 1,
		droppers = {},
		upgraders = {},
	}
	for _, def in sorted do
		local kind = (Kinds :: { [string]: KindTypes.Kind })[def.kind]
		assert(kind, `FactorySim: no kind file for "{def.kind}" (machine {def.id})`)
		kind.apply(build, def)
	end

	local running = build.speed > 0 and build.hasCollector
	local starts = options.starts or {}
	local droppers: { Dropper } = {}
	local incomeRate = 0
	for _, spec in build.droppers do
		local value = spec.itemValue * build.collectorMultiplier
		for _, upgrader in build.upgraders do
			if upgrader.at > spec.at then
				value *= upgrader.multiplier
			end
		end
		local intervalTicks = math.max(1, math.round(spec.interval * options.rate))
		local travelTicks = if running
			then math.max(1, math.ceil(math.max(0, options.length - spec.at) / build.speed * options.rate))
			else 0
		local startTick = if running then starts[spec.id] or options.tick else options.tick
		table.insert(droppers, {
			id = spec.id,
			at = spec.at,
			value = value,
			intervalTicks = intervalTicks,
			travelTicks = travelTicks,
			startTick = startTick,
		})
		if running then
			incomeRate += value * options.rate / intervalTicks
		end
	end

	return {
		rate = options.rate,
		length = options.length,
		tick = options.tick,
		running = running,
		speed = build.speed,
		droppers = droppers,
		incomeRate = incomeRate,
		skipCarry = 0,
	}
end

--[[
	Runs one fixed step.
	@param sim the sim
	@return the cash that arrived at the collector during this step; 0 when the line is not running
]]
function FactorySim.step(sim: Sim): number
	sim.tick += 1
	if not sim.running then
		return 0
	end
	local earned = 0
	for _, dropper in sim.droppers do
		local dropped = sim.tick - dropper.travelTicks
		if dropped >= dropper.startTick and dropped % dropper.intervalTicks == 0 then
			earned += dropper.value
		end
	end
	return earned
end

--[[
	Moves the sim past time the Scheduler could not step (beyond its catch-up cap), paying it by the income rate so a
	stall never costs cash (plan section 4.1).
	@param sim the sim
	@param seconds the skipped time, 0 or more
	@return the cash for the whole steps skipped; a fraction of a step is carried to the next call
]]
function FactorySim.skip(sim: Sim, seconds: number): number
	sim.skipCarry += math.max(0, seconds) * sim.rate
	local steps = math.floor(sim.skipCarry)
	sim.skipCarry -= steps
	sim.tick += steps
	return if sim.running then sim.incomeRate * steps / sim.rate else 0
end

--[[
	@param sim the sim
	@return cash per second while the line runs; 0 when it does not
]]
function FactorySim.incomeRate(sim: Sim): number
	return if sim.running then sim.incomeRate else 0
end

--[[
	The start step of every dropper on a running line, to pass to the next build or to the client.
	@param sim the sim
	@return start step by dropper ID; empty when the line is not running
]]
function FactorySim.starts(sim: Sim): { [string]: number }
	local starts: { [string]: number } = {}
	if sim.running then
		for _, dropper in sim.droppers do
			starts[dropper.id] = dropper.startTick
		end
	end
	return starts
end

--[[
	Where every item on the belt is at a moment between steps, for drawing them. Visual only.
	@param sim the sim
	@param tick the moment, in steps, which may have a fraction
	@param out filled from index 1 with each item's distance along the conveyor, in studs; entries past the count are
	left as they were, so one table can be reused every frame
	@param maxPerDropper most items to report for one dropper, newest first
	@return how many entries of `out` are filled
]]
function FactorySim.itemsAt(sim: Sim, tick: number, out: { number }, maxPerDropper: number): number
	if not sim.running then
		return 0
	end
	local count = 0
	local secondsPerTick = 1 / sim.rate
	for _, dropper in sim.droppers do
		local interval = dropper.intervalTicks
		local dropped = math.floor(tick / interval) * interval
		local shown = 0
		while shown < maxPerDropper and dropped >= dropper.startTick do
			local age = tick - dropped
			if age >= dropper.travelTicks then
				break
			end
			count += 1
			shown += 1
			out[count] = math.min(sim.length, dropper.at + age * secondsPerTick * sim.speed)
			dropped -= interval
		end
	end
	return count
end

return FactorySim
