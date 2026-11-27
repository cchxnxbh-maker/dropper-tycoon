--!strict
-- Specs for Guard: plain data passes; NaN, infinity, negatives, huge text, deep or wide tables and Roblox values fail.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Config = require("../../../src/shared/Config")
local Guard = require("../../../src/shared/Network/Guard")

local limits = Config.Tuning.Network

local function reason(payload: any): string?
	local _, why = Guard.check(payload)
	return why
end

describe("Guard", function()
	it("passes plain requests", function()
		expect((Guard.check({ buildableId = "CoalDropper", count = 3, confirm = true }))).toBe(true)
		expect((Guard.check(nil))).toBe(true)
		expect((Guard.check({ ids = { "a", "b" } }))).toBe(true)
	end)

	it("names NaN, infinity and negative numbers with their path", function()
		expect(reason({ n = 0 / 0 })).toBe("payload.n: NaN")
		expect(reason({ n = math.huge })).toBe("payload.n: infinite number")
		expect(reason({ n = -math.huge })).toBe("payload.n: infinite number")
		expect(reason({ list = { 1, -1 } })).toBe("payload.list.2: negative number")
	end)

	it("refuses text over the limit, as a value or a key", function()
		local long = string.rep("x", limits.maxStringLength + 1)
		expect((Guard.check(string.rep("x", limits.maxStringLength)))).toBe(true)
		expect(reason(long)).toBe(`payload: text longer than {limits.maxStringLength} characters`)
		expect(reason({ [long] = true })).toBe(`payload: key longer than {limits.maxStringLength} characters`)
	end)

	it("refuses tables that are too deep or too wide", function()
		local deep: any = {}
		local cursor = deep
		for _ = 1, limits.maxTableDepth do
			cursor.inner = {}
			cursor = cursor.inner
		end
		expect(reason(deep)).toBe(`payload.inner.inner.inner: tables nested deeper than {limits.maxTableDepth}`)
		local wide = {}
		for index = 1, limits.maxTableEntries + 1 do
			wide[index] = true
		end
		expect(reason(wide)).toBe(`payload: table with more than {limits.maxTableEntries} entries`)
	end)

	it("refuses keys that are not text or whole numbers", function()
		expect(reason({ [1.5] = true })).toBe("payload: key that is not text or a whole number")
		expect(reason({ [true :: any] = true })).toBe("payload: key that is not text or a whole number")
	end)

	it("refuses functions and other values that are not plain data", function()
		expect(reason(function() end)).toBe("payload: function is not plain data")
		expect(reason({ f = coroutine.create(function() end) })).toBe("payload.f: thread is not plain data")
	end)
end)
