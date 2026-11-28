--!strict
-- Fixture: a save at schema version 2, after a developer pressed the dev panel's test button a few times.
-- Stored fixtures are never edited once published; `tests/shared/Logic/SaveLoad.spec.luau` migrates every one.

return {
	schemaVersion = 2,
	meta = { joins = 5, firstJoin = 1795996800, lastJoin = 1796256000 },
	dev = { testCounter = 4 },
}
