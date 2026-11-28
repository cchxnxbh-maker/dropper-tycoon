--!strict
-- Schema: the rules every config file must pass (plan section 5.2, guard 2; ADR 0017).
--
-- Type analysis already catches a missing or misspelled field. These rules catch what types cannot: numbers out of
-- range, unknown log levels, a malformed version, registry entries whose ID does not match their file, plots that would
-- overlap, machine params that break their kind's rule, requirements that are missing or loop, machines without a
-- name, and a factory that does not fit on the plot. The loader runs them at startup in Roblox, and
-- `lune run validate-config` runs them in the check, so a bad value fails both places with the same message.
--
-- State owned: none. The ranges below are limits on what is sensible, not tuning values.
--
-- Usage:
--     local problems = Schema.validate(require("./Sources"))
--     if #problems > 0 then error(Schema.report(problems)) end

local FactoryLayout = require("../Logic/FactoryLayout")
local KindTypes = require("../Logic/KindTypes")
local Kinds = require("../Logic/Kinds")
local Log = require("../Util/Log")
local PlotLayout = require("../Logic/PlotLayout")
local Purchase = require("../Logic/Purchase")
local Validate = require("../Logic/Validate")

-- A plain string list for the rule, copied from Log so the two can never disagree.
local LEVELS: { string } = {}
for _, name in Log.LEVELS do
	table.insert(LEVELS, name)
end

local level = Validate.string({ oneOf = LEVELS })
local color = Validate.string({ pattern = "^#%x%x%x%x%x%x$", hint = "like #6E9A5A (a # and six hex digits)" })
local studs = Validate.number({ min = 1, max = 1000 })
local point = Validate.record({
	x = Validate.number({ min = -1000, max = 1000 }),
	z = Validate.number({ min = -1000, max = 1000 }),
})

-- Every kind with a file in `Logic/Kinds/`, sorted.
local KIND_NAMES: { string } = {}
for name in Kinds do
	table.insert(KIND_NAMES, name)
end
table.sort(KIND_NAMES)

