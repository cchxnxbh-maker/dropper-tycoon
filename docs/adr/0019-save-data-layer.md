# 0019. How saves are loaded, checked and changed

- **Status:** Proposed
- **Date:** 2026-11-28
- **Decided by:** Claude's recommendation, awaiting Daniel

## Context

ADR 0003 settles that saves go through ProfileStore behind `DataService`, with a schema version, one migration per
change and a stored fixture for each version. Task 9 had to fill in what the plan leaves open: what a brand-new save
looks like, what happens to a save that fails its check, how other services change data safely, which data store
Studio uses, and how a vendored file that is not ours fits the check.

## Decision

- **A new player starts at version 0.** ProfileStore gets no template and `Reconcile` is never called. A new
  player's data is the empty table, which counts as version 0, and migration `v001_initial` turns it into a version 1
  save. Every save, new or old, goes through the same migration path, so that path is exercised on every first join.
- **Migrate a copy, keep it only if it is valid.** `Logic/SaveLoad` runs the migrations in order on a deep copy and
  checks the result with `Logic/SaveSchema`, which also rejects unknown fields so a typo in a migration is caught.
  The original save is never changed. Three outcomes:
  - valid: the copy becomes the player's data and the session moves to Playing;
  - written by a newer build: the save is left alone and the player is asked to rejoin (plan 4.7);
  - fails its check, or a migration throws: the save is left alone in its own key, a copy with the reasons goes to a
    separate store, `PlayerDataQuarantine`, and the player is asked to rejoin.
- **Changes are all or nothing.** `DataService.mutate(player, reason, change)` runs `change` on a copy and keeps the
  copy only if `change` did not throw and the result still passes the schema. A bug can refuse a change but cannot
  write a save that would fail to load next time. Saves are small (under 50 KB), so the copy is cheap.
- **Session states.** `Logic/SessionState` is a four-state machine: Loading, Playing, Releasing, Ended, with the
  allowed moves in one table. `ServerNet`'s session gate is `DataService.isPlaying`, so no request is handled before
  the save has loaded. The Studio abuse suite now starts when the save has loaded.
- **Which store Studio uses.** Real servers use the real store. Studio uses the real store only on the Dev place,
  whose ID is `Config.Build.devPlaceId`; on any other place it uses ProfileStore's mock store. On the Dev place,
  ProfileStore itself falls back to the mock store when "Enable Studio Access to API Services" is off. So Studio can
  never write Live saves, and saving in Studio is something Daniel turns on for Dev on purpose. The store names
  (`PlayerData`, `PlayerDataQuarantine`) are fixed in `DataService`, not tuned in Config, because renaming one loses
  every save in it.
- **Where the pieces live.** `SaveSchema`, `SaveLoad` and `SessionState` are pure Luau in `shared/Logic` and are
  tested by Lune. They hold no secrets. Migrations are a `gen-index` registry in `server/Migrations` and require
  nothing, so Lune can run them too. One fixture per past version lives in the `tests/fixtures/saves` registry; a
  spec fails if a version has no fixture or a fixture does not migrate and validate.
- **The first schema is small.** Version 1 holds only `meta`: join count, first join and last join, which DataService
  owns. Cash, buildables and prestige arrive with their services, each as a migration. That gives Phase 1 its first
  real migration.
- **Vendored code is kept byte for byte.** ProfileStore 1.0.3 (commit 45c9847) sits in `server/Vendor` with a
  header naming its source and licence (`docs/licenses/ProfileStore-LICENSE.txt`). StyLua (`.styluaignore`), Selene
  (`exclude`) and luau-lsp (`--ignore`) skip that folder, and the `--!strict` rule does not apply to it.

## Alternatives considered

- **A ProfileStore template plus `Reconcile`.** Shorter, but it fills missing fields silently, so a missing field
  never shows up as a problem and there would be two ways a save gets its shape.
- **Fix bad saves automatically.** Guessing at someone's progress risks making it worse. Quarantine keeps the
  original so a fix can be written and tested first.
- **Validate on every autosave instead of on every change.** Cheaper, but by then the bad change is already in
  memory and the player has played on it.
- **Mock store everywhere in Studio.** Safer, but then task 9's check (a counter survives stop and start) could not
  be done, and nothing would test the real store before a server does.

## Consequences

- A broken migration or a bad change shows up as a refused load or a refused change with a log line, never as a lost
  save.
- Each schema change is three files: the migration, the schema update and a fixture of the old version.
- A quarantined player cannot play until the save is fixed. The log line names the user ID; the runbook (later) will
  say how to read the quarantine copy and restore.
- To test saving in Studio, Daniel turns on API access for the Dev place once.
