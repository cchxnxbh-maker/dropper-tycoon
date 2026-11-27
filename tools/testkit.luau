--!strict
-- testkit: the project's small test framework (ADR 0008).
--
-- Specs call `describe`, `it` and `expect` to register cases. The runner (`tools/test.luau`) loads each spec file, then
-- calls `run` to execute what was registered and `reset` before the next file. Pure Luau with no Lune or Roblox
-- imports, so the same specs can later run inside Studio.
--
-- State owned: the list of registered cases and the current `describe` path. Nothing else.
--
-- Usage, in tests/shared/Logic/Example.spec.luau:
--     local testkit = require("../../../tools/testkit")
--     local describe, it, expect = testkit.describe, testkit.it, testkit.expect
--     describe("Example", function()
--         it("adds", function()
--             expect(1 + 1).toBe(2)
--         end)
--     end)

export type Failure = { name: string, message: string }
export type Results = { passed: number, failed: number, failures: { Failure } }

export type Expectation = {
	toBe: (expected: any) -> (),
	toEqual: (expected: any) -> (),
	toBeCloseTo: (expected: number, tolerance: number?) -> (),
	toBeNil: () -> (),
	toBeTruthy: () -> (),
	toThrow: (fragment: string?) -> (),
	never: {
		toBe: (expected: any) -> (),
		toEqual: (expected: any) -> (),
		toBeNil: () -> (),
	},
}

type Case = { name: string, fn: () -> () }

local cases: { Case } = {}
local path: { string } = {}

local testkit = {}

local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

-- Deep equality for plain data. Returns nil when equal, or a short description of the first difference.
local function difference(actual: any, expected: any, where: string): string?
	if type(actual) ~= "table" or type(expected) ~= "table" then
		if actual == expected or (actual ~= actual and expected ~= expected) then
			return nil
		end
		return string.format("%s: expected %s, got %s", where, show(expected), show(actual))
	end
	for key, value in expected do
		local found = difference(actual[key], value, where .. "." .. tostring(key))
		if found then
			return found
		end
	end
	for key, value in actual do
		if expected[key] == nil then
			return string.format("%s.%s: unexpected value %s", where, tostring(key), show(value))
		end
	end
	return nil
end

--[[
	Groups cases under a name. Nested groups join their names with " > ".
	@param name the group name shown in results
	@param body registers cases by calling `it`; it runs immediately, not at `run` time
]]
function testkit.describe(name: string, body: () -> ())
	table.insert(path, name)
	body()
	table.remove(path)
end

--[[
	Registers one case. It runs later, when the runner calls `run`.
	@param name what the case proves, shown in results
	@param fn the case; it fails if it raises an error, and every failed `expect` raises one
]]
function testkit.it(name: string, fn: () -> ())
	local full = table.clone(path)
	table.insert(full, name)
	table.insert(cases, { name = table.concat(full, " > "), fn = fn })
end

--[[
	Wraps a value so a case can state what it should be.
	@param actual the value under test
	@return matchers; each raises an error with a readable message when it does not hold
]]
function testkit.expect(actual: any): Expectation
	local function check(holds: boolean, message: string)
		if not holds then
			error(message, 3)
		end
	end

	local expectation: Expectation = {
		toBe = function(expected: any)
			check(actual == expected, string.format("expected %s, got %s", show(expected), show(actual)))
		end,
		toEqual = function(expected: any)
			local found = difference(actual, expected, "value")
			check(found == nil, found or "")
		end,
		toBeCloseTo = function(expected: number, tolerance: number?)
			local limit = tolerance or 1e-9
			local holds = type(actual) == "number" and math.abs(actual - expected) <= limit
			check(holds, string.format("expected %s within %s, got %s", show(expected), show(limit), show(actual)))
		end,
		toBeNil = function()
			check(actual == nil, string.format("expected nil, got %s", show(actual)))
		end,
		toBeTruthy = function()
			check(not not actual, string.format("expected a truthy value, got %s", show(actual)))
		end,
		toThrow = function(fragment: string?)
			check(type(actual) == "function", "toThrow needs a function")
			local ok, err = pcall(actual)
			check(not ok, "expected an error, but none was raised")
			if fragment then
				local text = tostring(err)
				local holds = string.find(text, fragment, 1, true) ~= nil
				check(holds, string.format("expected an error containing %s, got %s", show(fragment), show(text)))
			end
		end,
		never = {
			toBe = function(expected: any)
				check(actual ~= expected, string.format("expected a value other than %s", show(expected)))
			end,
			toEqual = function(expected: any)
				check(difference(actual, expected, "value") ~= nil, "expected the values to differ")
			end,
			toBeNil = function()
				check(actual ~= nil, "expected a value, got nil")
			end,
		},
	}
	return expectation
end

--[[
	Runs every registered case in registration order.
	@return counts and one entry per failed case; never raises
]]
function testkit.run(): Results
	local results: Results = { passed = 0, failed = 0, failures = {} }
	for _, case in cases do
		-- xpcall with a handler, because the type of pcall on a function that returns nothing has no error value.
		local message: string? = nil
		local ok = xpcall(case.fn, function(err: any)
			message = tostring(err)
		end)
		if ok then
			results.passed += 1
		else
			results.failed += 1
			table.insert(results.failures, { name = case.name, message = message or "unknown error" })
		end
	end
	return results
end

--[[
	Forgets all registered cases. The runner calls this before loading each spec file.
]]
function testkit.reset()
	table.clear(cases)
	table.clear(path)
end

return testkit
