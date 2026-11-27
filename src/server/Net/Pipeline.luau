--!strict
-- Pipeline: the checks every client request passes before a handler sees it (plan section 3.6, ADR 0011).
--
-- In order: the payload check from `Remotes.luau` (shape limits, then the remote's own rule), the remote's rate limit
-- for this player, and the player's session state, which must be Playing. A request that fails any check is dropped
-- and counts a strike; enough strikes inside one window and the result says to kick. Handlers then check ownership,
-- distance and price themselves.
--
-- Pure Luau: `ServerNet` feeds it Roblox events, and the Lune specs feed it by hand. That is why `RateLimiter` comes
-- in through the options instead of a require: server code reaches shared modules by Roblox paths, which Lune lacks.
--
-- Audit mode, for the Studio abuse suite: a player's outcomes are recorded, accepted requests never reach the real
-- handler (so no game state changes) and the player is never kicked.
--
-- State owned: per-player rate buckets, strike counts and audit logs, and the handler table.
--
-- Usage:
--     local pipeline = Pipeline.new({ remotes = Remotes, RateLimiter = RateLimiter, strikeWindowSeconds = 60,
--         kickAfterStrikes = 30 })
--     pipeline.handle("RequestTestPing", function(player, payload) ... end)
--     local result = pipeline.receive(player.UserId, player, "RequestTestPing", payload, os.clock())

export type Outcome = "accepted" | "payload" | "rate" | "session" | "unhandled" | "error"
export type Handler = (player: any, payload: any) -> ()
export type Result = { outcome: Outcome, reason: string?, strikes: number, kick: boolean }

type Bucket = any
type RateLimiterModule = {
	new: (rate: { burst: number, perSecond: number }, now: number) -> Bucket,
	take: (bucket: Bucket, now: number) -> boolean,
}

export type Options = {
	remotes: { [string]: any },
	RateLimiter: RateLimiterModule,
	strikeWindowSeconds: number,
	kickAfterStrikes: number,
}

type PlayerState = {
	buckets: { [string]: Bucket },
	strikes: number,
	windowStart: number,
	kicked: boolean,
	audit: { string }?,
}

export type Pipeline = {
	handle: (name: string, handler: Handler) -> (),
	setSessionGate: (gate: (player: any) -> boolean) -> (),
	receive: (key: number, player: any, name: string, payload: any, now: number) -> Result,
	unhandled: () -> { string },
	forget: (key: number) -> (),
	strikes: (key: number) -> number,
	audit: (key: number, on: boolean) -> (),
	auditLog: (key: number) -> { string },
}

local Pipeline = {}

--[[
	Makes a pipeline for a set of remotes.
	@param options `remotes` from `Remotes.luau`, the `RateLimiter` module, and the strike window and kick threshold
	@return the pipeline
]]
function Pipeline.new(options: Options): Pipeline
	local handlers: { [string]: Handler } = {}
	local players: { [number]: PlayerState } = {}
	local sessionGate: (player: any) -> boolean = function(_player)
		return true
	end

	local function stateFor(key: number, now: number): PlayerState
		local state = players[key]
		if state == nil then
			state = { buckets = {}, strikes = 0, windowStart = now, kicked = false, audit = nil }
			players[key] = state
		end
		return state
	end

	local function strike(state: PlayerState, now: number, outcome: Outcome, reason: string?): Result
		if now - state.windowStart >= options.strikeWindowSeconds then
			state.windowStart = now
			state.strikes = 0
		end
		state.strikes += 1
		local kick = false
		if state.audit == nil and not state.kicked and state.strikes >= options.kickAfterStrikes then
			state.kicked = true
			kick = true
		end
		return { outcome = outcome, reason = reason, strikes = state.strikes, kick = kick }
	end

	local pipeline = {} :: Pipeline

	--[[
		Registers the handler for a client request. Each request has exactly one.
		@error when the name is not a client request in `Remotes.luau`, or already has a handler
	]]
	function pipeline.handle(name: string, handler: Handler)
		local remote = options.remotes[name]
		assert(remote and remote.direction == "toServer", `ServerNet: {name} is not a client request in Remotes.luau`)
		assert(handlers[name] == nil, `ServerNet: {name} already has a handler`)
		handlers[name] = handler
	end

	--[[
		Sets the check that a player's session is Playing. Until the session state machine exists (task 9), every
		player in the server counts as Playing.
	]]
	function pipeline.setSessionGate(gate: (player: any) -> boolean)
		sessionGate = gate
	end

	--[[
		Runs every check on one request and, when all pass, its handler.
		@param key the player's UserId
		@param player the player, passed to the session gate and the handler
		@param name the remote's name
		@param payload the request exactly as it arrived
		@param now seconds on the server's steady clock
		@return the outcome, a reason when rejected, the player's strikes this window and whether to kick now.
		A handler that errors gives "error" and no strike, since the fault is ours, not the player's.
	]]
	function pipeline.receive(key: number, player: any, name: string, payload: any, now: number): Result
		local state = stateFor(key, now)
		local remote = options.remotes[name]
		local result: Result
		local ok, reason = remote.check(payload)
		if not ok then
			result = strike(state, now, "payload", reason)
		else
			local bucket = state.buckets[name]
			if bucket == nil then
				bucket = options.RateLimiter.new(remote.rate, now)
				state.buckets[name] = bucket
			end
			if not options.RateLimiter.take(bucket, now) then
				result = strike(state, now, "rate", nil)
			elseif not sessionGate(player) then
				result = strike(state, now, "session", nil)
			else
				local handler = handlers[name]
				if handler == nil then
					result = { outcome = "unhandled", reason = nil, strikes = state.strikes, kick = false }
				elseif state.audit then
					result = { outcome = "accepted", reason = nil, strikes = state.strikes, kick = false }
				else
					-- xpcall with a handler, because the type of pcall on a function that returns nothing has no error.
					local why: string? = nil
					local handled = xpcall(handler, function(err: any)
						why = tostring(err)
					end, player, payload)
					local outcome: Outcome = if handled then "accepted" else "error"
					result = { outcome = outcome, reason = why, strikes = state.strikes, kick = false }
				end
			end
		end
		if state.audit then
			table.insert(state.audit, result.outcome)
		end
		return result
	end

	--[[
		@return the client requests in `Remotes.luau` that have no handler yet, sorted
	]]
	function pipeline.unhandled(): { string }
		local names = {}
		for name, remote in options.remotes do
			if remote.direction == "toServer" and handlers[name] == nil then
				table.insert(names, name)
			end
		end
		table.sort(names)
		return names
	end

	--[[
		Drops everything held for a player who left.
	]]
	function pipeline.forget(key: number)
		players[key] = nil
	end

	--[[
		@return the player's strikes in the current window
	]]
	function pipeline.strikes(key: number): number
		local state = players[key]
		return if state then state.strikes else 0
	end

	--[[
		Turns audit mode on or off for a player. Either way the player starts fresh (full buckets, no strikes), so the
		suite neither depends on nor leaves any trace of earlier requests.
	]]
	function pipeline.audit(key: number, on: boolean)
		players[key] = nil
		if on then
			local state = stateFor(key, 0)
			state.audit = {}
		end
	end

	--[[
		@return the outcomes recorded for the player since audit mode was turned on, in arrival order
	]]
	function pipeline.auditLog(key: number): { string }
		local state = players[key]
		return if state and state.audit then table.clone(state.audit) else {}
	end

	return pipeline
end

return Pipeline
