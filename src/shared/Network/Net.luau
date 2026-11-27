--!strict
-- Net: the two ways to declare a remote, used only by `Remotes.luau` (plan section 3.6, ADR 0011).
--
-- `toServer` declares a client request: its payload rule, its rate limit and one valid example. The example is
-- checked when the game loads, and the abuse suite builds every bad request from it, so a new remote is tested
-- without writing a test. `toClient` declares a message from the server, with a rule the server checks before it
-- sends, so a bug never ships a malformed message. `define` names every remote after its key and freezes the lot.
--
-- Every remote is a RemoteEvent. Version 1 needs no RemoteFunction; the server never invokes a client in any case.
--
-- State owned: none. The definitions are frozen data.
--
-- Usage, in Remotes.luau:
--     return Net.define({
--         RequestPurchase = Net.toServer({
--             payload = Validate.record({ buildableId = Validate.string({ maxLength = 40 }) }),
--             rate = { burst = 5, perSecond = 2 },
--             example = { buildableId = "CoalDropper" },
--         }),
--     })

local Guard = require("./Guard")
local RateLimiter = require("../Logic/RateLimiter")
local Validate = require("../Logic/Validate")

export type Check = (payload: any) -> (boolean, string?)
export type ToServer = {
	name: string,
	direction: "toServer",
	rate: RateLimiter.Rate,
	example: any,
	check: Check,
}
export type ToClient = { name: string, direction: "toClient", check: Check }
export type Remote = ToServer | ToClient

export type ToServerSpec = { payload: Validate.Rule, rate: RateLimiter.Rate, example: any }
export type ToClientSpec = { payload: Validate.Rule }

local Net = {}

-- A value no client request accepts (Guard refuses functions). The server substitutes it for a request that arrived
-- with extra arguments, so tampering counts as a bad payload without a special path.
Net.REJECTED = function() end

-- Runs a payload rule and keeps the first problem as the reason, which is enough for a log line.
local function ruleCheck(rule: Validate.Rule): Check
	return function(payload)
		local problems = Validate.run(payload, rule, "payload")
		return #problems == 0, problems[1]
	end
end

--[[
	Declares a request from a client to the server.
	@param spec `payload` the rule for the request, `rate` its limit per player, `example` one valid request
	@return the definition, named later by `define`
]]
function Net.toServer(spec: ToServerSpec): ToServer
	local rule = ruleCheck(spec.payload)
	return {
		name = "",
		direction = "toServer",
		rate = spec.rate,
		example = spec.example,
		-- Shape limits first, so a payload rule never sees a huge or hostile value.
		check = function(payload)
			local ok, reason = Guard.check(payload)
			if not ok then
				return false, reason
			end
			return rule(payload)
		end,
	}
end

--[[
	Declares a message from the server to clients.
	@param spec `payload` the rule the server checks before sending
	@return the definition, named later by `define`
]]
function Net.toClient(spec: ToClientSpec): ToClient
	return { name = "", direction = "toClient", check = ruleCheck(spec.payload) }
end

--[[
	Names every remote after its key, checks each definition and freezes them.
	@param remotes the definitions by name
	@return the same table, frozen
	@error when a name is not PascalCase, a rate is not positive, or an example fails its own rule
]]
function Net.define<T>(remotes: T): T
	local all: { [string]: any } = remotes :: any
	for name, remote in all do
		assert(string.match(name, "^%u%w*$"), `Remotes: "{name}" must be PascalCase, like RequestPurchase`)
		remote.name = name
		if remote.direction == "toServer" then
			local rate = remote.rate
			assert(rate.burst >= 1 and rate.perSecond > 0, `Remotes.{name}: rate needs burst >= 1 and perSecond > 0`)
			local ok, reason = remote.check(remote.example)
			assert(ok, `Remotes.{name}: the example fails its own rule ({reason})`)
			table.freeze(rate)
		end
		table.freeze(remote)
	end
	table.freeze(all)
	return remotes
end

return Net
