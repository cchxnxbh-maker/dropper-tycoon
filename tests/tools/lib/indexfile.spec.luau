--!strict
-- Specs for indexfile: which files become entries, rejected names, and the exact generated text.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local indexfile = require("../../../tools/lib/indexfile")

describe("indexfile.entries", function()
	it("keeps .luau files other than the index, sorted, without the suffix", function()
		expect(indexfile.entries({ "init.luau", "Iron.luau", "notes.md", "Coal.luau" })).toEqual({ "Coal", "Iron" })
	end)

	it("rejects a file name that cannot be an ID", function()
		expect(function()
			indexfile.entries({ "Coal Dropper.luau" })
		end).toThrow("letters and digits only")
	end)
end)

describe("indexfile.render", function()
	it("requires each entry by name", function()
		local text = indexfile.render({ "Coal", "Iron" })
		expect((string.find(text, '\tCoal = require("@self/Coal"),\n\tIron = require("@self/Iron"),\n', 1, true))).never.toBeNil()
		expect(string.sub(text, 1, 10)).toBe("--!strict\n")
	end)

	it("writes an empty table when the folder has no entries", function()
		expect((string.find(indexfile.render({}), "local index: { [string]: any } = {}\n\nreturn index\n", 1, true))).never.toBeNil()
	end)
end)
