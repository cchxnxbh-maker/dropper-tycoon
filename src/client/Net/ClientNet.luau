--!strict
-- ClientNet: the client side of the network layer (plan section 4.8, ADR 0011).
--
-- Sends requests and listens for server messages, using only the remotes in `Remotes.luau`. Before sending it checks
-- the request against its own rule and keeps under a slightly stricter copy of the server's rate limit
-- (`Tuning.Network.clientRateShare`), so an honest client never earns a strike. The server checks everything again;
-- nothing here is trusted.
--
-- State owned: the remote events found at startup and the client's own rate buckets.
--
-- Usage:
--     ClientNet.init()
--     ClientNet.on(Remotes.TestPong, function(payload) ... end)
--     ClientNet.send(Remotes.RequestTestPing, { label = "hello" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log"))
local Net = require(Shared:WaitForChild("Network"):WaitForChild("Net"))
local RateLimiter = require(Shared:WaitForChild("Logic"):WaitForChild("RateLimiter"))
local RemoteFolder = require(Shared:WaitForChild("Network"):WaitForChild("RemoteFolder"))
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local TAG = "Net"

local ClientNet = {}

local trove = Trove.new()
local events: { [string]: RemoteEvent }? = nil
local buckets: { [string]: RateLimiter.Bucket } = {}

local function eventFor(name: string): RemoteEvent
	assert(events, "ClientNet: call init first")
	return events[name]
end

--[[
	Waits for the remotes to replicate. Call once, before anything else here.
	@error when the remotes have not arrived within RemoteFolder's timeout
]]
function ClientNet.init()
	events = RemoteFolder.find(ReplicatedStorage, Remotes)
end

--[[
	Sends a request to the server.
	@param remote a client request from `Remotes.luau`
	@param payload the request: IDs only, never prices, amounts or positions
	@return true when it was sent; false when it fails its own rule (logged as an error, since it is our bug) or
	would go over the client's share of the rate limit (logged at debug)
]]
function ClientNet.send(remote: Net.ToServer, payload: any): boolean
	local ok, reason = remote.check(payload)
	if not ok then
		Log.error(TAG, "request fails its own rule, not sent", { remote = remote.name, reason = reason })
		return false
	end
	local now = os.clock()
	local bucket = buckets[remote.name]
	if bucket == nil then
		local share = Config.Tuning.Network.clientRateShare
		local rate =
			{ burst = math.max(1, math.floor(remote.rate.burst * share)), perSecond = remote.rate.perSecond * share }
		bucket = RateLimiter.new(rate, now)
		buckets[remote.name] = bucket
	end
	if not RateLimiter.take(bucket, now) then
		Log.debug(TAG, "request held back by the client rate limit", { remote = remote.name })
		return false
	end
	eventFor(remote.name):FireServer(payload)
	return true
end

--[[
	Listens for a server message.
	@param remote a server-to-client remote from `Remotes.luau`
	@param handler called with the payload each time the message arrives
	@return a function that stops listening
]]
function ClientNet.on(remote: Net.ToClient, handler: (payload: any) -> ()): () -> ()
	local connection = trove:Connect(eventFor(remote.name).OnClientEvent, handler)
	return function()
		trove:Remove(connection)
	end
end

return ClientNet
