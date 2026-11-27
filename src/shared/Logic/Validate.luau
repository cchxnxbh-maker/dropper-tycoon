--!strict
-- Validate: small rules that check a data table and describe every problem in plain words (plan section 5.2).
--
-- A rule looks at one value and appends a line per problem to a list. Rules nest, so the config schema is one tree of
-- rules and every problem names its full path, such as `Tuning.Timing.simRate: must be at least 1, got 0`. Keys are
-- visited in sorted order, so the same data always gives the same lines in the same order.
--
-- Pure Luau: no Roblox APIs, so the config loader in Roblox and `lune run validate-config` share it (ADR 0017).
--
-- State owned: none.
--
-- Usage:
--     local rule = Validate.record({ simRate = Validate.number({ integer = true, min = 1 }) })
--     local problems = Validate.run({ simRate = 0 }, rule, "Timing")
--     -- { "Timing.simRate: must be at least 1, got 0" }

export type Problems = { string }
export type Rule = (value: any, path: string, problems: Problems) -> ()
export type NumberOptions = { integer: boolean?, min: number?, max: number? }
export type StringOptions = { oneOf: { string }?, pattern: string?, hint: string?, maxLength: number? }

local Validate = {}

-- How a wrong value is shown in a problem line. Tables and functions show their type, not an address.
local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) == "number" or type(value) == "boolean" or value == nil then
		return tostring(value)
	end
	return `a {type(value)}`
end

local function add(problems: Problems, path: string, message: string, value: any)
	local where = if path == "" then "(root)" else path
	table.insert(problems, `{where}: {message}, got {show(value)}`)
end

local function join(path: string, key: any): string
	local name = tostring(key)
	return if path == "" then name else path .. "." .. name
end

-- Keys of a table in sorted order. The one place this module walks a table's keys, and it sorts them at once so the
-- order of problems never depends on hash order.
local function sortedKeys(value: { [any]: any }): { any }
	local keys = {}
	for key in value do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

--[[
	A number, optionally whole and inside a range. NaN and infinity are never accepted.
	@param options `integer` for whole numbers only, `min` and `max` inclusive bounds
	@return the rule
]]
function Validate.number(options: NumberOptions?): Rule
	local opts: NumberOptions = options or {}
	return function(value, path, problems)
		if type(value) ~= "number" or value ~= value then
			add(problems, path, "must be a number", value)
		elseif value == math.huge or value == -math.huge then
			add(problems, path, "must be a finite number", value)
		elseif opts.integer and value % 1 ~= 0 then
			add(problems, path, "must be a whole number", value)
		elseif opts.min ~= nil and value < opts.min then
			add(problems, path, `must be at least {opts.min}`, value)
		elseif opts.max ~= nil and value > opts.max then
			add(problems, path, `must be at most {opts.max}`, value)
		end
	end
end

--[[
	A boolean: true or false.
	@return the rule
]]
function Validate.boolean(): Rule
	return function(value, path, problems)
		if type(value) ~= "boolean" then
			add(problems, path, "must be true or false", value)
		end
	end
end

--[[
	A string, optionally one of a list, matching a Lua pattern, or no longer than a limit.
	@param options `oneOf` allowed values, `pattern` a Lua pattern, `hint` words shown when the pattern does not match,
	`maxLength` the most characters (bytes) allowed
	@return the rule
]]
function Validate.string(options: StringOptions?): Rule
	local opts: StringOptions = options or {}
	return function(value, path, problems)
		if type(value) ~= "string" then
			add(problems, path, "must be text", value)
			return
		end
		local allowed = opts.oneOf
		if opts.maxLength ~= nil and #value > opts.maxLength then
			-- The value itself is not shown: it may be huge.
			table.insert(
				problems,
				`{if path == "" then "(root)" else path}: must be at most {opts.maxLength} characters, got {#value}`
			)
		elseif allowed and table.find(allowed, value) == nil then
			add(problems, path, "must be one of " .. table.concat(allowed, ", "), value)
		elseif opts.pattern and string.match(value, opts.pattern) == nil then
			add(problems, path, `must look {opts.hint or "like " .. opts.pattern}`, value)
		end
	end
end

--[[
	A value that may be missing. When present it must pass `rule`.
	@param rule the rule for a present value
	@return the rule
]]
function Validate.optional(rule: Rule): Rule
	return function(value, path, problems)
		if value ~= nil then
			rule(value, path, problems)
		end
	end
end

--[[
	A table with exactly these fields. A missing field is checked by its own rule (so it fails unless optional), and a
	field with no rule is reported, which catches misspelled names.
	@param fields the rule for each field name
	@return the rule
]]
function Validate.record(fields: { [string]: Rule }): Rule
	local names = sortedKeys(fields)
	return function(value, path, problems)
		if type(value) ~= "table" then
			add(problems, path, "must be a table", value)
			return
		end
		for _, name in names do
			fields[name](value[name], join(path, name), problems)
		end
		for _, key in sortedKeys(value) do
			if fields[key] == nil then
				add(problems, join(path, key), "is not a known field (check the spelling)", value[key])
			end
		end
	end
end

--[[
	A table of any size where every key passes `keyRule` and every value passes `valueRule`.
	@param keyRule the rule for each key
	@param valueRule the rule for each value
	@return the rule
]]
function Validate.map(keyRule: Rule, valueRule: Rule): Rule
	return function(value, path, problems)
		if type(value) ~= "table" then
			add(problems, path, "must be a table", value)
			return
		end
		for _, key in sortedKeys(value) do
			local keyPath = join(path, key)
			keyRule(key, keyPath .. " (name)", problems)
			valueRule(value[key], keyPath, problems)
		end
	end
end

--[[
	A registry built from a folder index: file name to entry. Each entry must be a table whose `id` equals its file
	name, because IDs are saved in player data and must never drift from the file that defines them.
	@param entryRule optional rule for each entry's full contents
	@return the rule
]]
function Validate.registry(entryRule: Rule?): Rule
	return function(value, path, problems)
		if type(value) ~= "table" then
			add(problems, path, "must be a table", value)
			return
		end
		for _, key in sortedKeys(value) do
			local entry = value[key]
			local entryPath = join(path, key)
			if type(entry) ~= "table" then
				add(problems, entryPath, "must be a table", entry)
			else
				if entry.id ~= key then
					add(problems, entryPath .. ".id", `must match the file name "{tostring(key)}"`, entry.id)
				end
				if entryRule then
					entryRule(entry, entryPath, problems)
				end
			end
		end
	end
end

--[[
	Checks `value` against `rule`.
	@param value the data to check
	@param rule the rule tree
	@param root the name the paths start with, or "" for none
	@return one line per problem, empty when the data is valid
]]
function Validate.run(value: any, rule: Rule, root: string): Problems
	local problems: Problems = {}
	rule(value, root, problems)
	return problems
end

return Validate
