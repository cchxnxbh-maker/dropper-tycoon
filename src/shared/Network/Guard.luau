--!strict
-- Guard: the shape limits every client request must pass before its own payload rule runs (plan sections 3.6 and 8.2).
--
-- Each remote's rule in `Remotes.luau` says what its fields are. Guard adds limits no rule can forget: only plain
-- data (nil, true or false, numbers, text, tables), no NaN, no infinity, no negative numbers, no huge text, no deep or
-- wide tables. Clients send IDs, never amounts or positions, so none of these limits gets in an honest request's way.
-- The limits are in `Config/Tuning.luau` under `Network`.
--
-- State owned: none.
--
-- Usage:
--     local ok, reason = Guard.check({ buildableId = "CoalDropper" })
--     -- true, nil

local Config = require("../Config")

local Guard = {}

local limits = Config.Tuning.Network

-- Checks one value. Returns nil when it is fine, or a reason naming where the problem is.
local function inspect(value: any, path: string, depth: number): string?
	local kind = type(value)
	if kind == "nil" or kind == "boolean" then
		return nil
	elseif kind == "number" then
		if value ~= value then
			return `{path}: NaN`
		elseif value == math.huge or value == -math.huge then
			return `{path}: infinite number`
		elseif value < 0 then
			return `{path}: negative number`
		end
		return nil
	elseif kind == "string" then
		if #value > limits.maxStringLength then
			return `{path}: text longer than {limits.maxStringLength} characters`
		end
		return nil
	elseif kind == "table" then
		if depth > limits.maxTableDepth then
			return `{path}: tables nested deeper than {limits.maxTableDepth}`
		end
		local count = 0
		-- Order does not matter here: any one problem rejects the whole request.
		for key, child in value do
			count += 1
			if count > limits.maxTableEntries then
				return `{path}: table with more than {limits.maxTableEntries} entries`
			end
			local keyKind = type(key)
			if keyKind == "string" then
				if #key > limits.maxStringLength then
					return `{path}: key longer than {limits.maxStringLength} characters`
				end
			elseif keyKind ~= "number" or key < 1 or key % 1 ~= 0 then
				return `{path}: key that is not text or a whole number`
			end
			local found = inspect(child, `{path}.{key}`, depth + 1)
			if found then
				return found
			end
		end
		return nil
	end
	-- Instances, vectors, functions and other Roblox values are never part of a request.
	return `{path}: {kind} is not plain data`
end

--[[
	Checks the shape limits on a client request.
	@param payload the request exactly as it arrived
	@return true when it passes; otherwise false and a reason such as `payload.buildableId: NaN`
]]
function Guard.check(payload: any): (boolean, string?)
	local reason = inspect(payload, "payload", 1)
	return reason == nil, reason
end

return Guard
