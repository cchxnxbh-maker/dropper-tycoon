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
	devCashGift = 1000,
	-- Pacing targets the balance tool checks on every run of the check (plan section 5.2, ADR 0022). Starting values.
	pacing = {
		-- No purchase should take longer than this to save up for.
		maxWaitSeconds = 150,
		-- Buying all of tier 1 should fill most of a 20-minute first session, without dragging past it.
		minTotalMinutes = 12,
		maxTotalMinutes = 25,
	},
}

return Economy
