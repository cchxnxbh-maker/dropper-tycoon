--!strict
-- v004_machine_levels: version 3 to 4. Adds the level of each machine, starting empty, so every machine owned so far
-- is at level 1 (ADR 0023). Published: never edit it; add the next version as a new file.
-- Migrations require nothing, so the same file runs in Roblox and in Lune; the shape is `SaveLoad.Migration`.

return {
	from = 3,
	to = 4,
	migrate = function(data: any): any
		data.factory.levels = {}
		return data
	end,
}
