--!strict
-- literals: finds number literals in Luau source (plan section 5.2, "no literals in logic"). Pure, so it is
-- unit-tested; `check-literals` does the file work.
--
-- A small tokenizer walks the source and skips comments and strings (including long brackets and the text parts of
-- backtick strings, whose `{...}` parts are code), so a digit inside text or a name such as `u32` is never counted.
-- The numbers 0, 1 and 2 are allowed anywhere; -1 is a minus sign and a 1. Any other number is reported unless its
-- line carries a `-- const:` comment giving the reason.
--
-- State owned: none.
--
-- Usage:
--     literals.scan("local x = 3\n") -- { { line = 1, text = "3" } }

export type Finding = { line: number, text: string }

local ALLOWED: { [number]: true } = { [0] = true, [1] = true, [2] = true }
local EXEMPT_MARK = "const:"

local literals = {}

-- Length of a long bracket opener like `[[` or `[==[` at `index`, with its level, or nil when there is none.
local function longOpen(source: string, index: number): (number?, number?)
	local equals = string.match(source, "^%[(=*)%[", index)
	if equals == nil then
		return nil, nil
	end
	return #equals + 2, #equals
end

-- Index just past the long bracket closer for `level`, or past the end of the source when it is unclosed.
local function longClose(source: string, from: number, level: number): number
	local closer = "]" .. string.rep("=", level) .. "]"
	local found = string.find(source, closer, from, true)
	return if found then found + #closer else #source + 1
end

-- Index just past a quoted string starting at `index`, honouring backslash escapes.
local function quotedEnd(source: string, index: number, quote: string): number
	local position = index + 1
	while position <= #source do
		local char = string.sub(source, position, position)
		if char == "\\" then
			position += 2
		elseif char == quote or char == "\n" then
			return position + 1
		else
			position += 1
		end
	end
	return position
end

--[[
	Finds the number literals in `source` that are not allowed.
	@param source the text of one Luau file
	@return one finding per literal, with its 1-based line and its text as written, in source order
]]
function literals.scan(source: string): { Finding }
	local findings: { Finding } = {}
	local exemptLines: { [number]: true } = {}
	local pending: { Finding } = {}
	local line = 1
	local index = 1
	local length = #source
	-- One entry per open backtick string, counting the `{` braces open inside its current code part.
	local templates: { number } = {}

	local function advanceTo(newIndex: number)
		local _, newlines = string.gsub(string.sub(source, index, newIndex - 1), "\n", "")
		line += newlines
		index = newIndex
	end

	-- Skips the text part of a backtick string from `index`, stopping after a `{` (code follows) or the closing quote.
	local function templateText()
		local position = index
		while position <= length do
			local char = string.sub(source, position, position)
			if char == "\\" then
				position += 2
			elseif char == "`" then
				table.remove(templates)
				advanceTo(position + 1)
				return
			elseif char == "{" then
				templates[#templates] = 1
				advanceTo(position + 1)
				return
			else
				position += 1
			end
		end
		advanceTo(length + 1)
	end

	while index <= length do
		local char = string.sub(source, index, index)
		local open = #templates > 0 and templates[#templates] or nil
		if char == "\n" then
			advanceTo(index + 1)
		elseif string.sub(source, index, index + 1) == "--" then
			local size, level = longOpen(source, index + 2)
			local stop
			if size and level then
				stop = longClose(source, index + 2 + size, level)
			else
				stop = string.find(source, "\n", index, true) or length + 1
			end
			if string.find(string.sub(source, index, stop - 1), EXEMPT_MARK, 1, true) then
				exemptLines[line] = true
			end
			advanceTo(stop)
		elseif char == "[" and longOpen(source, index) then
			local size, level = longOpen(source, index)
			advanceTo(longClose(source, index + (size :: number), level :: number))
		elseif char == '"' or char == "'" then
			advanceTo(quotedEnd(source, index, char))
		elseif char == "`" then
			table.insert(templates, 0)
			advanceTo(index + 1)
			templateText()
		elseif open ~= nil and open > 0 and char == "{" then
			templates[#templates] = open + 1
			index += 1
		elseif open ~= nil and open > 0 and char == "}" then
			templates[#templates] = open - 1
			index += 1
			if open - 1 == 0 then
				templateText()
			end
		elseif string.match(char, "[%a_]") then
			local name = string.match(source, "^[%w_]+", index) :: string
			index += #name
		elseif string.match(char, "%d") or (char == "." and string.match(source, "^%.%d", index)) then
			local text = string.match(source, "^0[xX][%x_]+", index)
				or string.match(source, "^0[bB][01_]+", index)
				or string.match(source, "^[%d_]*%.?[%d_]*[eE][%+%-]?[%d_]+", index)
				or string.match(source, "^[%d_]*%.?[%d_]*", index) :: string
			local value = tonumber((string.gsub(text, "_", "")))
			if value == nil or not ALLOWED[value] then
				table.insert(pending, { line = line, text = text })
			end
			index += #text
		else
			index += 1
		end
	end

	for _, finding in pending do
		if not exemptLines[finding.line] then
			table.insert(findings, finding)
		end
	end
	return findings
end

return literals
