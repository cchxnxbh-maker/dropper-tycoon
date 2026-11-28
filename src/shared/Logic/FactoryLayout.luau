--!strict
-- FactoryLayout: where the grey-box parts of each machine and each purchase pad go on a plot, and whether the factory
-- config fits on the plot (Phase 1, ADR 0021, ADR 0023).
--
-- The conveyor follows `Factory.line.path`: corners joined by straight runs along x or z, so the line can wind across
-- the plot. A machine's `at` is its distance along that path. Every position is in studs from the plot's pivot, the
-- centre of the base's top face, with y up and negative z towards the front edge. PlotService turns them into parts
-- with `pivot * CFrame.new(x, y, z)`; the client uses the same numbers to draw items on the belt. Real models replace
-- the boxes in Phase 2.
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

-- Length and unit direction of the run from corner `index` to the next.
local function run(path: { Types.PlotPoint }, index: number): (number, number, number)
	local a, b = path[index], path[index + 1]
	local dx, dz = b.x - a.x, b.z - a.z
	local length = math.abs(dx) + math.abs(dz)
	if length == 0 then
		return 0, 1, 0
	end
	return length, dx / length, dz / length
end

--[[
	@param factory the factory config
	@return the conveyor's length in studs, along its whole path
]]
function FactoryLayout.length(factory: Types.Factory): number
	local path = factory.line.path
	local total = 0
	for index = 1, #path - 1 do
		total += (run(path, index))
	end
	return total
end

--[[
	The point on the belt's top surface a given distance along the line, and the way the belt runs there.
	@param factory the factory config
	@param distance studs from the start of the conveyor; clamped to the line
	@return x, y and z of that point, then the x and z of the belt's direction (one of them is 0)
]]
function FactoryLayout.beltPoint(factory: Types.Factory, distance: number): (number, number, number, number, number)
	local line = factory.line
	local path = line.path
	local left = math.max(0, distance)
	local last = #path - 1
	for index = 1, last do
		local length, dx, dz = run(path, index)
		if left <= length or index == last then
			local along = math.min(left, length)
			local a = path[index]
			return a.x + dx * along, line.height, a.z + dz * along, dx, dz
		end
		left -= length
	end
	local only = path[1]
	return only.x, line.height, only.z, 1, 0
end

-- Distances along the line of every bend.
local function bends(factory: Types.Factory): { number }
	local path = factory.line.path
	local list: { number } = {}
	local total = 0
	for index = 1, #path - 2 do
		total += (run(path, index))
		table.insert(list, total)
	end
	return list
end

-- The belt's boxes, one per straight run. Each run after the first starts half a belt past its corner, and each run
-- before the last reaches half a belt past its end, so corners are filled once and no two boxes overlap.
local function beltBoxes(factory: Types.Factory): { Box }
	local line = factory.line
	local path = line.path
	local half = line.width / 2
	local boxes: { Box } = {}
	local last = #path - 1
	for index = 1, last do
		local length, dx, dz = run(path, index)
		local a = path[index]
		local from = if index == 1 then 0 else half
		local to = if index == last then length else length + half
		local mid = (from + to) / 2
		local span = to - from
		local sx = if dx ~= 0 then span else line.width
		local sz = if dz ~= 0 then span else line.width
		table.insert(
			boxes,
			box(
				`Belt{index}`,
				a.x + dx * mid,
				line.height / 2,
				a.z + dz * mid,
				sx,
				line.height,
				sz,
				factory.colors.conveyor
			)
		)
	end
	return boxes
end

