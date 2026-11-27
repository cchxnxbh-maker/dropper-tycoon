--!strict
-- Specs for literals: which numbers are reported, and that comments, strings and names are skipped.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local literals = require("../../../tools/lib/literals")

local function texts(source: string): { string }
	local out = {}
	for _, finding in literals.scan(source) do
		table.insert(out, `{finding.line}:{finding.text}`)
	end
	return out
end

describe("literals.scan", function()
	it("reports numbers other than 0, 1 and 2, with their line", function()
		expect(texts("local a = 0\nlocal b = -1 + 2\nlocal c = 3\nlocal d = 0.5")).toEqual({ "3:3", "4:0.5" })
	end)

	it("reads hex, binary, exponents and underscores", function()
		expect(texts("x = 0xFF + 0b101 + 1e3 + 1_000 + .25 + 2.0")).toEqual({
			"1:0xFF",
			"1:0b101",
			"1:1e3",
			"1:1_000",
			"1:.25",
		})
	end)

	it("skips names with digits, strings and comments", function()
		local source = table.concat({
			"local u32 = bit32.band(x, y) -- 99 in a comment",
			"local s = \"7 days\" .. '8' .. [[9]] .. [==[10]==]",
			"--[[ 11",
			"12 ]]",
		}, "\n")
		expect(texts(source)).toEqual({})
	end)

	it("skips backtick text but checks the code inside braces", function()
		expect(texts("local s = `3 items {count + 4} and {`{5}`} left`")).toEqual({ "1:4", "1:5" })
	end)

	it("allows a number on a line with a const: comment", function()
		expect(texts("local SHIFT = 13 -- const: xorshift constant\nlocal x = 14")).toEqual({ "2:14" })
	end)

	it("counts lines through multi-line strings and comments", function()
		expect(texts("--[[\n\n]]\nlocal s = [[\n]]\nx = 5")).toEqual({ "6:5" })
	end)
end)
