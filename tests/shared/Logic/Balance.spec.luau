--!strict
-- Specs for Balance: the real config buys everything inside the pacing targets, and broken pacing is reported in
-- plain words.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Balance = require("../../../src/shared/Logic/Balance")
local Config = require("../../../src/shared/Config")

local function machine(
	id: string,
	kind: string,
	price: number,
	requires: { string },
	params: any,
	levelPrice: number?
): any
	return {
		levelPrice = levelPrice,
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

-- A straight line 90 studs long, so a belt of speed 90 carries an item in one second.
local straight: any = table.clone(Config.Factory)
straight.line = { path = { { x = -45, z = 30 }, { x = 45, z = 30 } }, height = 3, width = 4 }

-- A tiny factory: a free belt, bin and dropper paying 1 a second, then a dropper costing `price`. With `levelPrice`,
-- the first dropper sells levels too, up to level 3.
local function tiny(price: number, levelPrice: number?): any
	return {
		Buildables = {
			Belt = machine("Belt", "Conveyor", 0, {}, { speed = 90 }),
			Bin = machine("Bin", "Collector", 0, { "Belt" }, { multiplier = 1 }),
			Coal = machine(
				"Coal",
				"Dropper",
				0,
				{ "Bin" },
				{ itemValue = 1, interval = 1, at = 0, perLevel = 1 },
				levelPrice
			),
			Gold = machine("Gold", "Dropper", price, { "Coal" }, { itemValue = 5, interval = 1, at = 0 }),
		},
		Factory = straight,
		Tuning = Config.Tuning,
		Economy = {
			maxCash = 1e15,
			devCashGift = 1,
			levels = { maxLevel = 3, priceGrowth = 2 },
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

	it("buys a level when it is the cheapest thing on offer, and stops once every machine is owned", function()
		local report = Balance.run(tiny(20, 4))
		local bought: { string } = {}
		for _, buy in report.buys do
			table.insert(bought, if buy.upgrade then `{buy.id}:{buy.level}` else buy.id)
		end
		-- Level 2 costs 4 and level 3 costs 8, both cheaper than Gold; Gold ends the run.
		expect(bought).toEqual({ "Belt", "Bin", "Coal", "Coal:2", "Coal:3", "Gold" })
		expect(report.buys[4].rate).toBeCloseTo(2, 1e-9)
		expect(report.buys[5].rate).toBeCloseTo(3, 1e-9)
		expect(report.finished).toBe(true)
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
