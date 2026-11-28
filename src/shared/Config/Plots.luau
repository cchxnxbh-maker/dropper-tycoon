--!strict
-- Plots: how many plots a server has, where they sit and how big they are (plan sections 4.4 and 10, task 10).
-- The plots sit in a ring around the origin, each facing the middle, so every sign is readable from the lobby spawn.
-- Distances are in studs. Colours are hex strings so the file stays plain data that Lune can read.
-- Ranges are checked by `Config/Schema.luau`. Read it through `Config`, which validates and freezes it.
--
-- State owned: none. Read-only data.
--
-- Usage:
--     local Config = require("../Config")
--     local layout = PlotLayout.ring(Config.Plots.count, Config.Plots.ringRadius)

local Types = require("../Types/Config")

local Plots: Types.Plots = {
	-- Plots per server. The experience's Max Players setting must match it, so nobody joins without a plot.
	count = 6,
	-- Distance from the origin to each plot's centre. The plan keeps the world within about 250 studs of the origin.
	ringRadius = 250,
	-- Width and depth of each square plot base. Neighbours are about 250 studs apart, so this leaves a wide path.
	baseSize = 160,
	-- Thickness of the plot base. It rests on the baseplate, so its top is this high above the ground.
	baseThickness = 1,
	-- How far in from the plot's front edge (the edge facing the middle) the spawn pad sits.
	spawnInset = 16,
	-- Side length of the square spawn pad, and how far it stands above the plot base.
	spawnSize = 8,
	padThickness = 0.4,
	-- The sign at the front edge, which names the owner.
	signWidth = 24,
	signHeight = 8,
	signThickness = 1,
	-- Height of the sign's bottom edge above the plot base.
	signLift = 4,
	colors = {
		base = "#6E9A5A",
		spawn = "#E3C35A",
		sign = "#2F3B45",
	},
}

return Plots
