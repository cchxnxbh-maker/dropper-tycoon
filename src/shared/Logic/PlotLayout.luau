--!strict
-- PlotLayout: where each plot sits in the ring, and whether a plot config fits together (plan section 4.4, task 10).
--
-- Plot 1 sits on the +X axis and the rest follow counter-clockwise seen from above, evenly spaced. Each plot is turned
-- so its front faces the origin: a CFrame built as `CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)` has its look
-- vector pointing at the middle of the ring. That is where the spawn pad and the sign go.
--
-- Pure Luau: no Roblox types, so Lune tests it. PlotService turns these numbers into CFrames.
--
-- State owned: none.
--
-- Usage:
--     for _, slot in PlotLayout.ring(6, 250) do
--         local cframe = CFrame.new(slot.x, 0, slot.z) * CFrame.Angles(0, slot.yaw, 0)
--     end

export type Slot = {
	-- 1 to count.
	index: number,
	-- Centre of the plot on the ground plane, in studs.
	x: number,
	z: number,
	-- Turn about the vertical axis, in radians, that makes the plot face the origin.
	yaw: number,
}

-- The fields of `Config.Plots` this module reads.
export type Shape = {
	count: number,
	ringRadius: number,
	baseSize: number,
	spawnInset: number,
	spawnSize: number,
	signWidth: number,
}

local PlotLayout = {}

--[[
	The position and facing of every plot.
	@param count how many plots, at least 1
	@param radius distance from the origin to each plot's centre
	@return one slot per plot, in index order
]]
function PlotLayout.ring(count: number, radius: number): { Slot }
	local slots: { Slot } = {}
	for index = 1, count do
		local angle = (index - 1) * 2 * math.pi / count
		-- Facing the origin means the look vector (-sin yaw, -cos yaw) equals -(cos angle, sin angle).
		table.insert(slots, {
			index = index,
			x = radius * math.cos(angle),
			z = radius * math.sin(angle),
			yaw = math.pi / 2 - angle,
		})
	end
	return slots
end

--[[
	Checks the rules that span several plot fields, which a per-field range cannot.
	@param shape the plot config
	@return one readable line per problem, empty when the layout works
]]
function PlotLayout.problems(shape: Shape): { string }
	local problems: { string } = {}
	if shape.count > 1 then
		-- Centres of neighbouring plots are a chord apart. Squares turned to face the middle clear each other when
		-- the chord is at least their diagonal, which holds at any rotation.
		local chord = 2 * shape.ringRadius * math.sin(math.pi / shape.count)
		local diagonal = shape.baseSize * math.sqrt(2)
		if chord < diagonal then
			table.insert(
				problems,
				`Plots.baseSize: neighbouring plots overlap; centres are {string.format("%.0f", chord)} studs apart but`
					.. ` a plot needs {string.format("%.0f", diagonal)}. Make baseSize smaller or ringRadius larger`
			)
		end
	end
	if shape.signWidth > shape.baseSize then
		table.insert(problems, "Plots.signWidth: the sign is wider than the plot")
	end
	if shape.spawnInset < shape.spawnSize / 2 or shape.spawnInset > shape.baseSize / 2 then
		table.insert(problems, "Plots.spawnInset: the spawn pad must sit in the front half of the plot")
	end
	return problems
end

return PlotLayout
