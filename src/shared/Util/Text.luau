--!strict
-- Text: fills the `{name}` gaps in player-facing text from `Config/Strings.luau`.
--
-- A gap is a name in braces. A gap with no value is left as it is, so a missing value shows up on screen instead of
-- vanishing. Pure Luau, so Lune tests it.
--
-- State owned: none.
--
-- Usage:
--     Text.format(Config.Strings.Plot.ownerSign, { name = player.DisplayName }) -- "Daniel's factory"

local Text = {}

--[[
	Fills the gaps in a text.
	@param template text with gaps such as `{name}`
	@param values the value for each gap; numbers are written as whole numbers when they are whole
	@return the text with every known gap filled
]]
function Text.format(template: string, values: { [string]: string | number }): string
	local result = string.gsub(template, "{(%w+)}", function(name: string): string
		local value = values[name]
		if value == nil then
			return `\{{name}\}`
		end
		if type(value) == "number" and value % 1 == 0 then
			return string.format("%d", value)
		end
		return tostring(value)
	end)
	return result
end

return Text
