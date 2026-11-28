--!strict
-- Factory: where the production line sits on every plot, and how the grey-box machines and items look (Phase 1).
-- Positions are in studs from the plot's pivot, the centre of its top face. Negative z is towards the front edge,
-- where the spawn pad is. The line winds back and forth across the back half (ADR 0023), ending near the front with
-- the collector, and the purchase pads fill the front half.
-- Colours are hex strings so the file stays plain data that Lune can read.
-- Ranges and fit (everything on the plot, nothing overlapping) are checked by `Config/Schema.luau`.
--
-- State owned: none. Read-only data.
--
-- Usage:
--     local Config = require("../Config")
--     local height = Config.Factory.line.height

local Types = require("../Types/Config")

local Factory: Types.Factory = {
	line = {
		-- The conveyor's corners, in order. It runs straight from each to the next, along x or z. Droppers and upgraders
		-- say how far along it they sit; the collector sits just past the last corner. Three rows of 120 studs joined
		-- by two bends of 20 make 400 studs: the back row from 0 to 120, the middle from 140 to 260, the front from 280.
		path = {
			{ x = 60, z = 55 },
			{ x = -60, z = 55 },
			{ x = -60, z = 35 },
			{ x = 60, z = 35 },
			{ x = 60, z = 15 },
			{ x = -60, z = 15 },
		},
		-- Height of the belt's top above the plot.
		height = 3,
		-- Width of the belt.
		width = 4,
	},
	-- Side length of the collector, the bin at the end of the line that turns items into cash.
	collectorSize = 8,
	-- Side length of a dropper's box, and how far above the belt it hangs.
	dropperSize = 3,
	dropperLift = 5,
	-- Gap between the belt and the bar of an upgrader's arch.
	upgraderClearance = 4,
	-- Thickness of the posts that hold up droppers and upgraders.
	postSize = 1,
	-- Side length of one box item.
	itemSize = 1.2,
	-- Side length and thickness of a purchase pad.
	padSize = 6,
	padThickness = 0.4,
	-- A character may stand this far beyond a pad's edge and still buy from it, to allow for lag (plan section 4.4).
	padReach = 8,
	-- Standing on a pad you cannot afford asks again after this many seconds, so it buys once the cash is there.
	-- On a pad that sells levels, staying on it keeps buying them at this pace.
	padRetrySeconds = 0.5,
	-- Box items one dropper may show at once. Draw-side only.
	maxItemsPerDropper = 40,
	colors = {
		conveyor = "#3A3F44",
		collector = "#2E6E9E",
		dropper = "#9A9EA3",
		upgrader = "#C8873A",
		item = "#E8D9A8",
		pad = "#4CAF50",
	},
}

return Factory
