--!strict
-- Entry point for `lune run validate-config`. The work is in `tools/validate-config.luau`.

local process = require("@lune/process")

local validateConfig = require("../tools/validate-config")

process.exit(if validateConfig.run() then 0 else 1)
