--!strict
-- v002_dev_counter: version 1 to 2. Adds the dev panel's saved test counter, starting at 0 (task 10, ADR 0020).
-- Published: never edit it; add the next version as a new file.
-- Migrations require nothing, so the same file runs in Roblox and in Lune; the shape is `SaveLoad.Migration`.

return {
	from = 1,
	to = 2,
	migrate = function(data: any): any
		data.dev = { testCounter = 0 }
		return data
	end,
}
