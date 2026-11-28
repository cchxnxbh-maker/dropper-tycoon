# Data (saves)

Files: `src/server/Services/DataService/` (`init.luau`, `Quarantine.luau`), `src/shared/Logic/SaveSchema.luau`, `src/shared/Logic/SaveLoad.luau`,
`src/shared/Logic/SessionState.luau`, `src/server/Migrations/`, `src/server/Vendor/ProfileStore.luau`.
Specs: `tests/shared/Logic/SaveLoad.spec.luau`, `tests/shared/Logic/SessionState.spec.luau`. Fixtures:
`tests/fixtures/saves/`. Plan sections 3.4, 4.7 and 12.1. Decisions: ADR 0003, 0019.

`DataService` is the only door to saved player data. Nothing else requires ProfileStore.

```luau
DataService.get(player)                      -- frozen snapshot, or nil until the save has loaded
DataService.mutate(player, "purchase", function(data) ... end)   -- true when the change was kept
DataService.isPlaying(player)                -- ServerNet's session gate
DataService.getState(player)                 -- "Loading" | "Playing" | "Releasing" | nil
DataService.profileLoaded:Connect(function(player) ... end)
DataService.profileReleasing:Connect(function(player) ... end)  -- write in-memory state now, without yielding
```

## What happens when a player joins

1. The session starts in **Loading** and ProfileStore opens the save, holding a lock so no other server can write it.
2. `SaveLoad.prepare` copies the save and runs each migration from its `schemaVersion` up to
   `SaveSchema.CURRENT_VERSION`. A new player's empty save counts as version 0.
3. The copy is checked against `SaveSchema`. Unknown fields are problems too.
4. Then one of three things:
   - **Valid.** The copy becomes the save, `meta.joins` goes up by one, the session moves to **Playing** and
     `profileLoaded` fires. The log shows `[Data] save loaded` with the join count and the store.
   - **Newer build.** The save is left alone and the player is kicked with `Strings.Data.newerSave`.
   - **Fails its check.** The save is left alone in its own key, a copy with the problems goes to the
     `PlayerDataQuarantine` store under `<userId>_<time>`, each problem is logged, and the player is kicked with
     `Strings.Data.invalidSave`. Investigate the same day (plan 12.3).

When the player leaves, the session moves to **Releasing**, `profileReleasing` fires, ProfileStore writes the last
save and releases the lock, and the session is **Ended**. ProfileStore also saves every few minutes and on shutdown.
If another server takes the session, this one ends it, fires `profileReleasing` and kicks with
`Strings.Data.sessionTaken`.

## Changing saved data

Only the service that owns a field changes it (CLAUDE.md, state ownership). `mutate` gives `change` a private copy;
the copy replaces the save only if `change` did not throw and the result passes `SaveSchema`. Otherwise it returns
false and logs an error, and the save is as it was. `change` must not yield.

## Adding a saved field

1. Raise `SaveSchema.CURRENT_VERSION` and add the field to `SaveData` and `SaveSchema.rule`.
2. Add `src/server/Migrations/v00N_<what>.luau` returning `{ from = N - 1, to = N, migrate = function(data) ... end }`.
   It sets the new field's starting value and requires nothing. Never edit a published migration.
3. Add `tests/fixtures/saves/v00N.luau`: a realistic save at the new version. Never edit a published fixture.
4. Run `lune run gen-index`, then `lune run check`. The specs migrate every fixture and check the chain has no gaps.

Saves hold IDs and counts, never prices or rates, so a rebalance never needs a migration.

## Versions so far

| Version | Migration | Adds | Owner |
| --- | --- | --- | --- |
| 1 | `v001_initial` | `meta`: joins, first and last join time | DataService |
| 2 | `v002_dev_counter` | `dev.testCounter`, the dev panel's test counter | DevService (ADR 0020) |

## Which store

| Where | Store |
| --- | --- |
| Real servers (Dev or Live experience) | The experience's real data store |
| Studio, Dev place, API access on | The Dev experience's real data store |
| Studio, Dev place, API access off | ProfileStore's mock store (ProfileStore prints "data will not be saved") |
| Studio, any other place | ProfileStore's mock store |

The mock store forgets everything when the playtest stops. To save in Studio, open the Dev place, then
**File > Experience Settings > Security > Enable Studio Access to API Services**, and save (older Studio versions call it Game Settings; stop any running playtest first).

## Vendored ProfileStore

Version 1.0.3, commit 45c9847 of `MadStudioRoblox/ProfileStore`, copied unchanged under a header. StyLua, Selene and
luau-lsp skip `src/server/Vendor`. Upgrading is its own task: replace the file, keep the header, run the check and
test saves in Studio.
