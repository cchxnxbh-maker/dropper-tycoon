--!strict
-- test: finds every `tests/**/*.spec.luau`, runs it through testkit and prints the results.
--
-- State owned: none. `.lune/test.luau` and the check both call `runAll`. Usage from the project root:
--     lune run test             -- every spec
--     lune run test Rng         -- only specs whose path contains "Rng"

local fs = require("@lune/fs")

local testkit = require("./testkit")

local TESTS_ROOT = "tests"
local SPEC_SUFFIX = ".spec.luau"

local test = {}

-- Collects spec paths under `dir`, sorted, so runs are always in the same order.
local function collect(dir: string, into: { string })
	local names = fs.readDir(dir)
	table.sort(names)
	for _, name in names do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			collect(full, into)
		elseif string.sub(name, -#SPEC_SUFFIX) == SPEC_SUFFIX then
			table.insert(into, full)
		end
	end
end

--[[
	Runs every spec whose path contains `filter` (all specs when nil) and prints one line per failure.
	@param filter optional plain-text fragment of a spec path
	@return true when at least one spec ran and no case failed; a spec that fails to load counts as a failure
]]
function test.runAll(filter: string?): boolean
	local specs: { string } = {}
	if fs.isDir(TESTS_ROOT) then
		collect(TESTS_ROOT, specs)
	end

	local passed, failed, ran = 0, 0, 0
	for _, spec in specs do
		if filter == nil or string.find(spec, filter, 1, true) ~= nil then
			ran += 1
			testkit.reset()
			-- Requires resolve relative to this file, which sits one folder below the project root.
			local modulePath = "../" .. string.sub(spec, 1, -#".luau" - 1)
			local loaded, loadError = pcall(require, modulePath)
			if not loaded then
				failed += 1
				print(string.format("FAIL  %s could not load: %s", spec, tostring(loadError)))
			else
				local results = testkit.run()
				passed += results.passed
				failed += results.failed
				for _, failure in results.failures do
					print(string.format("FAIL  %s: %s\n      %s", spec, failure.name, failure.message))
				end
			end
		end
	end

	if ran == 0 then
		print(if filter then `No spec path contains "{filter}".` else "No specs found under tests/.")
		return false
	end
	print(string.format("%d passed, %d failed, in %d spec file(s)", passed, failed, ran))
	return failed == 0
end

return test
