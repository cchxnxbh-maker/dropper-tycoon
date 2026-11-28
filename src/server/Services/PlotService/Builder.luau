--!strict
-- PlotService/Builder: makes the parts of a plot (task 10) and of the factory on it (task 12). Split from PlotService
-- so that file keeps to who holds which plot. Parts are a display of what the services hold, never the truth.
--
-- State owned: none. It makes instances and hands them back.
--
-- Usage:
--     local plot = Builder.plot(slot, folder)
--     Builder.box(FactoryLayout.pad(def, Config.Factory), plot.pivot, plot.pads)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FactoryLayout = require(ReplicatedStorage.Shared.Logic.FactoryLayout)
local PlotLayout = require(ReplicatedStorage.Shared.Logic.PlotLayout)
local WorldKeys = require(ReplicatedStorage.Shared.Util.WorldKeys)

export type Plot = { index: number, model: Model, spawn: CFrame, pivot: CFrame, machines: Folder, pads: Folder }

-- How far above the spawn pad a character is placed, so its feet clear the pad. A fact of the default character size.
local SPAWN_CLEARANCE = 4 -- const: a standard character's hip height plus a margin, not a tuning value

local Attributes = WorldKeys.Attributes
local Parts = WorldKeys.PlotParts

local Builder = {}

local function part(name: string, size: Vector3, cframe: CFrame, color: string, parent: Instance): Part
	local made = Instance.new("Part")
	made.Name = name
	made.Anchored = true
	made.Size = size
	made.CFrame = cframe
	made.Color = Color3.fromHex(color)
	made.Material = Enum.Material.SmoothPlastic
	made.TopSurface = Enum.SurfaceType.Smooth
	made.BottomSurface = Enum.SurfaceType.Smooth
	made.Parent = parent
	return made
end

--[[
	Builds one empty plot in `folder`. Its pivot is the centre of the base's top face, turned to face the middle of the ring.
	@param slot where the plot sits in the ring
	@param folder where the model goes
	@return the plot's parts and places
]]
function Builder.plot(slot: PlotLayout.Slot, folder: Folder): Plot
	local shape = Config.Plots
	local colors = shape.colors
	local top = shape.baseThickness
	local pivot = CFrame.new(slot.x, top, slot.z) * CFrame.Angles(0, slot.yaw, 0)
	-- The front edge faces the middle, which is the pivot's look direction: negative Z in its own space.
	local front = -shape.baseSize / 2

	local model = Instance.new("Model")
	model.Name = `Plot{slot.index}`

	local base = part(
		Parts.Base,
		Vector3.new(shape.baseSize, shape.baseThickness, shape.baseSize),
		pivot * CFrame.new(0, -shape.baseThickness / 2, 0),
		colors.base,
		model
	)
	base.Material = Enum.Material.Grass
	model.PrimaryPart = base

	local spawnCFrame = pivot * CFrame.new(0, 0, front + shape.spawnInset)
	local pad = part(
		Parts.Spawn,
		Vector3.new(shape.spawnSize, shape.padThickness, shape.spawnSize),
		spawnCFrame * CFrame.new(0, shape.padThickness / 2, 0),
		colors.spawn,
		model
	)
	pad.Material = Enum.Material.Neon

	local sign = part(
		Parts.Sign,
		Vector3.new(shape.signWidth, shape.signHeight, shape.signThickness),
		pivot * CFrame.new(0, shape.signLift + shape.signHeight / 2, front + shape.signThickness / 2),
		colors.sign,
		model
	)
	sign.CanCollide = false

	local machines = Instance.new("Folder")
	machines.Name = Parts.Machines
	machines.Parent = model
	local pads = Instance.new("Folder")
	pads.Name = Parts.Pads
	pads.Parent = model

	model.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	model.WorldPivot = pivot
	model:SetAttribute(Attributes.PlotIndex, slot.index)
	model:SetAttribute(Attributes.OwnerUserId, 0)
	model:SetAttribute(Attributes.OwnerName, "")
	CollectionService:AddTag(model, WorldKeys.Tags.Plot)
	model.Parent = folder

	-- Characters arrive facing into the plot, away from the middle.
	local arrival = spawnCFrame * CFrame.new(0, SPAWN_CLEARANCE, 0) * CFrame.Angles(0, math.pi, 0)
	return { index = slot.index, model = model, spawn = arrival, pivot = pivot, machines = machines, pads = pads }
end

--[[
	Removes every machine and pad from a plot.
	@param plot the plot
]]
function Builder.clearFactory(plot: Plot)
	plot.machines:ClearAllChildren()
	plot.pads:ClearAllChildren()
end

--[[
	Makes one anchored part from a layout box.
	@param box the box, in plot studs
	@param pivot the plot's pivot
	@param parent where the part goes
	@return the part
]]
function Builder.box(box: FactoryLayout.Box, pivot: CFrame, parent: Instance): Part
	return part(
		box.name,
		Vector3.new(box.sx, box.sy, box.sz),
		pivot * CFrame.new(box.x, box.y, box.z),
		box.color,
		parent
	)
end

--[[
	Of the machines of one kind on a plot that share a place on the line (conveyors, collectors), shows only the best
	(`FactoryLayout.rank`), so two belts or two bins never draw over each other. Other kinds are left alone.
	@param plot the plot
	@param kind the kind just placed
]]
function Builder.showBestOfKind(plot: Plot, kind: string)
	local best: Instance? = nil
	local bestRank = -math.huge
	local same: { Instance } = {}
	for _, model in plot.machines:GetChildren() do
		local def = Config.Buildables[model.Name]
		local rank = if def and def.kind == kind then FactoryLayout.rank(def) else nil
		if rank then
			table.insert(same, model)
			-- Ties go to the lower ID, so the choice never depends on the order children are listed in.
			if rank > bestRank or (rank == bestRank and best ~= nil and model.Name < best.Name) then
				best = model
				bestRank = rank
			end
		end
	end
	for _, model in same do
		local shown = model == best
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") then
				child.Transparency = if shown then 0 else 1
				child.CanCollide = shown
			end
		end
	end
end

return Builder
