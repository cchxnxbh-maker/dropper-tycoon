--!strict
-- Balance: plays a fresh factory from config alone and reports how long each purchase takes (plan section 5.2, guard
-- 3; ADR 0022).
--
-- The simulated player starts with no cash and no machines, stands on every pad at once and buys the cheapest
-- available machine the moment they can afford it (ties go to the lower ID). Walking takes no time, so real waits are
-- a little longer. Every step runs the real `FactorySim`, rebuilt after each purchase exactly as the server does, so
-- the numbers are the game's numbers. `problems` compares the result with the pacing targets in `Economy.pacing`.
--
-- Pure Luau. State owned: none.
--
-- Usage:
--     local report = Balance.run(Config)
--     for _, problem in Balance.problems(report, Config.Economy) do print(problem) end

local FactorySim = require("./FactorySim")
local Purchase = require("./Purchase")
local Types = require("../Types/Config")

export type Buy = {
	id: string,
	price: number,
	-- Seconds from the start of the game to this purchase.
	at: number,
	-- Seconds since the previous purchase (or the start).
	waited: number,
	-- Cash per second after this purchase.
	rate: number,
}

export type Report = {
	buys: { Buy },
	-- True when every machine was bought before the time limit.
	finished: boolean,
	-- Seconds from the start to the last purchase, or to the time limit.
	seconds: number,
	-- Most cash held at any moment.
	peakCash: number,
	-- Machines never bought before the time limit, sorted.
	unbought: { string },
}

-- The parts of `Config` this module reads.
export type Inputs = {
	Buildables: { [string]: Types.BuildableDef },
	Factory: Types.Factory,
	Economy: Types.Economy,
	Tuning: Types.Tuning,
}

local Balance = {}

-- The cheapest machine the player can buy now, or nil.
local function nextBuy(
	owned: { [string]: boolean },
	buildables: { [string]: Types.BuildableDef },
	ids: { string }
): Types.BuildableDef?
	local best: Types.BuildableDef? = nil
	for _, id in Purchase.available(owned, buildables, ids) do
		local def = buildables[id]
		if best == nil or def.price < best.price then
			best = def
		end
	end
	return best
end

--[[
	Plays a fresh factory until every machine is bought or `Economy.pacing.maxTotalMinutes` doubles.
	@param config the config, or a test copy with the same fields
	@return what was bought when, and how it ended
]]
function Balance.run(config: Inputs): Report
	local buildables = config.Buildables
	local ids = Purchase.sortedIds(buildables)
	local rate = config.Tuning.Timing.simRate
	local limitSteps = config.Economy.pacing.maxTotalMinutes * 60 * 2 * rate -- const: minutes to seconds, run to twice the target
	local owned: { [string]: boolean } = {}
	local defs: { any } = {}
	local sim = FactorySim.new(defs, { length = config.Factory.line.length, rate = rate, tick = 0, starts = nil })
	local cash = 0
	local peak = 0
	local lastBuy = 0
	local buys: { Buy } = {}

	while sim.tick <= limitSteps do
		-- Buy everything affordable on this step before the next one runs, as standing on the pads would.
		local def = nextBuy(owned, buildables, ids)
		while def and cash >= def.price do
			cash -= def.price
			owned[def.id] = true
			table.insert(defs, def)
			sim = FactorySim.new(defs, {
				length = config.Factory.line.length,
				rate = rate,
				tick = sim.tick,
				starts = FactorySim.starts(sim),
			})
			local now = sim.tick / rate
			table.insert(buys, {
				id = def.id,
				price = def.price,
				at = now,
				waited = now - lastBuy,
				rate = FactorySim.incomeRate(sim),
			})
			lastBuy = now
			def = nextBuy(owned, buildables, ids)
		end
		if def == nil then
			break
		end
		cash = math.min(config.Economy.maxCash, cash + FactorySim.step(sim))
		peak = math.max(peak, cash)
	end

	local unbought: { string } = {}
	for _, id in ids do
		if not owned[id] then
			table.insert(unbought, id)
		end
	end
	return {
		buys = buys,
		finished = #unbought == 0,
		seconds = if #unbought == 0 then lastBuy else sim.tick / rate,
		peakCash = peak,
		unbought = unbought,
	}
end

--[[
	Compares a report with the pacing targets.
	@param report from `Balance.run`
	@param economy the economy config, with `pacing` and `maxCash`
	@return one readable line per broken target, empty when the pacing holds
]]
function Balance.problems(report: Report, economy: Types.Economy): { string }
	local problems: { string } = {}
	local pacing = economy.pacing
	if not report.finished then
		table.insert(problems, `never bought {table.concat(report.unbought, ", ")}: the factory stalls`)
	end
	for _, buy in report.buys do
		if buy.waited > pacing.maxWaitSeconds then
			table.insert(
				problems,
				`{buy.id}: waited {math.round(buy.waited)} s, more than Economy.pacing.maxWaitSeconds ({pacing.maxWaitSeconds} s)`
			)
		end
	end
	local minutes = report.seconds / 60 -- const: seconds to minutes
	if report.finished and minutes > pacing.maxTotalMinutes then
		table.insert(
			problems,
			`buying everything took {string.format("%.1f", minutes)} min, more than Economy.pacing.maxTotalMinutes ({pacing.maxTotalMinutes})`
		)
	end
	if report.finished and minutes < pacing.minTotalMinutes then
		table.insert(
			problems,
			`buying everything took {string.format("%.1f", minutes)} min, less than Economy.pacing.minTotalMinutes ({pacing.minTotalMinutes})`
		)
	end
	if report.peakCash >= economy.maxCash then
		table.insert(problems, "cash reached Economy.maxCash in one cycle (ADR 0009)")
	end
	return problems
end

return Balance
