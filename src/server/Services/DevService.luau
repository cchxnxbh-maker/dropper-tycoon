--!strict
-- DevService: the server half of the dev panel (plan section 4.10, task 10, ADR 0020).
--
-- Decides who may use the panel (every Studio playtest, the experience owner, and the user IDs in
-- `server/Config/DevAccess.luau`), runs dev commands for them and tells their panel what to show. Each command is one
-- file in `server/DevCommands/`. A request from anyone else is dropped and logged; the client cannot tell whether it is
-- allowed except by receiving the panel's state.
--
-- It starts last, after every other service, because dev commands may call any of them.
--
-- State owned: the `dev` section of every save (through DataService.mutate).
--
-- Usage, in Main:
--     DevService.init()
--     DevService.start()
-- From the RequestDevCommand handler:
--     DevService.run(player, payload.command)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)
local DevAccess = require(script.Parent.Parent.Config.DevAccess)
local DevCommands = require(script.Parent.Parent.DevCommands)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local ServerNet = require(script.Parent.Parent.Net.ServerNet)
local Trove = require(ReplicatedStorage.Packages.Trove)

type Command = { run: (player: Player) -> boolean }

local TAG = "Dev"

local DevService = {}

local trove = Trove.new()

local function sendState(player: Player)
	local data = DataService.get(player)
	if data then
		ServerNet.send(player, Remotes.DevPanelState, { testCounter = data.dev.testCounter })
	end
end

--[[
	Whether the player may use the dev panel.
	@return true in every Studio playtest, for the experience's owning account when `DevAccess.experienceOwner` is on,
	and for each user ID in `DevAccess.userIds`
]]
function DevService.isAllowed(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if DevAccess.experienceOwner and game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return table.find(DevAccess.userIds, player.UserId) ~= nil
end

--[[
	Runs one dev command for a player and sends their panel its new state.
	@param player who asked; must be allowed and Playing (ServerNet checks Playing first)
	@param name the command's file name in `server/DevCommands/`, such as "AddTestCounter"
	@return true when the command ran and reported success; false when the player is not allowed, the command is
	unknown, or the command failed (each is logged)
]]
function DevService.run(player: Player, name: string): boolean
	if not DevService.isAllowed(player) then
		Log.warn(TAG, "command refused: not allowed", { userId = player.UserId, command = name })
		return false
	end
	local command = (DevCommands :: { [string]: Command })[name]
	if command == nil then
		Log.warn(TAG, "command refused: unknown", { userId = player.UserId, command = name })
		return false
	end
	local ok = command.run(player)
	Log.info(TAG, "command ran", { userId = player.UserId, command = name, ok = ok })
	sendState(player)
	return ok
end

--[[
	Nothing to prepare yet; here so Main treats every service the same way.
]]
function DevService.init() end

--[[
	Shows the panel to each allowed player once their save has loaded.
]]
function DevService.start()
	trove:Add(DataService.profileLoaded:Connect(function(player: Player)
		if DevService.isAllowed(player) then
			sendState(player)
		end
	end))
end

return DevService
