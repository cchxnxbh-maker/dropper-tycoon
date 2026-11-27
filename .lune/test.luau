--!strict
-- Entry point for `lune run test [filter]`, which runs only the unit tests. The work is in `tools/test.luau`.

local process = require("@lune/process")

local test = require("../tools/test")

process.exit(if test.runAll(process.args[1]) then 0 else 1)
