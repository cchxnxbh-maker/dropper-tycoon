--!strict
-- Freeze: deep-freezes a table so no code can change a config value by accident (plan section 5.2, guard 4).
--
-- `table.freeze` only freezes one level. This walks every nested table and freezes it too. Writing to a frozen table
-- throws, so a stray write fails loudly in testing instead of quietly changing the game's numbers.
--
-- State owned: none.
--
-- Usage:
--     local tuning = Freeze.deep({ Timing = { simRate = 10 } })
--     tuning.Timing.simRate = 20 -- throws: attempt to modify a readonly table

local Freeze = {}

--[[
	Freezes `value` and every table inside it, in place. Tables already frozen are left as they are, which also stops
	the walk from looping on a table that contains itself.
	@param value any value; non-tables are returned unchanged
	@return the same value, now frozen all the way down
]]
function Freeze.deep<T>(value: T): T
	local any: any = value
	if type(any) == "table" and not table.isfrozen(any) then
		table.freeze(any)
		for _, child in any do
			Freeze.deep(child)
		end
	end
	return value
end

return Freeze
