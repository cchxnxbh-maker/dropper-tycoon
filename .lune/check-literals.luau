--!strict
-- Entry point for `lune run check-literals`. The work is in `tools/check-literals.luau`.

local process = require("@lune/process")

local checkLiterals = require("../tools/check-literals")

process.exit(if checkLiterals.run() then 0 else 1)
