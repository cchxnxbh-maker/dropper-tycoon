--!strict
-- Specs for Log: line format, sorted fields, levels per tag, and that error lines never throw.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Log = require("../../../src/shared/Util/Log")

type Line = { level: Log.Level, line: string }

-- Captures written lines, runs `body`, then restores the default sink and levels.
local function capture(body: () -> ()): { Line }
	local lines: { Line } = {}
	Log.setSink(function(level, line)
		table.insert(lines, { level = level, line = line })
	end)
	local ok, problem = pcall(body :: any)
	Log.setSink(nil)
	Log.configure({})
	if not ok then
		error(problem, 0)
	end
	return lines
end

describe("Log.format", function()
	it("prints level, tag, message and fields sorted by key", function()
		local line = Log.format("info", "Purchase", "bought", { userId = 123, buildable = "CoalDropper" })
		expect(line).toBe("[INFO] [Purchase] bought buildable=CoalDropper userId=123")
	end)

	it("quotes strings with spaces or equals signs", function()
		expect(Log.format("warn", "Net", "dropped", { reason = "bad payload" })).toBe(
			'[WARN] [Net] dropped reason="bad payload"'
		)
	end)

	it("works without fields", function()
		expect(Log.format("debug", "Boot", "ready")).toBe("[DEBUG] [Boot] ready")
	end)
end)

describe("Log levels", function()
	it("writes info and above by default, not debug", function()
		local lines = capture(function()
			Log.debug("A", "hidden")
			Log.info("A", "shown")
			Log.warn("A", "shown")
			Log.error("A", "shown")
		end)
		expect(#lines).toBe(3)
		expect(lines[1].level).toBe("info")
		expect(lines[3].level).toBe("error")
	end)

	it("uses a tag's own level over the default", function()
		local lines = capture(function()
			Log.configure({ default = "warn", tags = { Economy = "debug" } :: { [string]: Log.Level } })
			Log.info("Purchase", "hidden")
			Log.debug("Economy", "shown")
		end)
		expect(#lines).toBe(1)
		expect(lines[1].line).toBe("[DEBUG] [Economy] shown")
	end)

	it("rejects an unknown level", function()
		expect(function()
			Log.configure({ default = "loud" :: any })
		end).toThrow("unknown level")
		expect(function()
			Log.configure({ tags = { Net = "chatty" :: any } })
		end).toThrow("for tag Net")
	end)

	it("error lines do not throw", function()
		local lines = capture(function()
			Log.error("Data", "save failed", { userId = 1 })
		end)
		expect(lines[1].line).toBe("[ERROR] [Data] save failed userId=1")
	end)
end)

describe("Log.setBuild", function()
	it("starts every line with the build version until cleared", function()
		Log.setBuild("0.3.0")
		local withBuild = Log.format("info", "Server", "started", { seed = 7 })
		Log.setBuild(nil)
		expect(withBuild).toBe("[v0.3.0] [INFO] [Server] started seed=7")
		expect(Log.format("info", "Server", "started")).toBe("[INFO] [Server] started")
	end)

	it("lists every level, lowest first", function()
		expect(Log.LEVELS).toEqual({ "debug", "info", "warn", "error" })
		for _, level: Log.Level in Log.LEVELS do
			expect(Log.enabled(level, "Anything")).toBe(level ~= "debug")
		end
	end)
end)