local rules = Validate.record({
	Build = Validate.record({
		version = Validate.string({ pattern = "^%d+%.%d+%.%d+$", hint = "like 1.2.3 (three whole numbers)" }),
		devPlaceId = Validate.number({ integer = true, min = 1 }),
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
		Sync = Validate.record({
			cashPerSecond = Validate.number({ min = 0.5, max = 30 }),
			cashSaveSeconds = Validate.number({ min = 0.1, max = 60 }),
			cashEaseShare = Validate.number({ min = 0, max = 0.5 }),
			cashEaseSeconds = Validate.number({ min = 0.01, max = 5 }),
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
	-- The outer limits keep every plot within the plan's world size and the server within Roblox's player limit.
	Plots = Validate.record({
		count = Validate.number({ integer = true, min = 1, max = 50 }),
		ringRadius = Validate.number({ min = 0, max = 2000 }),
		baseSize = studs,
		baseThickness = Validate.number({ min = 0.2, max = 20 }),
		spawnInset = studs,
		spawnSize = studs,
		padThickness = Validate.number({ min = 0.05, max = 20 }),
		signWidth = studs,
		signHeight = studs,
		signThickness = Validate.number({ min = 0.05, max = 20 }),
		signLift = Validate.number({ min = 0, max = 100 }),
		colors = Validate.record({ base = color, spawn = color, sign = color }),
	}),
	Factory = Validate.record({
		line = Validate.record({
			path = Validate.list(point),
			height = Validate.number({ min = 0.5, max = 100 }),
			width = Validate.number({ min = 0.5, max = 50 }),
		}),
		collectorSize = studs,
		dropperSize = Validate.number({ min = 0.5, max = 50 }),
		dropperLift = Validate.number({ min = 0, max = 100 }),
		upgraderClearance = Validate.number({ min = 1, max = 100 }),
		postSize = Validate.number({ min = 0.2, max = 10 }),
		itemSize = Validate.number({ min = 0.2, max = 10 }),
		padSize = studs,
		padThickness = Validate.number({ min = 0.05, max = 20 }),
		padReach = Validate.number({ min = 0, max = 50 }),
		padRetrySeconds = Validate.number({ min = 0.5, max = 10 }),
		maxItemsPerDropper = Validate.number({ integer = true, min = 1, max = 500 }),
		colors = Validate.record({
			conveyor = color,
			collector = color,
			dropper = color,
			upgrader = color,
			item = color,
			pad = color,
		}),
	}),
	-- ADR 0009: cash stays under 1e15 per rebirth cycle.
	Economy = Validate.record({
		maxCash = Validate.number({ min = 1, max = 1e15 }),
		devCashGift = Validate.number({ min = 1, max = 1e15 }),
		levels = Validate.record({
			maxLevel = Validate.number({ integer = true, min = 1, max = 100 }),
			priceGrowth = Validate.number({ min = 1, max = 10 }),
		}),
		pacing = Validate.record({
			maxWaitSeconds = Validate.number({ min = 1, max = 86400 }),
			minTotalMinutes = Validate.number({ min = 0, max = 10000 }),
			maxTotalMinutes = Validate.number({ min = 1, max = 10000 }),
		}),
	}),
	Strings = Validate.map(
		Validate.string({ pattern = "^%u%w*$", hint = "like Net (PascalCase)" }),
		Validate.map(
			Validate.string({ pattern = "^%l%w*$", hint = "like kicked (camelCase)" }),
			Validate.string({ pattern = "%S", hint = "like real words (not empty)", maxLength = 500 })
		)
	),
	-- Each entry's params are checked by its kind's own rule, after these pass.
	Buildables = Validate.registry(Validate.record({
		id = Validate.string({ pattern = "^%u%w*$", hint = "like CoalDropper (PascalCase)", maxLength = 40 }),
		kind = Validate.string({ oneOf = KIND_NAMES }),
		tier = Validate.number({ integer = true, min = 1, max = 20 }),
		price = Validate.number({ min = 0, max = 1e15 }),
		requires = Validate.list(Validate.string({ pattern = "^%u%w*$", hint = "a buildable ID" })),
		line = Validate.string({ oneOf = { "Main" } }),
		params = Validate.map(Validate.string({ pattern = "^%l%w*$", hint = "like itemValue" }), Validate.number()),
		pad = point,
		levelPrice = Validate.optional(Validate.number({ min = 0, max = 1e15 })),
	})),
})

local Schema = {}

--[[
	Checks every config source.
	@param sources the raw config tables, as `Config/Sources.luau` returns them
	@return one line per problem, such as `Tuning.Timing.simRate: must be at least 1, got 0`; empty when valid
]]
function Schema.validate(sources: any): { string }
	local problems = Validate.run(sources, rules, "")
	-- Rules across several fields run only on fields that passed, so each problem is reported once.
	if #problems == 0 then
		for _, problem in PlotLayout.problems(sources.Plots) do
			table.insert(problems, problem)
		end
		local ids = Purchase.sortedIds(sources.Buildables)
		for _, problem in Schema.buildableProblems(sources, ids) do
			table.insert(problems, problem)
		end
		for _, problem in FactoryLayout.problems(sources.Factory, sources.Plots, sources.Buildables, ids) do
			table.insert(problems, problem)
		end
	end
	return problems
end

--[[
	Checks what spans buildable files: each kind's params, levels only on kinds that have them, requirements that
	exist and never loop, and a name in `Strings.Buildables` for every machine.
	@param sources the raw config tables, already passing the per-field rules
	@param ids every buildable ID, sorted
	@return one line per problem
]]
function Schema.buildableProblems(sources: any, ids: { string }): { string }
	local problems: { string } = {}
	local buildables = sources.Buildables
	local names = sources.Strings.Buildables or {}
	for _, id in ids do
		local def = buildables[id]
		local kind = (Kinds :: { [string]: KindTypes.Kind })[def.kind]
		for _, problem in Validate.run(def.params, kind.params, `Buildables.{id}.params`) do
			table.insert(problems, problem)
		end
		if def.levelPrice ~= nil and not kind.levels then
			table.insert(problems, `Buildables.{id}.levelPrice: a {def.kind} has no levels; remove it`)
		end
		for _, required in def.requires do
			if buildables[required] == nil then
				table.insert(problems, `Buildables.{id}.requires: "{required}" is not a buildable`)
			end
		end
		local key = string.lower(string.sub(id, 1, 1)) .. string.sub(id, 2)
		if names[key] == nil then
			table.insert(problems, `Strings.Buildables.{key}: missing; every machine needs a name`)
		end
	end
	-- A loop of requirements would hide every pad in it forever. Walk each chain; a chain longer than the registry
	-- must revisit a machine.
	for _, id in ids do
		local seen: { [string]: boolean } = {}
		local stack = { id }
		local looped = false
		while #stack > 0 and not looped do
			local current = table.remove(stack) :: string
			local def = buildables[current]
			if def then
				for _, required in def.requires do
					if required == id then
						looped = true
					elseif not seen[required] then
						seen[required] = true
						table.insert(stack, required)
					end
				end
			end
		end
		if looped then
			table.insert(problems, `Buildables.{id}.requires: the requirements loop back to {id}`)
		end
	end
	return problems
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
