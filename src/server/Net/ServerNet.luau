--!strict
-- ServerNet: the server side of the network layer (plan section 4.8, ADR 0011).
--
-- Creates the remotes from `Remotes.luau`, runs every client request through `Pipeline` (payload, rate limit,
-- session state) and only then calls its handler. Rejected requests are dropped and logged with a strike; a player
-- far over the limit is kicked. Outgoing messages are checked against their rule before they are sent, so a server
-- bug is caught here instead of in a client.
--
-- State owned: the remote instances and the pipeline (rate buckets and strikes per player).
--
-- Usage:
--     ServerNet.init(Handlers)   -- in Main, once
--     ServerNet.start()
--     ServerNet.send(player, Remotes.TestPong, { label = "hello", serverTime = os.time() })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Net = require(ReplicatedStorage.Shared.Network.Net)
local Pipeline = require(script.Parent.Pipeline)
local RateLimiter = require(ReplicatedStorage.Shared.Logic.RateLimiter)
local RemoteFolder = require(ReplicatedStorage.Shared.Network.RemoteFolder)
local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type HandlerFile = { remote: Net.ToServer, handle: (player: Player, payload: any) -> () }

local TAG = "Net"

local ServerNet = {}

local trove = Trove.new()
local events: { [string]: RemoteEvent } = {}
local auditing: { [Player]: true } = {}
local pipeline = Pipeline.new({
	remotes = Remotes,
	RateLimiter = RateLimiter,
	strikeWindowSeconds = Config.Tuning.Network.strikeWindowSeconds,
	kickAfterStrikes = Config.Tuning.Network.kickAfterStrikes,
})

local function receive(player: Player, name: string, payload: any, extraArguments: number)
	local now = os.clock()
	local result
	if extraArguments > 0 then
		-- A real client always sends exactly one payload. Run a value no rule accepts, so it counts as a bad payload.
		result = pipeline.receive(player.UserId, player, name, Net.REJECTED, now)
	else
		result = pipeline.receive(player.UserId, player, name, payload, now)
	end
	local fields = { userId = player.UserId, remote = name, strikes = result.strikes, reason = result.reason }
	if result.outcome == "error" then
		Log.error(TAG, "handler failed", fields)
	elseif result.outcome == "unhandled" then
		Log.error(TAG, "request has no handler", fields)
	elseif result.outcome ~= "accepted" then
		-- The abuse suite sends hundreds of bad requests on purpose; keep its run quiet.
		local level = if auditing[player] or result.outcome == "rate" then "debug" else "warn"
		if level == "warn" then
			Log.warn(TAG, `rejected ({result.outcome})`, fields)
		else
			Log.debug(TAG, `rejected ({result.outcome})`, fields)
		end
	end
	if result.kick then
		Log.warn(TAG, "kicked for too many strikes", fields)
		player:Kick(Config.Strings.Net.kicked)
	end
end

--[[
	Creates the remotes and registers one handler per client request. Call once, before `start`.
	@param handlers the handler files from `server/Net/Handlers`, by file name
	@error when a handler names a remote that is not a client request, or its file is not named after its remote
]]
function ServerNet.init(handlers: { [string]: HandlerFile })
	local folder
	folder, events = RemoteFolder.create(ReplicatedStorage, Remotes)
	trove:Add(folder)
	for fileName, file in handlers do
		assert(
			fileName == file.remote.name,
			`Handlers/{fileName}.luau must be named after its remote, {file.remote.name}`
		)
		pipeline.handle(file.remote.name, file.handle)
	end
end

--[[
	Starts listening. Every client request in `Remotes.luau` without a handler is logged as an error, so a missing
	handler file shows up in the first playtest.
]]
function ServerNet.start()
	for name, event in events do
		if (Remotes :: any)[name].direction == "toServer" then
			trove:Connect(event.OnServerEvent, function(player: Player, payload: any, ...: any)
				receive(player, name, payload, select("#", ...))
			end)
		else
			-- Clients never send on a server-to-client remote. Doing so is a strike-free no-op but is logged.
			trove:Connect(event.OnServerEvent, function(player: Player)
				Log.warn(TAG, "client sent on a server-only remote", { userId = player.UserId, remote = name })
			end)
		end
	end
	trove:Connect(Players.PlayerRemoving, function(player: Player)
		pipeline.forget(player.UserId)
		auditing[player] = nil
	end)
	for _, name in pipeline.unhandled() do
		Log.error(TAG, "client request has no handler file", { remote = name })
	end
end

--[[
	Sends a message to one player.
	@param player who receives it
	@param remote a server-to-client remote from `Remotes.luau`
	@param payload the message; it must pass the remote's rule, or it is not sent and an error is logged
]]
function ServerNet.send(player: Player, remote: Net.ToClient, payload: any)
	local ok, reason = remote.check(payload)
	if not ok then
		Log.error(TAG, "outgoing message fails its rule", { remote = remote.name, reason = reason })
		return
	end
	events[remote.name]:FireClient(player, payload)
end

--[[
	Sends a message to every player in the server.
	@param remote a server-to-client remote from `Remotes.luau`
	@param payload the message; it must pass the remote's rule, or it is not sent and an error is logged
]]
function ServerNet.sendAll(remote: Net.ToClient, payload: any)
	local ok, reason = remote.check(payload)
	if not ok then
		Log.error(TAG, "outgoing message fails its rule", { remote = remote.name, reason = reason })
		return
	end
	events[remote.name]:FireAllClients(payload)
end

--[[
	Sets the check that a player's session is Playing. DataService sets it in task 9; until then every player counts.
	@param gate returns true when the player may make requests
]]
function ServerNet.setSessionGate(gate: (player: Player) -> boolean)
	pipeline.setSessionGate(gate)
end

--[[
	Audit mode for the Studio abuse suite: the player's outcomes are recorded, handlers are skipped (no state
	changes) and the player is never kicked. Turning it on or off gives the player a fresh start.
	@param player the player running the suite
	@param on true to start auditing, false to stop
]]
function ServerNet.audit(player: Player, on: boolean)
	pipeline.audit(player.UserId, on)
	if on then
		auditing[player] = true
	else
		auditing[player] = nil
	end
end

--[[
	@param player a player in audit mode
	@return the outcome of each request since audit mode was turned on, in arrival order
]]
function ServerNet.auditLog(player: Player): { string }
	return pipeline.auditLog(player.UserId)
end

return ServerNet
