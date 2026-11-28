--!strict
-- Fixture: a save at schema version 4, a player a few minutes in who has raised two machines above level 1.
-- Stored fixtures are never edited once published; `tests/shared/Logic/SaveLoad.spec.luau` migrates every one.

return {
	schemaVersion = 4,
	meta = { joins = 3, firstJoin = 1796342400, lastJoin = 1796349600 },
	dev = { testCounter = 0 },
	economy = { cash = 310.5 },
	factory = {
		owned = { StarterConveyor = true, BasicCollector = true, CoalDropper = true, CopperDropper = true },
		levels = { CoalDropper = 4, CopperDropper = 2 },
	},
}
