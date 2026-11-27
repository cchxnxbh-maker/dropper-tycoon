--!strict
-- Build: the version of this build (plan section 7.6). Bumped on release, together with the changelog and a Git tag.
-- It appears in the settings screen and on every log line. Read it through `Config`.
--
-- State owned: none. Read-only data.
--
-- Usage:
--     local Config = require("../Config")
--     print(Config.Build.version)

local Types = require("../Types/Config")

local Build: Types.Build = {
	version = "0.0.0",
}

return Build
