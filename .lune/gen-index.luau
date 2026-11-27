--!strict
-- Entry point for `lune run gen-index`. The work is in `tools/gen-index.luau`. Exits 1 only when a registry folder holds a
-- file name that cannot be an entry. (The check, by contrast, also fails when an index had to be rewritten.)

local process = require("@lune/process")

local genIndex = require("../tools/gen-index")

process.exit(if genIndex.run() == "broken" then 1 else 0)
