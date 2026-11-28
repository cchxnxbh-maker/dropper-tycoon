--!strict
-- FactoryLayout: where the grey-box parts of each machine and each purchase pad go on a plot, and whether the factory
-- config fits on the plot (Phase 1, ADR 0021).
--
-- Every position is in studs from the plot's pivot, the centre of the base's top face, with y up and negative z
-- towards the front edge. PlotService turns them into parts with `pivot * CFrame.new(x, y, z)`; the client uses the
-- same numbers to draw items on the belt. Real models replace the boxes in Phase 2.
--
-- Pure Luau: no Roblox types, so Lune tests it.
--
-- State owned: none.
--
-- Usage:
--     for _, box in FactoryLayout.boxes(def, Config.Factory) do
--         makePart(box.name, box.size, pivot * CFrame.new(box.x, box.y, box.z), box.color)
--     end

local Types = require("../Types/Config")

export type Box = {
	name: string,
	-- Centre of the box.
	x: number,
	y: number,
	z: number,
	-- Full size along each axis.
	sx: number,
	sy: number,
	sz: number,
	-- Hex colour, like "#3A3F44".
	color: string,
}

local FactoryLayout = {}

local function box(name: string, x: number, y: number, z: number, sx: number, sy: number, sz: number, color: string)
	return { name = name, x = x, y = y, z = z, sx = sx, sy = sy, sz = sz, color = color }
end

--[[
	The point on the belt's top surface a given distance along the line.
	@param factory the factory config
	@param distance studs from the start of the conveyor
	@return x, y and z of that point
]]
function FactoryLayout.beltPoint(factory: Types.Factory, distance: number): (number, number, number)
	local line = factory.line
	return line.start.x + distance, line.height, line.start.z
end

--[[
	The grey-box parts that show one machine.
	@param def the machine's definition; its kind decides the shape
	@param factory the factory config
	@return the boxes, empty for a kind with no shape yet
]]
function FactoryLayout.boxes(def: Types.BuildableDef, factory: Types.Factory): { Box }
	local line = factory.line
	local colors = factory.colors
	local z = line.start.z
	local post = factory.postSize
	local sideZ = z + line.width / 2 + post / 2
	if def.kind == "Conveyor" then
		return {
			box(
				"Belt",
				line.start.x + line.length / 2,
				line.height / 2,
				z,
				line.length,
				line.height,
				line.width,
				colors.conveyor
			),
		}
	elseif def.kind == "Collector" then
		local size = factory.collectorSize
		local height = line.height + 1 -- const: the bin's rim stands one stud above the belt so items drop in
		return {
			box("Bin", line.start.x + line.length + size / 2, height / 2, z, size, height, size, colors.collector),
		}
	elseif def.kind == "Dropper" then
		local x = line.start.x + def.params.at
		local size = factory.dropperSize
		local centre = line.height + factory.dropperLift + size / 2
		local top = centre + size / 2
		return {
			box("Hopper", x, centre, z, size, size, size, colors.dropper),
			box("Post", x, top / 2, sideZ, post, top, post, colors.dropper),
		}
	elseif def.kind == "Upgrader" then
		local x = line.start.x + def.params.at
		local top = line.height + factory.upgraderClearance
		local span = line.width + 2 * post
		return {
			box("PostA", x, top / 2, sideZ, post, top, post, colors.upgrader),
			box("PostB", x, top / 2, z - line.width / 2 - post / 2, post, top, post, colors.upgrader),
			box("Bar", x, top + post / 2, z, post, post, span, colors.upgrader),
		}
	end
	return {}
end

--[[
	The purchase pad of one machine.
	@param def the machine's definition
	@param factory the factory config
	@return the pad's box
]]
function FactoryLayout.pad(def: Types.BuildableDef, factory: Types.Factory): Box
	local size = factory.padSize
	local thickness = factory.padThickness
	return box("Pad", def.pad.x, thickness / 2, def.pad.z, size, thickness, size, factory.colors.pad)
end

--[[
	How far a character's position may be from a pad's centre, across the ground, and still buy from it.
	@param factory the factory config
	@return the distance in studs: half the pad's diagonal plus the reach allowance
]]
function FactoryLayout.padRadius(factory: Types.Factory): number
	return factory.padSize * math.sqrt(2) / 2 + factory.padReach
end

--[[
	Checks that the factory fits on the plot: the line and collector inside the base, every dropper and upgrader on
	the belt, and every pad on the plot, off the line, off the spawn pad and clear of every other pad.
	@param factory the factory config
	@param plots the plot config
	@param buildables the buildable registry
	@param ids the buildable IDs, sorted, so problems come out in the same order every time
	@return one readable line per problem, empty when everything fits
]]
function FactoryLayout.problems(
	factory: Types.Factory,
	plots: Types.Plots,
	buildables: { [string]: Types.BuildableDef },
	ids: { string }
): { string }
	local problems: { string } = {}
	local half = plots.baseSize / 2
	local line = factory.line
	local lineEnd = line.start.x + line.length + factory.collectorSize
	if line.start.x < -half or lineEnd > half or math.abs(line.start.z) + factory.collectorSize / 2 > half then
		table.insert(problems, "Factory.line: the conveyor and collector must fit on the plot")
	end

	local padHalf = factory.padSize / 2
	local spawnZ = -half + plots.spawnInset
	local spawnClear = plots.spawnSize / 2 + padHalf
	local lineClear = math.max(line.width, factory.collectorSize) / 2 + padHalf
	for index, id in ids do
		local def = buildables[id]
		local at = def.params.at
		if at ~= nil and at >= line.length then
			table.insert(problems, `Buildables.{id}.params.at: must be on the belt, below {line.length}, got {at}`)
		end
		local pad = def.pad
		if math.abs(pad.x) + padHalf > half or math.abs(pad.z) + padHalf > half then
			table.insert(problems, `Buildables.{id}.pad: the pad must be on the plot`)
		end
		if math.abs(pad.x) < spawnClear and math.abs(pad.z - spawnZ) < spawnClear then
			table.insert(problems, `Buildables.{id}.pad: the pad overlaps the spawn pad`)
		end
		local onLineX = pad.x > line.start.x - padHalf and pad.x < lineEnd + padHalf
		if onLineX and math.abs(pad.z - line.start.z) < lineClear then
			table.insert(problems, `Buildables.{id}.pad: the pad overlaps the production line`)
		end
		for other = index + 1, #ids do
			local otherPad = buildables[ids[other]].pad
			if math.abs(pad.x - otherPad.x) < factory.padSize and math.abs(pad.z - otherPad.z) < factory.padSize then
				table.insert(problems, `Buildables.{id}.pad: the pad overlaps the pad of {ids[other]}`)
			end
		end
	end
	return problems
end

return FactoryLayout
