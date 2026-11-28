--!strict
-- Specs for Balance: the real config buys everything inside the pacing targets, and broken pacing is reported in
-- plain words.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Balance = require("../../../src/shared/Logic/Balance")
local Config = require("../../../src/shared/Config")

local function machine(id: string, kind: string, price: number, requires: { string }, params: any): any
	return {
		id = id,
		kind = kind,
		tier = 1,
		price = price,
		requires = requires,
		line = "Main",
		params = params,
		pad = {
			x = 0,
			z = 0,
		},
	}
end

-- A tiny factory: a free belt, bin and dropper paying 1 a second, then a dropper costing `price`.
local function tiny(price: number): any
	return {
		Buildables = {
			Belt = machine("Belt", "Conveyor", 0, {}, { speed = 90 }),
			Bin = machine("Bin", "Collector", 0, { "Belt" }, { multiplier = 1 }),
			Coal = machine("Coal", "Dropper", 0, { "Bin" }, { itemValue = 1, interval = 1, at = 0 }),
			Gold = machine("Gold", "Dropper", price, { "Coal" }, { itemValue = 5, interval = 1, at = 0 }),
		},
		Factory = Config.Factory,
		Tuning = Config.Tuning,
		Economy = {
			maxCash = 1e15,
			devCashGift = 1,
			pacing = { maxWaitSeconds = 60, minTotalMinutes = 0, maxTotalMinutes = 10 },
		},
	}
end

describe("Balance", function()
	it("buys the free machines at once and the rest when the cash is there", function()
		local report = Balance.run(tiny(20))
		expect(report.finished).toBe(true)
		expect(#report.buys).toBe(4)
		expect(report.buys[3].at).toBe(0)
		-- One a second, after the first item's 1-second ride: 20 cash by second 20 or 21.
		local gold = report.buys[4]
		expect(gold.id).toBe("Gold")
		expect(gold.at >= 20 and gold.at <= 21).toBe(true)
		expect(gold.rate).toBeCloseTo(6, 1e-9)
		expect(Balance.problems(report, tiny(20).Economy)).toEqual({})
	end)

	it("reports a wait over the limit", function()
		local config = tiny(100)
		local problems = Balance.problems(Balance.run(config), config.Economy)
		expect(#problems).toBe(1)
		expect(string.find(problems[1], "Gold: waited", 1, true) ~= nil).toBe(true)
	end)

	it("reports a factory that never finishes", function()
		local config = tiny(1e9)
		local report = Balance.run(config)
		expect(report.finished).toBe(false)
		expect(report.unbought).toEqual({ "Gold" })
		expect(Balance.problems(report, config.Economy)[1]).toBe("never bought Gold: the factory stalls")
	end)

	it("keeps the real config inside the pacing targets", function()
		local report = Balance.run(Config)
		expect(report.finished).toBe(true)
		expect(Balance.problems(report, Config.Economy)).toEqual({})
	end)
end)
