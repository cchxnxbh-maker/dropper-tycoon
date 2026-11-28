--!strict
-- Entry point for `lune run balance`. The work is in `tools/balance.luau`.

local process = require("@lune/process")

local balance = require("../tools/balance")

process.exit(if balance.run() then 0 else 1)
