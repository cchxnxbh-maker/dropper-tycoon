--!strict
-- PlotService: the plots of this server and who holds each one (plan sections 3.4 and 4.4, task 10, ADR 0020).
--
-- At init it builds `Config.Plots.count` plot bases in a ring around the origin, in `Workspace.Plots`, each facing the
-- middle with a spawn pad and a sign at its front edge. Once a player's save has loaded, they get the lowest free plot,
-- their character is sent to its spawn pad, and every respawn after that lands there too. When they leave, the plot is
-- free again. With every plot taken, a new player is asked to rejoin (Max Players should keep that from happening).
--
-- Streaming (plan section 4.8): each plot streams as one whole model, and a player's own plot stays loaded for them.
-- The models carry the tag `Plot` and the attributes `PlotIndex`, `OwnerUserId` and `OwnerName` so the client can draw
-- signs; the attributes are a display of the assignment held here, never the truth.
--
-- From task 12 it also shows each owner's factory: the grey-box parts of every machine they bought, in the plot's
-- `Machines` folder, and a pad for each machine they can buy next, in `Pads` (shapes from `Logic/FactoryLayout`).
-- PurchaseService decides what goes there; the parts are a display, never the truth (ADR 0021).
--
-- State owned: plot assignment and the plot models.
--
-- Usage, in Main:
--     PlotService.init()
--     PlotService.start()
-- From a later service:
--     local plot = PlotService.getPlot(player)
--     PlotService.placeMachine(player, def)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Builder = require(script.Builder)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local FactoryLayout = require(ReplicatedStorage.Shared.Logic.FactoryLayout)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local PlotLayout = require(ReplicatedStorage.Shared.Logic.PlotLayout)
local PlotSlots = require(ReplicatedStorage.Shared.Logic.PlotSlots)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(ReplicatedStorage.Shared.Types.Config)
local WorldKeys = require(ReplicatedStorage.Shared.Util.WorldKeys)

type Plot = Builder.Plot
-- Spelled out here because Wally's package link files do not re-export the Signal package's types.
export type PlayerSignal = {
	Connect: (self: any, listener: (player: Player) -> ()) -> { Disconnect: (self: any) -> () },
	Fire: (self: any, player: Player) -> (),
}

local TAG = "Plot"
local FOLDER_NAME = "Plots"
-- How far above the spawn pad a character is placed, so its feet clear the pad. A fact of the default character size.

local Attributes = WorldKeys.Attributes

local PlotService = {}

--[[
	Fires once a player has been given a plot. Carries the player. Their plot is empty until a later service fills it.
]]
PlotService.plotAssigned = (Signal.new() :: any) :: PlayerSignal

local trove = Trove.new()
local plots: { Plot } = {}
local slots = PlotSlots.new(Config.Plots.count)
local playerTroves: { [Player]: typeof(Trove.new()) } = {}

-- Sends a character to its owner's spawn pad, once the area around the pad has streamed in for that player.
local function sendHome(player: Player, character: Model)
	local index = slots.indexOf(player.UserId)
	if index == nil then
		return
	end
	local target = plots[index].spawn
	local ok, err = pcall(function()
		player:RequestStreamAroundAsync(target.Position)
	end)
	if not ok then
		Log.warn(
			TAG,
			"could not stream the plot in before moving the character",
			{ userId = player.UserId, error = err }
		)
	end
	if character.Parent ~= nil and player.Character == character then
		character:PivotTo(target)
	end
end

local function assign(player: Player)
	if player.Parent ~= Players or slots.indexOf(player.UserId) then
		return
	end
	local index = slots.claim(player.UserId)
	if index == nil then
		Log.warn(TAG, "no free plot; asking the player to rejoin", { userId = player.UserId })
		player:Kick(Config.Strings.Plot.serverFull)
		return
	end
	local plot = plots[index]
	plot.model:SetAttribute(Attributes.OwnerUserId, player.UserId)
	plot.model:SetAttribute(Attributes.OwnerName, player.DisplayName)
	plot.model:AddPersistentPlayer(player)

	local own = Trove.new()
	playerTroves[player] = own
	own:Connect(player.CharacterAdded, function(character: Model)
		sendHome(player, character)
	end)
	local character = player.Character
	if character then
		task.spawn(sendHome, player, character)
	end
	Log.info(TAG, "plot assigned", { userId = player.UserId, plot = index, free = slots.freeCount() })
	PlotService.plotAssigned:Fire(player)
end

local function release(player: Player)
	local own = playerTroves[player]
	if own then
		own:Destroy()
		playerTroves[player] = nil
	end
	local index = slots.release(player.UserId)
	if index == nil then
		return
	end
	Builder.clearFactory(plots[index])
	local model = plots[index].model
	model:SetAttribute(Attributes.OwnerUserId, 0)
	model:SetAttribute(Attributes.OwnerName, "")
	model:RemovePersistentPlayer(player)
	Log.info(TAG, "plot released", { userId = player.UserId, plot = index, free = slots.freeCount() })
