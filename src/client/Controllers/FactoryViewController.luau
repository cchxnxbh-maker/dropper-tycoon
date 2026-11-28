--!strict
-- FactoryViewController: draws the box items riding the player's conveyor (plan section 4.4, ADR 0021).
--
-- Items are never sent by the server. `Net/FactoryMirror` builds the same `FactorySim` from the `FactoryState` the
-- server sent
-- (what is owned, each dropper's start step, and the step at a moment of server time), works out the current step
-- from the shared server clock, and asks the sim where every item is. So the boxes reach the collector on the very
-- step the server pays for them. The boxes are anchored and never collide, touch or block anything; they are only a
-- picture (ADR 0002). Only the player's own plot is drawn for now; other plots join with the level of detail rules
-- (plan section 4.12).
--
-- State owned: a pool of box parts in `Workspace.Items`.
--
-- Usage, in Main:
--     FactoryViewController.init()
--     FactoryViewController.start()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientStore = require(script.Parent.Parent.Net.ClientStore)
local Config = require(Shared:WaitForChild("Config"))
local FactoryLayout = require(Shared:WaitForChild("Logic"):WaitForChild("FactoryLayout"))
local FactoryMirror = require(script.Parent.Parent.Net.FactoryMirror)
local FactorySim = require(Shared:WaitForChild("Logic"):WaitForChild("FactorySim"))
local PlotLayout = require(Shared:WaitForChild("Logic"):WaitForChild("PlotLayout"))
local Scheduler = require(Shared:WaitForChild("Util"):WaitForChild("Scheduler"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local WorldKeys = require(Shared:WaitForChild("Util"):WaitForChild("WorldKeys"))

local FactoryViewController = {}

local trove = Trove.new()
local folder: Folder
local plotPivot: CFrame? = nil

-- Reused every frame, so drawing allocates nothing.
local positions: { number } = {}
local parts: { BasePart } = {}
local cframes: { CFrame } = {}
local moving: { BasePart } = {}
local shownCount = 0

local function newPart(): BasePart
	local part = Instance.new("Part")
	part.Name = "Item"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = Vector3.one * Config.Factory.itemSize
	part.Color = Color3.fromHex(Config.Factory.colors.item)
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 1
	part.Parent = folder
	return part
end

-- The pivot of the player's plot, worked out from config exactly as the server places it.
local function findPlotPivot(): CFrame?
	local plots = Workspace:FindFirstChild("Plots")
	if plots == nil then
		return nil
	end
	for _, model in plots:GetChildren() do
		local index = model:GetAttribute(WorldKeys.Attributes.PlotIndex)
		if
			model:GetAttribute(WorldKeys.Attributes.OwnerUserId) == Players.LocalPlayer.UserId
			and type(index) == "number"
		then
			local slot = PlotLayout.ring(Config.Plots.count, Config.Plots.ringRadius)[index]
			if slot then
				return CFrame.new(slot.x, Config.Plots.baseThickness, slot.z) * CFrame.Angles(0, slot.yaw, 0)
			end
		end
	end
	return nil
end

-- Enough parts for every dropper's fullest belt.
local function grow(sim: FactorySim.Sim)
	local needed = #sim.droppers * Config.Factory.maxItemsPerDropper
	while #parts < needed do
		table.insert(parts, newPart())
	end
end

local function render()
	local current = FactoryMirror.sim()
	if current == nil then
		return
	end
	grow(current)
	if plotPivot == nil then
		plotPivot = findPlotPivot()
		if plotPivot == nil then
			return
		end
	end
	local pivot = plotPivot :: CFrame
	local tick = FactoryMirror.tickAt(Workspace:GetServerTimeNow())
	local count = math.min(#parts, FactorySim.itemsAt(current, tick, positions, Config.Factory.maxItemsPerDropper))
	local lift = Config.Factory.itemSize / 2
	table.clear(moving)
	table.clear(cframes)
	for index = 1, count do
		local x, y, z = FactoryLayout.beltPoint(Config.Factory, positions[index])
		local part = parts[index]
		if part.Transparency ~= 0 then
			part.Transparency = 0
		end
		moving[index] = part
		cframes[index] = pivot * CFrame.new(x, y + lift, z)
	end
	Workspace:BulkMoveTo(moving, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	for index = count + 1, shownCount do
		parts[index].Transparency = 1
	end
	shownCount = count
end

--[[
	Makes the folder the item parts live in.
]]
function FactoryViewController.init()
	folder = trove:Add(Instance.new("Folder"))
	folder.Name = "Items"
	folder.Parent = Workspace
end

--[[
	Follows the player's factory state and draws the items every frame.
]]
function FactoryViewController.start()
	trove:Add(ClientStore.changed("factory", function()
		-- A purchase may have moved the plot's machines; find the plot again in case it changed.
		plotPivot = findPlotPivot()
	end))
	Scheduler.onRender("ItemVisuals", render)
end

return FactoryViewController
