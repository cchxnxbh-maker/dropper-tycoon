--!strict
-- Fixture: a save at schema version 3, a player a few minutes in who owns the first four machines.
-- Stored fixtures are never edited once published; `tests/shared/Logic/SaveLoad.spec.luau` migrates every one.

return {
	schemaVersion = 3,
	meta = { joins = 2, firstJoin = 1796342400, lastJoin = 1796346000 },
	dev = { testCounter = 0 },
	economy = { cash = 42.5 },
	factory = {
		owned = { StarterConveyor = true, BasicCollector = true, CoalDropper = true, CopperDropper = true },
	},
}