end

--[[
	Builds the empty plots in `Workspace.Plots`. Call once, before `start`.
	@error when `Workspace.Plots` already exists (it is built by code; nothing in the place file may use the name)
]]
function PlotService.init()
	assert(Workspace:FindFirstChild(FOLDER_NAME) == nil, "PlotService: Workspace already has a Plots folder")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, slot in PlotLayout.ring(Config.Plots.count, Config.Plots.ringRadius) do
		table.insert(plots, Builder.plot(slot, folder))
	end
	folder.Parent = Workspace
	trove:Add(folder)
	if not Workspace.StreamingEnabled then
		-- Rojo sets streaming from default.project.json. Off means the place was never synced, or the setting was
		-- changed by hand in Studio.
		Log.warn(TAG, "Workspace.StreamingEnabled is off; reconnect Rojo so it applies default.project.json")
	end
end

--[[
	Gives each player a plot once their save has loaded, and frees it when they leave.
]]
function PlotService.start()
	trove:Add(DataService.profileLoaded:Connect(assign))
	trove:Connect(Players.PlayerRemoving, release)
	for _, player in Players:GetPlayers() do
		if DataService.isPlaying(player) then
			assign(player)
		end
	end
end

--[[
	The player's plot model.
	@return the model; nil when the player holds no plot (still loading, or the server was full)
]]
function PlotService.getPlot(player: Player): Model?
	local index = slots.indexOf(player.UserId)
	return if index then plots[index].model else nil
end

--[[
	The number of the player's plot.
	@return 1 to `Config.Plots.count`; nil when the player holds no plot
]]
function PlotService.getPlotIndex(player: Player): number?
	return slots.indexOf(player.UserId)
end

--[[
	Shows one bought machine on the player's plot, as grey-box parts in a model tagged `Buildable`.
	@param player the plot's owner
	@param def the machine
	@return true when placed; false when the player holds no plot. Placing a machine that is already shown replaces it
]]
function PlotService.placeMachine(player: Player, def: Types.BuildableDef): boolean
	local index = slots.indexOf(player.UserId)
	if index == nil then
		return false
	end
	local plot = plots[index]
	local old = plot.machines:FindFirstChild(def.id)
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = def.id
	for _, box in FactoryLayout.boxes(def, Config.Factory) do
		local made = Builder.box(box, plot.pivot, model)
		-- Items are drawn by each client and never touch parts, so machines need no collision with them; players may
		-- still bump into machines.
		made.CanTouch = false
	end
	model:SetAttribute(Attributes.BuildableId, def.id)
	CollectionService:AddTag(model, WorldKeys.Tags.Buildable)
	model.Parent = plot.machines
	Builder.showBestOfKind(plot, def.kind)
	return true
end

--[[
	Sets which purchase pads the player's plot shows. A pad that stays (one selling its next level) is kept as it is,
	so a player standing on it is not knocked off.
	@param player the plot's owner
	@param defs the machines whose pads should show, from `Purchase.offers`
	@return true when shown; false when the player holds no plot
]]
function PlotService.showPads(player: Player, defs: { Types.BuildableDef }): boolean
	local index = slots.indexOf(player.UserId)
	if index == nil then
		return false
	end
	local plot = plots[index]
	local wanted: { [string]: boolean } = {}
	for _, def in defs do
		wanted[def.id] = true
	end
	for _, existing in plot.pads:GetChildren() do
		if not wanted[existing.Name] then
			existing:Destroy()
		end
	end
	for _, def in defs do
		if plot.pads:FindFirstChild(def.id) then
			continue
		end
		local pad = Builder.box(FactoryLayout.pad(def, Config.Factory), plot.pivot, plot.pads)
		pad.Name = def.id
		pad.Material = Enum.Material.Neon
		pad:SetAttribute(Attributes.BuildableId, def.id)
		CollectionService:AddTag(pad, WorldKeys.Tags.PurchasePad)
	end
	return true
end

--[[
	Removes every machine and pad from the player's plot. For the dev panel's reset.
	@param player the plot's owner
]]
function PlotService.clearFactory(player: Player)
	local index = slots.indexOf(player.UserId)
	if index then
		Builder.clearFactory(plots[index])
	end
end

--[[
	Where a point on the player's plot is in the world.
	@param player the plot's owner
	@param point a point in plot studs, as in config
	@return the world position on the plot's surface; nil when the player holds no plot
]]
function PlotService.toWorld(player: Player, point: Types.PlotPoint): Vector3?
	local index = slots.indexOf(player.UserId)
	if index == nil then
		return nil
	end
	return (plots[index].pivot * CFrame.new(point.x, 0, point.z)).Position
end

return PlotService
