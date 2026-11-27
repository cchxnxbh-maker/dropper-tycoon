--!strict
-- Specs for Rng: fixed reference sequences (checked against an independent implementation), stream independence,
-- ranges, and the session seed rules.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Rng = require("../../../src/shared/Logic/Rng")

local function draws(generator: Rng.Generator, count: number): { number }
	local out = {}
	for _ = 1, count do
		table.insert(out, generator:nextU32())
	end
	return out
end

describe("Rng.new", function()
	-- These sequences pin the algorithm. If one changes, every saved repro bundle stops replaying: that needs an ADR.
	it("matches the reference xoshiro128** sequences", function()
		expect(draws(Rng.new(1), 5)).toEqual({ 3296685081, 292216795, 3203276040, 3343330025, 3022133357 })
		expect(draws(Rng.new(12345, "Loot"), 5)).toEqual({ 186699727, 3948883198, 2289436081, 482160202, 1448121127 })
		expect(draws(Rng.new(4294967295, "FactorySim"), 5)).toEqual({
			524147370,
			2088213076,
			2553591029,
			2157940774,
			4280355875,
		})
	end)

	it("gives different sequences for different names with the same seed", function()
		expect(draws(Rng.new(7, "A"), 3)).never.toEqual(draws(Rng.new(7, "B"), 3))
	end)

	it("rejects a fractional seed", function()
		expect(function()
			Rng.new(1.5)
		end).toThrow("whole number")
	end)
end)

describe("Generator", function()
	it("nextNumber stays in [0, 1)", function()
		local generator = Rng.new(99)
		for _ = 1, 10000 do
			local value = generator:nextNumber()
			expect(value >= 0 and value < 1).toBe(true)
		end
	end)

	it("nextInteger covers both ends and nothing outside", function()
		local generator = Rng.new(3)
		local seen: { [number]: boolean } = {}
		for _ = 1, 2000 do
			local value = generator:nextInteger(-2, 3)
			expect(value >= -2 and value <= 3 and value == math.floor(value)).toBe(true)
			seen[value] = true
		end
		for value = -2, 3 do
			expect(seen[value]).toBe(true)
		end
	end)

	it("nextInteger with min == max returns it", function()
		expect(Rng.new(1):nextInteger(4, 4)).toBe(4)
	end)

	it("nextInteger rejects bad ranges", function()
		local generator = Rng.new(1)
		expect(function()
			generator:nextInteger(5, 1)
		end).toThrow("max >= min")
		expect(function()
			generator:nextInteger(1, 2.5)
		end).toThrow("whole numbers")
	end)

	it("shuffle keeps every element and is repeatable", function()
		local first = { 1, 2, 3, 4, 5, 6, 7, 8 }
		local second = { 1, 2, 3, 4, 5, 6, 7, 8 }
		Rng.new(42):shuffle(first)
		Rng.new(42):shuffle(second)
		expect(first).toEqual(second)
		local sorted = table.clone(first)
		table.sort(sorted)
		expect(sorted).toEqual({ 1, 2, 3, 4, 5, 6, 7, 8 })
	end)

	it("pick returns an element and rejects an empty array", function()
		local value = Rng.new(5):pick({ "a", "b", "c" })
		expect(value == "a" or value == "b" or value == "c").toBe(true)
		expect(function()
			Rng.new(5):pick({})
		end).toThrow("non-empty")
	end)
end)

describe("Rng.stream", function()
	it("returns the same generator for the same name", function()
		Rng.seed(10)
		expect(Rng.stream("Loot")).toBe(Rng.stream("Loot"))
	end)

	it("does not depend on the order streams are used in", function()
		Rng.seed(2024)
		local lootFirst = draws(Rng.stream("Loot"), 4)
		local weatherSecond = draws(Rng.stream("Weather"), 4)

		Rng.seed(2024)
		local weatherFirst = draws(Rng.stream("Weather"), 4)
		local lootSecond = draws(Rng.stream("Loot"), 4)

		expect(lootFirst).toEqual(lootSecond)
		expect(weatherSecond).toEqual(weatherFirst)
	end)

	it("restarts every stream when the seed is set again", function()
		Rng.seed(8)
		local before = draws(Rng.stream("A"), 3)
		Rng.seed(8)
		expect(draws(Rng.stream("A"), 3)).toEqual(before)
		expect(Rng.sessionSeed()).toBe(8)
	end)
end)
