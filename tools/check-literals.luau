--!strict
-- check-literals: fails when services, logic or controllers contain a number that belongs in config (plan section 5.2).
--
-- Tuning values live in `src/shared/Config`, so a rebalance edits one data file and never a rule. This scans every
-- `.luau` file in the folders below and reports each number other than 0, 1, 2 or -1. A line may keep a number when
-- it says why in a `-- const:` comment, for fixed facts such as an algorithm's constants.
--
-- State owned: none. Usage from the project root:
--     lune run check-literals

local fs = require("@lune/fs")

local literals = require("./lib/literals")

-- The folders the rule covers. Config, Util, Types and Network hold data or plumbing, not game rules.
local FOLDERS = { "src/server/Services", "src/shared/Logic", "src/client/Controllers" }

local checkLiterals = {}

local function collect(dir: string, into: { string })
	if not fs.isDir(dir) then
		return
	end
	local names = fs.readDir(dir)
	table.sort(names)
	for _, name in names do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			collect(full, into)
		elseif string.sub(name, -#".luau") == ".luau" then
			table.insert(into, full)
		end
	end
end

--[[
	Scans every covered file and prints each literal found.
	@return true when no file has a literal outside the rule
]]
function checkLiterals.run(): boolean
	local files: { string } = {}
	for _, folder in FOLDERS do
		collect(folder, files)
	end
	local count = 0
	for _, path in files do
		for _, finding in literals.scan(fs.readFile(path)) do
			count += 1
			print(`{path}:{finding.line}: the number {finding.text} belongs in src/shared/Config`)
		end
	end
	if count > 0 then
		print(
			`\n{count} number(s) found. Move each to a config file, or add a "-- const: <reason>" comment to its line.`
		)
		return false
	end
	print(`No stray numbers in {#files} file(s).`)
	return true
end

return checkLiterals