-- Centre of the collector: just past the end of the line, in the direction it runs.
local function collectorCentre(factory: Types.Factory): (number, number)
	local x, _, z, dx, dz = FactoryLayout.beltPoint(factory, FactoryLayout.length(factory))
	local reach = factory.collectorSize / 2
	return x + dx * reach, z + dz * reach
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
	local post = factory.postSize
	local side = line.width / 2 + post / 2
	if def.kind == "Conveyor" then
		return beltBoxes(factory)
	elseif def.kind == "Collector" then
		local size = factory.collectorSize
		local height = line.height + 1 -- const: the bin's rim stands one stud above the belt so items drop in
		local x, z = collectorCentre(factory)
		return {
			box("Bin", x, height / 2, z, size, height, size, colors.collector),
		}
	elseif def.kind == "Dropper" then
		local x, _, z, dx, dz = FactoryLayout.beltPoint(factory, def.params.at)
		-- The post stands beside the belt on its right as the belt runs, leaving the left for the pad.
		local nx, nz = dz, -dx
		local size = factory.dropperSize
		local centre = line.height + factory.dropperLift + size / 2
		local top = centre + size / 2
		return {
			box("Hopper", x, centre, z, size, size, size, colors.dropper),
			box("Post", x + nx * side, top / 2, z + nz * side, post, top, post, colors.dropper),
		}
	elseif def.kind == "Upgrader" then
		local x, _, z, dx, dz = FactoryLayout.beltPoint(factory, def.params.at)
		local nx, nz = -dz, dx
		local top = line.height + factory.upgraderClearance
		local span = line.width + 2 * post
		return {
			box("PostA", x + nx * side, top / 2, z + nz * side, post, top, post, colors.upgrader),
			box("PostB", x - nx * side, top / 2, z - nz * side, post, top, post, colors.upgrader),
			box(
				"Bar",
				x,
				top + post / 2,
				z,
				if dx ~= 0 then post else span,
				post,
				if dx ~= 0 then span else post,
				colors.upgrader
			),
		}
	end
	return {}
end

--[[
	How good a machine is among others of its kind that take the same place on the line. Only the best one is shown,
	matching the simulation, which runs at the fastest conveyor and pays by the best collector.
	@param def the machine
	@return its speed for a conveyor, its multiplier for a collector; nil for kinds that each take their own place
]]
function FactoryLayout.rank(def: Types.BuildableDef): number?
	if def.kind == "Conveyor" then
		return def.params.speed
	elseif def.kind == "Collector" then
		return def.params.multiplier
	end
	return nil
end

--[[
	Where a machine's purchase pad sits. A machine on the belt (with an `at` param) has its pad beside the belt next to
	it, on the belt's left as it runs, `padGap` from the belt's edge. Any other machine uses its own `pad`.
	@param def the machine's definition
	@param factory the factory config
	@return the pad's centre in plot studs; nil for a machine off the belt with no `pad` (config checks report it)
]]
function FactoryLayout.padPoint(def: Types.BuildableDef, factory: Types.Factory): Types.PlotPoint?
	local at = def.params.at
	if at == nil then
		return def.pad
	end
	local x, _, z, dx, dz = FactoryLayout.beltPoint(factory, at)
	local offset = factory.line.width / 2 + factory.padGap + factory.padSize / 2
	return { x = x - dz * offset, z = z + dx * offset }
end

--[[
	The purchase pad of one machine.
	@param def the machine's definition
	@param factory the factory config
	@return the pad's box; at the plot's centre for a machine with no pad position, which config checks refuse
]]
function FactoryLayout.pad(def: Types.BuildableDef, factory: Types.Factory): Box
	local size = factory.padSize
	local thickness = factory.padThickness
	local point = FactoryLayout.padPoint(def, factory) or { x = 0, z = 0 }
	return box("Pad", point.x, thickness / 2, point.z, size, thickness, size, factory.colors.pad)
end

--[[
	How far a character's position may be from a pad's centre, across the ground, and still buy from it.
	@param factory the factory config
	@return the distance in studs: half the pad's diagonal plus the reach allowance
]]
function FactoryLayout.padRadius(factory: Types.Factory): number
	return factory.padSize * math.sqrt(2) / 2 + factory.padReach
end

type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

-- The ground rectangles the line covers: each run, a belt wide, and the collector.
local function footprints(factory: Types.Factory): { Rect }
	local rects: { Rect } = {}
	local path = factory.line.path
	local half = factory.line.width / 2
	for index = 1, #path - 1 do
		local a, b = path[index], path[index + 1]
		table.insert(rects, {
			minX = math.min(a.x, b.x) - half,
			maxX = math.max(a.x, b.x) + half,
			minZ = math.min(a.z, b.z) - half,
			maxZ = math.max(a.z, b.z) + half,
		})
	end
	local cx, cz = collectorCentre(factory)
	local reach = factory.collectorSize / 2
	table.insert(rects, { minX = cx - reach, maxX = cx + reach, minZ = cz - reach, maxZ = cz + reach })
	return rects
