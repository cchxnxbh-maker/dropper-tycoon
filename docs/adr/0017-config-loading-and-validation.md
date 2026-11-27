# 0017. How config is loaded, checked and indexed

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decided by:** Claude's recommendation, accepted by Daniel

## Context

Plan section 5.2 asks for four guards on config: type analysis, `validate-config`, `balance`, and deep-frozen tables at
runtime. Section 4.9 asks for one `Config` module that loads every data file, validates it at startup and freezes it.
Section 6 asks for registry folders whose `init.luau` index is written by `gen-index`, and section 5.2 for
`check-literals`. The plan does not say how validation is written, where the rules live, or how the literal check
reads Luau. The same rules must run in Roblox at startup and in Lune inside the check, and a failure must read as a
plain sentence that names the file, the field and the allowed range.

## Decision

- **Our own small rule kit.** `src/shared/Logic/Validate.luau` has six rules (number, boolean, string, optional,
  record, map) plus `registry`, about 200 lines of pure Luau. Each problem is one line with the full path, such as
  `Tuning.Timing.simRate: must be at least 1, got 0`. A record rejects fields it does not know, which catches typos
  in optional fields that type analysis would let through.
- **One schema file.** `src/shared/Config/Schema.luau` holds every rule. `Config/Sources.luau` lists every data file.
  `Config/init.luau` is the loader: it checks `Sources` against `Schema`, stops with the full report when anything
  fails, and deep-freezes the result (`Util/Freeze.luau`). `tools/validate-config.luau` runs the same schema in the
  check, so a value that passes the check also loads in Studio.
- **Types in `src/shared/Types/Config.luau`.** Each data file is annotated with its type, so a missing or misspelled
  field fails type analysis before the schema runs.
- **Code reads `Config`, never a data file.** Scheduler and both `Main` scripts now do.
- **Generated indexes use `@self` requires.** `gen-index` writes `init.luau` in each registry folder (only
  `Config/Buildables` for now) with `Name = require("@self/Name")` lines. The check rewrites a stale index and fails,
  so a new file is never silently left out.
- **The literal check tokenizes.** `tools/lib/literals.luau` skips comments, strings, long brackets and the text of
  backtick strings, so digits in text or in names like `bit32` never count. It covers `src/server/Services`,
  `src/shared/Logic` and `src/client/Controllers`, as the plan says. Fixed facts, such as Rng's algorithm constants,
  carry a `-- const:` reason on their line.
- **Pure tool code lives in `tools/lib/`** and is type-checked and unit-tested. The scripts beside it only do file
  work through Lune's libraries.
- **New check order:** indexes, format, lint, types, literals, config values, unit tests. Boundaries, docs and
  `balance` slot in as their systems arrive.

## Alternatives considered

- **The `t` package already in `wally.toml`.** It needs Roblox's `script` paths to load, so Lune cannot run it, and
  its messages describe types rather than ranges and paths. `t` stays the choice for remote payloads.
- **Run the loader in the check and print its error.** Works, but a load error also carries Lune's require wrapper
  text, and a crash in one file would hide problems in the others.
- **A literal check by pattern matching lines.** Shorter, but it would flag numbers inside strings and comments, and
  people would learn to ignore it.

## Consequences

- A bad value fails `lune run check` at "Config values" with one readable line per problem, and the game refuses to
  start with the same lines if one ever reaches Studio.
- Each new config file adds a type in `Types/Config.luau`, a line in `Sources.luau` and its rules in `Schema.luau`.
- `Config` and each registry folder are ModuleScripts in Roblox, because they now have an `init.luau`.
- Changing to a different rule kit later means rewriting `Schema.luau`; the data files and the loader's interface stay.
