# 0003. ProfileStore for saves, behind our own DataService

- **Status:** Accepted
- **Date:** 2026-11-16
- **Decided by:** Build plan recommendation, accepted by Daniel

## Context

Player data must never be lost or duplicated, and old saves must always load after an update. Writing session locking
and retry logic over raw Roblox data stores is easy to get subtly wrong.

## Decision

Use ProfileStore, copied as one module into `src/server/Vendor/` with its version in a header comment. Only
`DataService` requires it. Every other service reads saved data through `DataService.get(player)`, which returns a
frozen snapshot, and changes it through the service that owns that piece of state.

Saves carry a schema version. Each schema change adds a migration in `src/server/Migrations/` and a stored fixture that
a test migrates and validates. Dev and Live are separate experiences, so testing never touches real saves.

## Alternatives considered

- **A custom wrapper over data stores.** Full control, but we would own session locking and its failure modes.
- **Another save library.** ProfileStore is the maintained successor to ProfileService and is widely used.

## Consequences

- Session locking and autosave come from a proven library.
- One module is the only place that can corrupt saves, which makes it easy to test with a mock store.
- Once the game is live, changing the library means migrating real player data. Treat this as close to permanent.
