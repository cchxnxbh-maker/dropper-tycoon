--!strict
-- Sources: every config data file, raw and unchecked. Code reads `Config` instead, which validates and freezes these.
-- Only the loader and `lune run validate-config` require this file.
--
-- State owned: none.
--
-- Usage:
--     local problems = Schema.validate(require("./Sources"))

local Types = require("../Types/Config")

local Sources: Types.Config = {
	Build = require("./Build"),
	Flags = require("./Flags"),
	Tuning = require("./Tuning"),
	Plots = require("./Plots"),
	Factory = require("./Factory"),
	Economy = require("./Economy"),
	Strings = require("./Strings"),
	Buildables = require("./Buildables"),
}

return Sources
