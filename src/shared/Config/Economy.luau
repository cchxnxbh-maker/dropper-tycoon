--!strict
-- Economy: cash rules (plan section 5.1, ADR 0009). Rebirth, prestige points and offline earnings join in Phase 2.
-- Every number here is a starting value for the balance pass.
-- Ranges are checked by `Config/Schema.luau`. Read it through `Config`, which validates and freezes it.
--
-- State owned: none. Read-only data.
--
-- Usage:
--     local Config = require("../Config")
--     local cap = Config.Economy.maxCash

local Types = require("../Types/Config")

local Economy: Types.Economy = {
	-- Cash stops rising at this amount in one rebirth cycle (ADR 0009). The balance tool keeps real play far below it.
	maxCash = 1e15,
	-- Added by the dev panel's Give cash button, for testing purchases quickly.
	devCashGift = 100000,
	-- Machine levels (ADR 0023). A bought machine's pad sells its next level, up to `maxLevel`; each level costs
	-- `priceGrowth` times the one before. Level 2's price is the machine's own `levelPrice`.
	levels = {
		maxLevel = 10,
		priceGrowth = 1.6,
	},
	-- Pacing targets the balance tool checks on every run of the check (plan section 5.2, ADR 0022). Starting values.
	pacing = {
		-- No purchase, machine or level, should take longer than this to save up for. The first fun gate found waits of
		-- over two minutes too long (ADR 0023).
		maxWaitSeconds = 40,
		-- Buying all of tier 1 should fill most of a 20-minute first session, without dragging past it.
		minTotalMinutes = 12,
		maxTotalMinutes = 25,
	},
}

return Economy
