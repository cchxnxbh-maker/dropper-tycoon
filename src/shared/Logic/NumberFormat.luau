--!strict
-- NumberFormat: how cash and rates are written for players (plan section 4.5). Short suffixes keep big numbers
-- readable: 1,234 stays whole, then 12.3K, 4.56M and so on up to the cash cap.
--
-- Pure Luau. State owned: none.
--
-- Usage:
--     NumberFormat.cash(15234) --> "15.2K"

local NumberFormat = {}

-- Each step is a thousand times the last. Q is a quadrillion, 1e15, the cash cap (ADR 0009).
local SUFFIXES = { "K", "M", "B", "T", "Q" }
local THOUSAND = 1000 -- const: the step between suffixes, not a tuning value
local SIGNIFICANT = 3 -- const: digits shown with a suffix, such as 12.3K

local function withCommas(whole: number): string
	local text = tostring(whole)
	local groups: { string } = {}
	while #text > SIGNIFICANT do
		table.insert(groups, 1, string.sub(text, -SIGNIFICANT))
		text = string.sub(text, 1, -SIGNIFICANT - 1)
	end
	table.insert(groups, 1, text)
	return table.concat(groups, ",")
end

--[[
	Writes an amount of cash for a player.
	@param amount any number; negatives and fractions are rounded down to a whole, non-negative amount
	@return below 10,000 the whole number with commas; above, three significant digits and a suffix
]]
function NumberFormat.cash(amount: number): string
	local whole = math.max(0, math.floor(if amount == amount then amount else 0))
	if whole < 10 * THOUSAND then -- const: whole numbers read better than 1.23K up to ten thousand
		return withCommas(whole)
	end
	local value = whole
	local suffix = ""
	for _, next in SUFFIXES do
		if value < THOUSAND then
			break
		end
		value /= THOUSAND
		suffix = next
	end
	-- Round down, never up, so 999.99K shows as 999K and not as 1000K.
	local decimals = if value >= 100 then 0 elseif value >= 10 then 1 else 2 -- const: three significant digits
	local scale = 10 ^ decimals -- const: decimal places to a scale factor
	-- The small nudge stops 4.56 stored as 4.5599999 from showing as 4.55.
	local shown = math.floor(value * scale + 1e-9) / scale -- const: below any real digit, above float error
	return string.format(`%.{decimals}f`, shown) .. suffix
end

--[[
	Writes cash per second for a player. Small rates keep one decimal, since a starting factory makes a few a second.
	@param perSecond any number; negatives and NaN count as 0
	@return below 100 one decimal place, dropped when it is 0 (2.5, 3); from 100 the same as `cash`
]]
function NumberFormat.rate(perSecond: number): string
	local value = math.max(0, if perSecond == perSecond then perSecond else 0)
	if value >= 100 then -- const: from here, whole numbers are precise enough
		return NumberFormat.cash(value)
	end
	local tenths = math.floor(value * 10 + 1e-9) -- const: one decimal place; the nudge absorbs float error
	if tenths % 10 == 0 then -- const: a whole number of tenths
		return tostring(tenths // 10) -- const: tenths to wholes
	end
	return string.format("%.1f", tenths / 10) -- const: tenths to a decimal
end

return NumberFormat
