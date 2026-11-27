--!strict
-- Schema: the rules every config file must pass (plan section 5.2, guard 2; ADR 0017).
--
-- Type analysis already catches a missing or misspelled field. These rules catch what types cannot: numbers out of
-- range, unknown log levels, a malformed version, and registry entries whose ID does not match their file. The loader
-- runs them at startup in Roblox, and `lune run validate-config` runs them in the check, so a bad value fails both
-- places with the same message.
--
-- State owned: none. The ranges below are limits on what is sensible, not tuning values.
--
-- Usage:
--     local problems = Schema.validate(require("./Sources"))
--     if #problems > 0 then error(Schema.report(problems)) end

local Log = require("../Util/Log")
local Validate = require("../Logic/Validate")

-- A plain string list for the rule, copied from Log so the two can never disagree.
local LEVELS: { string } = {}
for _, name in Log.LEVELS do
	table.insert(LEVELS, name)
end

local level = Validate.string({ oneOf = LEVELS })

local rules = Validate.record({
	Build = Validate.record({
		version = Validate.string({ pattern = "^%d+%.%d+%.%d+$", hint = "like 1.2.3 (three whole numbers)" }),
	}),
	Flags = Validate.record({
		Features = Validate.map(
			Validate.string({ pattern = "^%l%w*$", hint = "like offlineEarnings (camelCase)" }),
			Validate.boolean()
		),
		Log = Validate.record({
			default = level,
			tags = Validate.map(Validate.string({ pattern = "^%u%w*$", hint = "like Purchase (PascalCase)" }), level),
		}),
	}),
	Tuning = Validate.record({
		Timing = Validate.record({
			simRate = Validate.number({ integer = true, min = 1, max = 60 }),
			maxCatchUpSteps = Validate.number({ integer = true, min = 1, max = 30 }),
		}),
		Network = Validate.record({
			maxStringLength = Validate.number({ integer = true, min = 16, max = 10000 }),
			maxTableDepth = Validate.number({ integer = true, min = 1, max = 8 }),
			maxTableEntries = Validate.number({ integer = true, min = 1, max = 1000 }),
			strikeWindowSeconds = Validate.number({ min = 1, max = 3600 }),
			kickAfterStrikes = Validate.number({ integer = true, min = 5, max = 10000 }),
			clientRateShare = Validate.number({ min = 0.1, max = 1 }),
		}),
	}),
	Strings = Validate.map(
		Validate.string({ pattern = "^%u%w*$", hint = "like Net (PascalCase)" }),
		Validate.map(
			Validate.string({ pattern = "^%l%w*$", hint = "like kicked (camelCase)" }),
			Validate.string({ pattern = "%S", hint = "like real words (not empty)", maxLength = 500 })
		)
	),
	-- Entry rules arrive with the buildable schema (plan section 5.1). Until then each entry's ID is checked.
	Buildables = Validate.registry(nil),
})

local Schema = {}

--[[
	Checks every config source.
	@param sources the raw config tables, as `Config/Sources.luau` returns them
	@return one line per problem, such as `Tuning.Timing.simRate: must be at least 1, got 0`; empty when valid
]]
function Schema.validate(sources: any): { string }
	return Validate.run(sources, rules, "")
end

--[[
	Turns a list of problems into one readable message for an error or the terminal.
	@param problems the lines from `Schema.validate`
	@return a message with a heading and one indented line per problem
]]
function Schema.report(problems: { string }): string
	local noun = if #problems == 1 then "problem" else "problems"
	return `Config has {#problems} {noun}. Fix these in src/shared/Config:\n  ` .. table.concat(problems, "\n  ")
end

return Schema
