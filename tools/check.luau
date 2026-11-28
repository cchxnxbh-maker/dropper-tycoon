--!strict
-- check: the one command that decides whether a change is acceptable (plan section 7.5, ADR 0015).
--
-- Runs each step in order and stops at the first failure. The pre-commit hook and GitHub Actions run the same thing
-- through `.lune/check.luau`, so a pass on Daniel's PC, in a cloud session and in CI means the same.
--
-- State owned: none. It writes `sourcemap.json` and caches the Roblox type definitions under `.cache/`, both
-- ignored by Git. Usage from the project root:
--     lune run check

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local balance = require("./balance")
local checkLiterals = require("./check-literals")
local genIndex = require("./gen-index")
local test = require("./test")
local validateConfig = require("./validate-config")

-- Folders holding Luau that StyLua and Selene look at.
local LUAU_FOLDERS = { "src", "tests", "tools", ".lune" }
-- What luau-lsp type-checks. The other tools files use Lune's own libraries, which luau-lsp does not know here, so
-- their pure parts live in `tools/lib`.
local ANALYZE_PATHS = { "src", "tests", "tools/testkit.luau", "tools/lib" }
local CACHE_DIR = ".cache"
local SOURCEMAP = "sourcemap.json"
local DEFINITIONS_FILE = "globalTypes.None.d.luau"
local DEFINITIONS_URL = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/%s/scripts/" .. DEFINITIONS_FILE

type Step = { name: string, run: () -> boolean }

local check = {}

local function joined(...: { string }): { string }
	local out = {}
	for _, list in { ... } do
		for _, item in list do
			table.insert(out, item)
		end
	end
	return out
end

-- Runs a tool with its output shown as it happens. A missing tool counts as a failure with a hint.
local function exec(program: string, args: { string }): boolean
	local ok, result = pcall(process.exec, program, args, { stdio = "inherit" })
	if not ok then
		print(`Could not start {program}: {result}`)
		print("Run `rokit install` in the project folder, then try again.")
		return false
	end
	return result.ok
end

-- The luau-lsp version pinned in rokit.toml, so the type definitions always match the analyzer.
local function luauLspVersion(): string?
	local pins = fs.readFile("rokit.toml")
	return string.match(pins, 'luau%-lsp%s*=%s*"[^"@]+@([^"]+)"')
end

-- Path to the Roblox type definitions for the pinned luau-lsp, downloading them once if they are not cached.
local function definitions(): string?
	local version = luauLspVersion()
	if version == nil then
		print("rokit.toml has no luau-lsp pin.")
		return nil
	end
	local dir = `{CACHE_DIR}/luau-lsp-{version}`
	local path = `{dir}/{DEFINITIONS_FILE}`
	if fs.isFile(path) then
		return path
	end
	local url = string.format(DEFINITIONS_URL, version)
	print(`Downloading Roblox type definitions for luau-lsp {version}`)
	local ok, response = pcall(net.request, url)
	if not ok or not response.ok then
		local reason = if ok then `HTTP {response.statusCode}` else tostring(response)
		print(`Could not download {url}: {reason}`)
		return nil
	end
	fs.writeDir(dir)
	fs.writeFile(path, response.body)
	return path
end

local function typeCheck(): boolean
	local defs = definitions()
	if defs == nil then
		return false
	end
	if not exec("rojo", { "sourcemap", "default.project.json", "--output", SOURCEMAP }) then
		return false
	end
	local args = {
		"analyze",
		`--sourcemap={SOURCEMAP}`,
		`--definitions=@roblox={defs}`,
		"--ignore=Packages/**",
		"--ignore=**/Packages/**",
		-- Vendored code is kept byte for byte (ADR 0019); its exported types are still used by the code that requires it.
		"--ignore=src/server/Vendor/**",
	}
	return exec("luau-lsp", joined(args, ANALYZE_PATHS))
end

check.steps = {
	{
		name = "Indexes (gen-index)",
		run = function()
			return genIndex.run() == "current"
		end,
	},
	{
		name = "Format (StyLua)",
		run = function()
			return exec("stylua", joined({ "--check" }, LUAU_FOLDERS))
		end,
	},
	{
		name = "Lint (Selene)",
		run = function()
			return exec("selene", LUAU_FOLDERS)
		end,
	},
	{ name = "Types (Rojo sourcemap, luau-lsp)", run = typeCheck },
	-- The boundary and docs checks join here, and `balance` after validate-config, as their systems arrive.
	{ name = "No stray numbers (check-literals)", run = checkLiterals.run },
	{ name = "Config values (validate-config)", run = validateConfig.run },
	{ name = "Pacing (balance)", run = balance.run },
	{
		name = "Unit tests (Lune)",
		run = function()
			return test.runAll(nil)
		end,
	},
} :: { Step }

--[[
	Runs every step in order, stopping at the first failure.
	@return true when all steps passed
]]
function check.run(): boolean
	local total = #check.steps
	for index, step in check.steps do
		print(`\n[{index}/{total}] {step.name}`)
		local started = os.clock()
		local ok, result = pcall(step.run)
		local seconds = string.format("%.1fs", os.clock() - started)
		if not ok then
			print(`Step crashed: {result}`)
		end
		if not (ok and result) then
			print(`\nCheck FAILED at step {index}, {step.name} ({seconds}). Fix the problem above and run it again.`)
			return false
		end
		print(`ok ({seconds})`)
	end
	print(`\nCheck passed: all {total} steps.`)
	return true
end

return check
