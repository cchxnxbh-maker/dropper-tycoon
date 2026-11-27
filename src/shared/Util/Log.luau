--!strict
-- Log: tagged, levelled log lines with structured fields (plan section 4.10).
--
-- Every line has a level, a tag naming the system, a short message and optional fields, printed in sorted key order
-- so the same event always prints the same line. Levels are debug < info < warn < error, with a default level and an
-- optional level per tag. Task 7 feeds these from `Config/Flags.luau` through `Log.configure`. Fields carry the user
-- ID and nothing more personal.
--
-- `warn` and `error` lines go to Roblox's `warn`, the rest to `print`. `Log.error` never throws.
--
-- State owned: the level settings and the output function.
--
-- Usage:
--     Log.info("Purchase", "bought", { userId = id, buildable = "CoalDropper" })
--     -- [INFO] [Purchase] bought buildable=CoalDropper userId=123

export type Level = "debug" | "info" | "warn" | "error"
export type Fields = { [string]: any }
export type Settings = { default: Level?, tags: { [string]: Level }? }
export type Sink = (level: Level, line: string) -> ()

local RANK: { [string]: number } = { debug = 1, info = 2, warn = 3, error = 4 }

local Log = {}

local defaultLevel: Level = "info"
local tagLevels: { [string]: Level } = {}

local function defaultSink(level: Level, line: string)
	if level == "warn" or level == "error" then
		warn(line)
	else
		print(line)
	end
end

local sink: Sink = defaultSink

local function formatValue(value: any): string
	if type(value) == "string" then
		if string.find(value, '[%s="]') then
			return string.format("%q", value)
		end
		return value
	end
	return tostring(value)
end

--[[
	Builds the text of a line without printing it. Exposed for tests and for the repro bundle.
	@param level the line's level
	@param tag the system name, such as "Purchase"
	@param message a short fixed message; put changing values in `fields`
	@param fields optional key-value pairs, printed sorted by key
	@return the formatted line
]]
function Log.format(level: Level, tag: string, message: string, fields: Fields?): string
	local parts = { string.format("[%s] [%s] %s", string.upper(level), tag, message) }
	if fields then
		local keys: { string } = {}
		for key in fields do
			table.insert(keys, tostring(key))
		end
		table.sort(keys)
		for _, key in keys do
			table.insert(parts, key .. "=" .. formatValue(fields[key]))
		end
	end
	return table.concat(parts, " ")
end

--[[
	Whether a line at `level` for `tag` would be written.
	@return true when the tag's level (or the default) is at or below `level`
]]
function Log.enabled(level: Level, tag: string): boolean
	return RANK[level] >= RANK[tagLevels[tag] or defaultLevel]
end

local function write(level: Level, tag: string, message: string, fields: Fields?)
	if Log.enabled(level, tag) then
		sink(level, Log.format(level, tag, message, fields))
	end
end

--[[
	Writes a debug line. Off by default; turn a tag on with `Log.configure`.
	@param tag the system name
	@param message a short fixed message
	@param fields optional key-value pairs
]]
function Log.debug(tag: string, message: string, fields: Fields?)
	write("debug", tag, message, fields)
end

--[[
	Writes an info line.
	@param tag the system name
	@param message a short fixed message
	@param fields optional key-value pairs
]]
function Log.info(tag: string, message: string, fields: Fields?)
	write("info", tag, message, fields)
end

--[[
	Writes a warning line through Roblox's `warn`.
	@param tag the system name
	@param message a short fixed message
	@param fields optional key-value pairs
]]
function Log.warn(tag: string, message: string, fields: Fields?)
	write("warn", tag, message, fields)
end

--[[
	Writes an error line through Roblox's `warn`. Does not throw, so a logged error never stops the caller.
	@param tag the system name
	@param message a short fixed message
	@param fields optional key-value pairs
]]
function Log.error(tag: string, message: string, fields: Fields?)
	write("error", tag, message, fields)
end

--[[
	Replaces the level settings. Tags not listed use the default.
	@param settings `default` level (info when nil) and optional per-tag levels
	@error when a level name is unknown
]]
function Log.configure(settings: Settings)
	local default: Level = settings.default or "info"
	assert(RANK[default] ~= nil, "Log: unknown level " .. tostring(default))
	local tags: { [string]: Level } = {}
	local given = settings.tags
	if given then
		for tag: string, level: Level in given do
			assert(RANK[level] ~= nil, "Log: unknown level " .. tostring(level) .. " for tag " .. tag)
			tags[tag] = level
		end
	end
	defaultLevel = default
	tagLevels = tags
end

--[[
	Sends lines somewhere other than the output window, such as a test's list. Pass nil to restore the default.
	@param newSink receives each written line with its level
]]
function Log.setSink(newSink: Sink?)
	sink = newSink or defaultSink
end

return Log