end

local function pathProblems(factory: Types.Factory, half: number): { string }
	local problems: { string } = {}
	local path = factory.line.path
	if #path < 2 then
		table.insert(problems, "Factory.line.path: needs at least two corners")
		return problems
	end
	for index = 1, #path - 1 do
		local a, b = path[index], path[index + 1]
		if (a.x ~= b.x) == (a.z ~= b.z) then
			table.insert(
				problems,
				`Factory.line.path[{index + 1}]: each run must go straight along x or z from the corner before`
			)
		end
	end
	for _, rect in footprints(factory) do
		if rect.minX < -half or rect.maxX > half or rect.minZ < -half or rect.maxZ > half then
			table.insert(problems, "Factory.line: the conveyor and collector must fit on the plot")
			break
		end
	end
	return problems
end

-- Machines with a place on the line: each must be on the belt, off the bends, and clear of the others.
local function spotProblems(
	factory: Types.Factory,
	buildables: { [string]: Types.BuildableDef },
	ids: { string }
): { string }
	local problems: { string } = {}
	local length = FactoryLayout.length(factory)
	local corners = bends(factory)
	local gap = factory.dropperSize
	local placed: { string } = {}
	for _, id in ids do
		local at = buildables[id].params.at
		if at ~= nil then
			if at >= length then
				table.insert(problems, `Buildables.{id}.params.at: must be on the belt, below {length}, got {at}`)
			end
			for _, corner in corners do
				if math.abs(at - corner) < factory.line.width then
					table.insert(problems, `Buildables.{id}.params.at: too close to the bend at {corner}`)
				end
			end
			for _, other in placed do
				if math.abs(at - buildables[other].params.at) < gap then
					table.insert(problems, `Buildables.{id}.params.at: too close to {other} on the belt`)
				end
			end
			table.insert(placed, id)
		end
	end
	return problems
end

--[[
	Checks that the factory fits on the plot: the line runs straight between corners and stays on the base with its
	collector, every dropper and upgrader sits on the belt away from bends and other machines, and every pad is on the
	plot, off the line, off the spawn pad and clear of every other pad.
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
	local half = plots.baseSize / 2
	local problems = pathProblems(factory, half)
	if #factory.line.path < 2 then
		return problems
	end
	for _, problem in spotProblems(factory, buildables, ids) do
		table.insert(problems, problem)
	end

	local padHalf = factory.padSize / 2
	local spawnZ = -half + plots.spawnInset
	local spawnClear = plots.spawnSize / 2 + padHalf
	local rects = footprints(factory)
	local pads: { [string]: Types.PlotPoint } = {}
	for _, id in ids do
		local point = FactoryLayout.padPoint(buildables[id], factory)
		if point then
			pads[id] = point
		else
			table.insert(
				problems,
				`Buildables.{id}.pad: missing; a machine that is not on the belt needs a pad position`
			)
		end
	end
	for index, id in ids do
		local pad = pads[id]
		if pad == nil then
			continue
		end
		if math.abs(pad.x) + padHalf > half or math.abs(pad.z) + padHalf > half then
			table.insert(problems, `Buildables.{id}.pad: the pad must be on the plot`)
		end
		if math.abs(pad.x) < spawnClear and math.abs(pad.z - spawnZ) < spawnClear then
			table.insert(problems, `Buildables.{id}.pad: the pad overlaps the spawn pad`)
		end
		for _, rect in rects do
			if
				pad.x > rect.minX - padHalf
				and pad.x < rect.maxX + padHalf
				and pad.z > rect.minZ - padHalf
				and pad.z < rect.maxZ + padHalf
			then
				table.insert(problems, `Buildables.{id}.pad: the pad overlaps the production line`)
				break
			end
		end
		for other = index + 1, #ids do
			local otherPad = pads[ids[other]]
			if
				otherPad
				and math.abs(pad.x - otherPad.x) < factory.padSize
				and math.abs(pad.z - otherPad.z) < factory.padSize
			then
				table.insert(problems, `Buildables.{id}.pad: the pad overlaps the pad of {ids[other]}`)
			end
		end
	end
	return problems
end

return FactoryLayout
