--!strict
-- Entry point for `lune run check`. Lune looks for scripts in `.lune/`; the work is in `tools/check.luau`.

local process = require("@lune/process")

local check = require("../tools/check")

process.exit(if check.run() then 0 else 1)
