--!strict
-- Dev command AddTestCounter: adds one to the saved test counter (task 10). The Phase 0 exit test presses it, rejoins
-- and checks the number is still there, which proves a change made in play is saved.
--
-- State owned: none. Changes `dev.testCounter`, which belongs to DevService.
--
-- Usage: run by `DevService.run(player, "AddTestCounter")`; never called directly.

local DataService = require(script.Parent.Parent.Services.DataService)

return {
	run = function(player: Player): boolean
		return DataService.mutate(player, "devTestCounter", function(data)
			data.dev.testCounter += 1
		end)
	end,
}
