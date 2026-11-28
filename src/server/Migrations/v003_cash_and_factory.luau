--!strict
-- v003_cash_and_factory: version 2 to 3. Adds cash, starting at 0, and the list of owned machines, starting empty
-- (task 12, ADR 0021). Published: never edit it; add the next version as a new file.
-- Migrations require nothing, so the same file runs in Roblox and in Lune; the shape is `SaveLoad.Migration`.

return {
	from = 2,
	to = 3,
	migrate = function(data: any): any
		data.economy = { cash = 0 }
		data.factory = { owned = {} }
		return data
	end,
}
