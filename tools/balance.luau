--!strict
-- balance: plays a fresh factory from config and fails if the pacing targets break (plan section 5.2, guard 3; ADR
-- 0022, ADR 0023). Prints one line per new machine: when it was bought, the longest the player saved for anything
-- since the line before, how many levels they bought in between, and the income after.
--
-- The simulation is `src/shared/Logic/Balance.luau`, run on the real config, so this shows the game's own numbers.
--
-- State owned: none. Usage from the project root:
--     lune run balance

local Balance = require("../src/shared/Logic/Balance")
local Config = require("../src/shared/Config")
local NumberFormat = require("../src/shared/Logic/NumberFormat")

local balance = {}

local function clock(seconds: number): string
	local whole = math.floor(seconds)
	return string.format("%2d:%02d", whole // 60, whole % 60)
end

--[[
	Runs the simulation, prints the report and checks it.
	@return true when every pacing target holds
]]
function balance.run(): boolean
	local report = Balance.run(Config)
	print("  time   longest  levels  machine              price      income after")
	local longest = 0
	local levels = 0
	local slowest = 0
	for _, buy in report.buys do
		longest = math.max(longest, buy.waited)
		slowest = math.max(slowest, buy.waited)
		if buy.upgrade then
			levels += 1
		else
			print(
				string.format(
					"  %s  %5ds  %6d  %-20s %-10s +%s/s",
					clock(buy.at),
					math.round(longest),
					levels,
					buy.id,
					"$" .. NumberFormat.cash(buy.price),
					NumberFormat.rate(buy.rate)
				)
			)
			longest = 0
			levels = 0
		end
	end
	print(`  {#report.buys} purchases. Longest wait {math.round(slowest)} s.`)
	print(`  Everything bought in {clock(report.seconds)} (walking time not counted).`)
	local problems = Balance.problems(report, Config.Economy)
	if #problems > 0 then
		print(`Pacing has {#problems} problem(s). Change prices or machine values in src/shared/Config:`)
		for _, problem in problems do
			print("  " .. problem)
		end
		return false
	end
	print("Pacing is inside the targets in Economy.pacing.")
	return true
end

return balance
