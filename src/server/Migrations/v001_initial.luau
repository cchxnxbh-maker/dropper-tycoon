--!strict
-- v001_initial: version 0 to 1. Version 0 is the empty table a brand-new player starts with, so this migration is
-- what creates every new save (ADR 0019). Published: never edit it; add the next version as a new file.
-- Migrations require nothing, so the same file runs in Roblox and in Lune; the shape is `SaveLoad.Migration`.

return {
	from = 0,
	to = 1,
	migrate = function(data: any): any
		-- Times stay 0 here: migrations never read the clock. DataService stamps them when the session starts.
		data.meta = { joins = 0, firstJoin = 0, lastJoin = 0 }
		return data
	end,
}
