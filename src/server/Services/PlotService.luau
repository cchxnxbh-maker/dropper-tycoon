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
-- State owned: plot assignment and the plot models.
--
-- Usage, in Main:
--     PlotService.init()
--     PlotService.start()
-- From a later service:
--     local plot = PlotService.getPlot(player)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local PlotLayout = require(ReplicatedStorage.Shared.Logic.PlotLayout)
local PlotSlots = require(ReplicatedStorage.Shared.Logic.PlotSlots)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldKeys = require(ReplicatedStorage.Shared.Util.WorldKeys)

type Plot = { index: number, model: Model, spawn: CFrame }

local TAG = "Plot"
local FOLDER_NAME = "Plots"
-- How far above the spawn pad a character is placed, so its feet clear the pad. A fact of the default character size.
local SPAWN_CLEARANCE = 4 -- const: a standard character's hip height plus a margin, not a tuning value

local Attributes = WorldKeys.Attributes
local Parts = WorldKeys.PlotParts

local PlotService = {}

local trove = Trove.new()
local plots: { Plot } = {}
local slots = PlotSlots.new(Config.Plots.count)
local playerTroves: { [Player]: typeof(Trove.new()) } = {}

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

-- Builds one empty plot. Its pivot is the centre of the base's top face, turned to face the middle of the ring.
local function buildPlot(slot: PlotLayout.Slot, folder: Folder): Plot
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

	model.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	model.WorldPivot = pivot
	model:SetAttribute(Attributes.PlotIndex, slot.index)
	model:SetAttribute(Attributes.OwnerUserId, 0)
	model:SetAttribute(Attributes.OwnerName, "")
	CollectionService:AddTag(model, WorldKeys.Tags.Plot)
	model.Parent = folder

	-- Characters arrive facing into the plot, away from the middle.
	local arrival = spawnCFrame * CFrame.new(0, SPAWN_CLEARANCE, 0) * CFrame.Angles(0, math.pi, 0)
	return { index = slot.index, model = model, spawn = arrival }
end

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
		table.insert(plots, buildPlot(slot, folder))
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

return PlotService
