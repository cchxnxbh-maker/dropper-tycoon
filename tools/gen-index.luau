--!strict
-- gen-index: writes the `init.luau` index of every registry folder (plan section 6).
--
-- The check runs it first: it rewrites any index that no longer matches its folder and fails, so a new config file
-- that was never indexed cannot slip through. Run `lune run gen-index` after adding or removing a registry file.
--
-- State owned: none. It writes the index files listed in FOLDERS. Usage from the project root:
--     lune run gen-index

local fs = require("@lune/fs")

local indexfile = require("./lib/indexfile")

-- Every registry folder: config registries, and one handler file per client request. Perks and Modifiers join here
-- when those systems arrive.
local FOLDERS = { "src/shared/Config/Buildables", "src/server/Net/Handlers" }

export type Outcome = "current" | "rewritten" | "broken"

local genIndex = {}

--[[
	Regenerates every index.
	@return "current" when nothing changed, "rewritten" when an index was stale and has been rewritten, "broken" when a
	folder holds a file name that cannot be an entry
]]
function genIndex.run(): Outcome
	local outcome: Outcome = "current"
	for _, folder in FOLDERS do
		local path = folder .. "/init.luau"
		local ok, result = pcall(function()
			return indexfile.render(indexfile.entries(fs.readDir(folder)))
		end)
		if not ok then
			print(`{folder}: {result}`)
			outcome = "broken"
		else
			local existing = if fs.isFile(path) then fs.readFile(path) else nil
			if existing ~= result then
				fs.writeFile(path, result)
				print(`Rewrote {path}: it did not match the files in its folder. Review it and commit it.`)
				if outcome == "current" then
					outcome = "rewritten"
				end
			end
		end
	end
	if outcome == "current" then
		print(`All {#FOLDERS} index file(s) are current.`)
	end
	return outcome
end

return genIndex
