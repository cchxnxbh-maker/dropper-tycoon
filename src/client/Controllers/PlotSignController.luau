--!strict
-- PlotSignController: writes who owns each plot on its sign (task 10). The player's own plot says "Your factory".
--
-- Streaming-safe (plan section 4.8): plots arrive and leave as whole models, so it binds a sign view when a model
-- tagged `Plot` streams in and drops it when the model streams out. It never assumes a plot exists. The owner comes
-- from the model's attributes, which mirror what PlotService holds.
--
-- State owned: one sign view per plot that is streamed in.
--
-- Usage, in Main:
--     PlotSignController.init()
--     PlotSignController.start()

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PlotSign = require(script.Parent.Parent.Views.PlotSign)
local Text = require(Shared:WaitForChild("Util"):WaitForChild("Text"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local WorldKeys = require(Shared:WaitForChild("Util"):WaitForChild("WorldKeys"))

local Attributes = WorldKeys.Attributes

local PlotSignController = {}

local trove = Trove.new()
local bound: { [Instance]: typeof(Trove.new()) } = {}

local function ownerLine(model: Instance): string
	local strings = Config.Strings.Plot
	local ownerId = model:GetAttribute(Attributes.OwnerUserId)
	if type(ownerId) ~= "number" or ownerId == 0 then
		return strings.freeSign
	elseif ownerId == Players.LocalPlayer.UserId then
		return strings.yourSign
	end
	local name = model:GetAttribute(Attributes.OwnerName)
	return Text.format(strings.ownerSign, { name = if type(name) == "string" then name else "" })
end

local function unbind(model: Instance)
	local own = bound[model]
	if own then
		own:Destroy()
		bound[model] = nil
	end
end

local function bind(model: Instance)
	unbind(model)
	local own = Trove.new()
	bound[model] = own
	local sign = model:FindFirstChild(WorldKeys.PlotParts.Sign)
	if sign == nil or not sign:IsA("BasePart") then
		-- A whole model normally arrives with its parts. If the sign comes a moment later, bind again then.
		own:Connect(model.ChildAdded, function(child: Instance)
			if child.Name == WorldKeys.PlotParts.Sign then
				task.defer(function()
					-- Only if the plot is still here and still waiting; it may have streamed out meanwhile.
					if bound[model] == own then
						bind(model)
					end
				end)
			end
		end)
		return
	end
	local view = own:Add(PlotSign.mount(sign), "destroy")
	local function refresh()
		local index = model:GetAttribute(Attributes.PlotIndex)
		local number =
			Text.format(Config.Strings.Plot.number, { number = if type(index) == "number" then index else 0 })
		view.set(ownerLine(model), number)
	end
	own:Connect(model:GetAttributeChangedSignal(Attributes.OwnerUserId), refresh)
	own:Connect(model:GetAttributeChangedSignal(Attributes.OwnerName), refresh)
	refresh()
end

--[[
	Nothing to prepare; here so Main treats every controller the same way.
]]
function PlotSignController.init() end

--[[
	Binds every plot already streamed in, and each one that arrives later.
]]
function PlotSignController.start()
	trove:Connect(CollectionService:GetInstanceAddedSignal(WorldKeys.Tags.Plot), bind)
	trove:Connect(CollectionService:GetInstanceRemovedSignal(WorldKeys.Tags.Plot), unbind)
	for _, model in CollectionService:GetTagged(WorldKeys.Tags.Plot) do
		bind(model)
	end
end

return PlotSignController
