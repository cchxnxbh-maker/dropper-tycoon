--!strict
-- Flags: feature switches and log levels (plan sections 4.10 and 7.7, ADR 0012). They change by publishing.
-- Read it through `Config`, which validates and freezes it.
--
-- State owned: none. Read-only data.
--
-- Usage:
--     local Config = require("../Config")
--     if Config.Flags.Features.offlineEarnings then ... end

local Types = require("../Types/Config")

local Flags: Types.Flags = {
	-- Feature switches, named in camelCase. Each risky feature adds its switch here, set to false.
	Features = {
		-- Runs the network abuse suite at the start of every Studio playtest (task 8). Never runs on real servers.
		studioAbuseSuite = true,
	},
	-- Levels are debug, info, warn and error. Tags not listed use the default.
	Log = {
		default = "info",
		tags = {},
	},
}

return Flags
