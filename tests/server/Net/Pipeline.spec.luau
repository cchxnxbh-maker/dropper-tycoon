--!strict
-- Specs for the server request pipeline: check order, strikes and kicks, the session gate, handler errors, audit
-- mode, and the generated abuse suite run against every remote in Remotes.luau.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local AbuseCases = require("../../../src/shared/Network/AbuseCases")
local Pipeline = require("../../../src/server/Net/Pipeline")
local RateLimiter = require("../../../src/shared/Logic/RateLimiter")
local Remotes = require("../../../src/shared/Network/Remotes")

local PLAYER = 1
local KICK_AFTER = 10
local WINDOW = 60

-- A pipeline over the real remotes whose handlers record every payload they see.
local function make(): (Pipeline.Pipeline, { any })
	local seen = {}
	local pipeline = Pipeline.new({
		remotes = Remotes,
		RateLimiter = RateLimiter,
		strikeWindowSeconds = WINDOW,
		kickAfterStrikes = KICK_AFTER,
	})
	for name, remote in Remotes :: any do
		if remote.direction == "toServer" then
			pipeline.handle(name, function(_player, payload)
				table.insert(seen, payload)
			end)
		end
	end
	return pipeline, seen
end

local good = { label = "hello" }

describe("Pipeline", function()
	it("passes a valid request to its handler", function()
		local pipeline, seen = make()
		expect(pipeline.receive(PLAYER, "p", "RequestTestPing", good, 0).outcome).toBe("accepted")
		expect(seen).toEqual({ good })
	end)

	it("checks the payload before the rate limit, so a bad payload spends no token", function()
		local pipeline = make()
		for _ = 1, 50 do
			expect(pipeline.receive(PLAYER, "p", "RequestTestPing", { label = 5 }, 0).outcome).toBe("payload")
		end
		local accepted = 0
		for _ = 1, 50 do
			if pipeline.receive(PLAYER, "p", "RequestTestPing", good, 0).outcome == "accepted" then
				accepted += 1
			end
		end
		expect(accepted).toBe(Remotes.RequestTestPing.rate.burst)
	end)

	it("keeps each player's limit separate", function()
		local pipeline = make()
		for _ = 1, 20 do
			pipeline.receive(PLAYER, "p", "RequestTestPing", good, 0)
		end
		expect(pipeline.receive(2, "q", "RequestTestPing", good, 0).outcome).toBe("accepted")
	end)

	it("counts a strike for every rejection and says to kick once at the threshold", function()
		local pipeline = make()
		local kicks = 0
		for index = 1, KICK_AFTER + 5 do
			local result = pipeline.receive(PLAYER, "p", "RequestTestPing", "bad", 0)
			expect(result.strikes).toBe(index)
			if result.kick then
				kicks += 1
				expect(index).toBe(KICK_AFTER)
			end
		end
		expect(kicks).toBe(1)
	end)

	it("starts the strike count again after the window", function()
		local pipeline = make()
		for _ = 1, KICK_AFTER - 1 do
			pipeline.receive(PLAYER, "p", "RequestTestPing", "bad", 0)
		end
		local result = pipeline.receive(PLAYER, "p", "RequestTestPing", "bad", WINDOW)
		expect(result.strikes).toBe(1)
		expect(result.kick).toBe(false)
	end)

	it("refuses requests while the session is not Playing", function()
		local pipeline, seen = make()
		pipeline.setSessionGate(function(player)
			return player ~= "loading"
		end)
		expect(pipeline.receive(PLAYER, "loading", "RequestTestPing", good, 0).outcome).toBe("session")
		expect(#seen).toBe(0)
		expect(pipeline.strikes(PLAYER)).toBe(1)
	end)

	it("reports a handler error without a strike", function()
		local pipeline = Pipeline.new({
			remotes = Remotes,
			RateLimiter = RateLimiter,
			strikeWindowSeconds = WINDOW,
			kickAfterStrikes = KICK_AFTER,
		})
		expect(pipeline.unhandled()).toEqual({ "RequestTestPing" })
		pipeline.handle("RequestTestPing", function()
			error("boom")
		end)
		local result = pipeline.receive(PLAYER, "p", "RequestTestPing", good, 0)
		expect(result.outcome).toBe("error")
		expect(result.strikes).toBe(0)
		expect(pipeline.unhandled()).toEqual({})
	end)

	it("refuses a handler for a server-to-client remote or a second handler", function()
		local pipeline = make()
		expect(function()
			pipeline.handle("TestPong", function() end)
		end).toThrow("is not a client request")
		expect(function()
			pipeline.handle("RequestTestPing", function() end)
		end).toThrow("already has a handler")
	end)

	it("forgets a player who left", function()
		local pipeline = make()
		pipeline.receive(PLAYER, "p", "RequestTestPing", "bad", 0)
		pipeline.forget(PLAYER)
		expect(pipeline.strikes(PLAYER)).toBe(0)
	end)

	it("in audit mode records outcomes, skips handlers and never kicks", function()
		local pipeline, seen = make()
		pipeline.audit(PLAYER, true)
		local kicked = false
		for _ = 1, KICK_AFTER * 2 do
			kicked = kicked or pipeline.receive(PLAYER, "p", "RequestTestPing", "bad", 0).kick
		end
		pipeline.receive(PLAYER, "p", "RequestTestPing", good, 0)
		expect(kicked).toBe(false)
		expect(#seen).toBe(0)
		local log = pipeline.auditLog(PLAYER)
		expect(#log).toBe(KICK_AFTER * 2 + 1)
		expect(log[#log]).toBe("accepted")
		pipeline.audit(PLAYER, false)
		expect(pipeline.strikes(PLAYER)).toBe(0)
		expect(pipeline.auditLog(PLAYER)).toEqual({})
	end)
end)

describe("Abuse suite (generated from Remotes.luau)", function()
	local cases = AbuseCases.all(Remotes)

	it("covers every client request with hostile cases", function()
		local remotes: { [string]: number } = {}
		for _, case in cases do
			remotes[case.remote] = (remotes[case.remote] or 0) + 1
		end
		for name, remote in Remotes :: any do
			if remote.direction == "toServer" then
				expect((remotes[name] or 0) > AbuseCases.SPAM_COUNT).toBe(true)
			end
		end
	end)

	it("rejects every hostile request, accepts the example and limits the spam", function()
		local pipeline, seen = make()
		local outcomes = {}
		for _, case in cases do
			table.insert(outcomes, pipeline.receive(PLAYER, "p", case.remote, case.payload, 0).outcome)
		end
		expect(AbuseCases.evaluate(cases, outcomes, Remotes, 0)).toEqual({})
		-- State unchanged by anything hostile: handlers only ever saw the remote's own example.
		for _, payload in seen do
			expect(payload).toEqual(Remotes.RequestTestPing.example)
		end
	end)

	it("fails when a hostile request gets through", function()
		local outcomes = {}
		for _, case in cases do
			table.insert(outcomes, if case.expect == "rejected" then "payload" else "accepted")
		end
		outcomes[1] = "accepted"
		local failures = AbuseCases.evaluate(cases, outcomes, Remotes, 0)
		expect(failures).toEqual({
			`RequestTestPing: {cases[1].name}: expected a payload rejection, got accepted`,
			"RequestTestPing: spam let 100 through, the limit allows 4",
			"RequestTestPing: spam was never rate limited",
		})
	end)

	it("fails when requests go missing", function()
		expect(AbuseCases.evaluate(cases, {}, Remotes, 0)).toEqual({
			`the server saw 0 requests, but {#cases} were sent`,
		})
	end)
end)
