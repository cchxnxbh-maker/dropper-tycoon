--!strict
-- validate-config: checks every config file against `Config/Schema.luau` and prints each problem (plan section 5.2).
--
-- Uses the same rules the game runs at startup, so a value that passes here loads in Studio, and one that fails here
-- would have stopped the game with the same message. Later tasks add cross-file checks here: prerequisites that exist
-- and do not loop, a string for every key, three bindings per action, a model for every machine.
--
-- State owned: none. Usage from the project root:
--     lune run validate-config

local Schema = require("../src/shared/Config/Schema")

local validateConfig = {}

--[[
	Loads the raw config files and checks them.
	@return true when there are no problems; a file that fails to load counts as a problem
]]
function validateConfig.run(): boolean
	local loaded, sources = pcall(require, "../src/shared/Config/Sources")
	if not loaded then
		print(`A config file could not be loaded: {sources}`)
		return false
	end
	local problems = Schema.validate(sources)
	if #problems > 0 then
		print(Schema.report(problems))
		return false
	end
	print("Config is valid.")
	return true
end

return validateConfig
