--!strict
-- AbuseCases: the abuse suite, generated from `Remotes.luau` (plan section 8.2, ADR 0011).
--
-- For every client request it builds a list of hostile requests from the remote's example: wrong types, missing and
-- unknown fields, huge text, NaN, infinity, negative numbers, deep and wide tables, then the example itself once, then
-- a spam burst of the example. `evaluate` compares what the server did with what it should have done. Because the
-- list comes from the definitions, a new remote is covered the moment it is added.
--
-- The Lune spec runs these cases against the server pipeline; in Studio the client fires them through the real
-- remotes and the server checks the outcomes. "IDs the player does not own" joins when ownership exists (task 9 on).
--
-- State owned: none.
--
-- Usage:
--     local cases = AbuseCases.all(Remotes)
--     local failures = AbuseCases.evaluate(cases, outcomes, Remotes, 0)

local Config = require("../Config")
local Net = require("./Net")

export type Expect = "rejected" | "accepted" | "limited"
export type Case = { remote: string, name: string, payload: any, expect: Expect }

local AbuseCases = {}

-- The player attribute the server sets in a Studio playtest to tell that player's client to fire the suite.
AbuseCases.ATTRIBUTE = "AbuseSuiteRunning"
-- How many copies of the example the spam burst sends at once. The plan's test is 100 calls in a second.
AbuseCases.SPAM_COUNT = 100
-- Text far past any sensible limit, to prove a long string is refused without trouble.
local HUGE_TEXT_LENGTH = 10000

local limits = Config.Tuning.Network

local function sortedKeys(value: { [any]: any }): { any }
	local keys = {}
	for key in value do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

-- A table nested one level deeper than the limit allows, counting from a value that already sits `depth` deep.
local function nested(depth: number): any
	local inner: any = { leaf = true }
	for _ = depth, limits.maxTableDepth do
		inner = { inner = inner }
	end
	return inner
end

-- A table with one more entry than the limit allows.
local function wide(): any
	local value = {}
	for index = 1, limits.maxTableEntries + 1 do
		value[index] = index
	end
	return value
end

-- Values that must never be accepted in place of a value whose valid form is `valid`, sitting `depth` tables deep.
local function badValues(valid: any, depth: number): { { name: string, value: any } }
	local kind = type(valid)
	local list = {}
	local function add(name: string, value: any)
		table.insert(list, { name = name, value = value })
	end
	if kind ~= "boolean" then
		add("a boolean", true)
	end
	if kind ~= "number" then
		add("a number", 3)
	end
	if kind ~= "string" then
		add("text", "text")
	end
	if kind ~= "table" then
		add("a table", {})
	end
	add("NaN", 0 / 0)
	add("infinity", math.huge)
	add("minus infinity", -math.huge)
	add("a negative number", -1)
	add("text one past the limit", string.rep("x", limits.maxStringLength + 1))
	add("huge text", string.rep("x", HUGE_TEXT_LENGTH))
	add("tables nested too deep", nested(depth))
	add("a table too wide", wide())
	return list
end

--[[
	Builds the cases for one client request, in the order they are sent.
	@param remote a `toServer` definition from `Remotes.luau`
	@return the cases: every hostile request (expected rejected), the example once (accepted), then the spam burst
]]
function AbuseCases.forRemote(remote: Net.ToServer): { Case }
	local cases: { Case } = {}
	local function add(name: string, payload: any, expect: Expect)
		table.insert(cases, { remote = remote.name, name = name, payload = payload, expect = expect })
	end
	local example = remote.example

	for _, bad in badValues(example, 1) do
		add(`request is {bad.name}`, bad.value, "rejected")
	end
	add("request is missing", nil, "rejected")

	if type(example) == "table" then
		local extra = table.clone(example)
		extra.unexpectedField = true
		add("request has an unknown field", extra, "rejected")
		for _, key in sortedKeys(example) do
			local missing = table.clone(example)
			missing[key] = nil
			add(`{key} is missing`, missing, "rejected")
			for _, bad in badValues(example[key], 2) do
				local changed = table.clone(example)
				changed[key] = bad.value
				add(`{key} is {bad.name}`, changed, "rejected")
			end
		end
	end

	add("the example", example, "accepted")
	for index = 1, AbuseCases.SPAM_COUNT do
		add(`spam {index}`, example, "limited")
	end
	return cases
end

--[[
	Builds the cases for every client request, remotes in name order.
	@param remotes the table from `Remotes.luau`
	@return every case, in the order they are sent
]]
function AbuseCases.all(remotes: { [string]: any }): { Case }
	local cases: { Case } = {}
	for _, name in sortedKeys(remotes) do
		local remote = remotes[name]
		if remote.direction == "toServer" then
			for _, case in AbuseCases.forRemote(remote) do
				table.insert(cases, case)
			end
		end
	end
	return cases
end

--[[
	Compares the server's outcome for each case with what it should be.
	@param cases the cases, in the order they were sent
	@param outcomes the pipeline's outcome for each, in the same order: "accepted", "payload", "rate", "session", ...
	@param remotes the table from `Remotes.luau`, for each remote's rate limit
	@param spamSeconds how long the spam burst took to arrive; the limit allows refill over that time
	@return one line per failure, empty when the server did exactly the right thing
]]
function AbuseCases.evaluate(
	cases: { Case },
	outcomes: { string },
	remotes: { [string]: any },
	spamSeconds: number
): { string }
	local failures: { string } = {}
	if #outcomes ~= #cases then
		table.insert(failures, `the server saw {#outcomes} requests, but {#cases} were sent`)
		return failures
	end
	local spam: { [string]: { accepted: number, limited: number } } = {}
	for index, case in cases do
		local outcome: string = outcomes[index]
		if case.expect == "rejected" then
			if outcome ~= "payload" then
				table.insert(failures, `{case.remote}: {case.name}: expected a payload rejection, got {outcome}`)
			end
		elseif case.expect == "accepted" then
			if outcome ~= "accepted" then
				table.insert(failures, `{case.remote}: {case.name}: expected it to be accepted, got {outcome}`)
			end
		else
			local counts = spam[case.remote] or { accepted = 0, limited = 0 }
			spam[case.remote] = counts
			if outcome == "accepted" then
				counts.accepted += 1
			elseif outcome == "rate" then
				counts.limited += 1
			else
				table.insert(failures, `{case.remote}: {case.name}: expected accepted or rate, got {outcome}`)
			end
		end
	end
	for _, name in sortedKeys(spam) do
		local counts = spam[name]
		local rate = remotes[name].rate
		-- The example already took one token, so the burst can let through at most burst - 1 plus the refill.
		local allowed = rate.burst - 1 + math.ceil(rate.perSecond * spamSeconds)
		if counts.accepted > allowed then
			table.insert(failures, `{name}: spam let {counts.accepted} through, the limit allows {allowed}`)
		end
		if counts.limited == 0 then
			table.insert(failures, `{name}: spam was never rate limited`)
		end
	end
	return failures
end

return AbuseCases
