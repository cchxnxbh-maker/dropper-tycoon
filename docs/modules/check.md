# The check, the test runner and testkit

Files: `tools/check.luau`, `tools/test.luau`, `tools/testkit.luau`, `tools/gen-index.luau`,
`tools/check-literals.luau`, `tools/validate-config.luau`, `tools/balance.luau`, their pure parts in `tools/lib/`, entry points in `.lune/`,
hook `.githooks/pre-commit`, workflow `.github/workflows/check.yml`. Decisions: ADR 0015, ADR 0017.

## `lune run check`

Runs these steps in order and stops at the first failure:

| # | Step | Command | Fails when |
| --- | --- | --- | --- |
| 1 | Indexes | `tools/gen-index.luau` | A registry index was stale (it is rewritten, so review and commit it) or a file name cannot be an ID |
| 2 | Format | `stylua --check src tests tools .lune` | A file is not formatted. Fix with `stylua src tests tools .lune` |
| 3 | Lint | `selene src tests tools .lune` | Any lint error, including `wait`, `spawn`, `delay` or `math.random` |
| 4 | Types | `rojo sourcemap`, then `luau-lsp analyze` on `src`, `tests`, `tools/testkit.luau`, `tools/lib` | Any type error in strict mode |
| 5 | No stray numbers | `tools/check-literals.luau` | A number other than 0, 1, 2 or -1 in services, logic or controllers without a `-- const:` reason |
| 6 | Config values | `tools/validate-config.luau` | A config value breaks `Config/Schema.luau` |
| 7 | Pacing | `tools/balance.luau` | A simulated fresh factory breaks `Economy.pacing` or reaches the cash cap (ADR 0022) |
| 8 | Unit tests | `tools/test.luau` in the same process | A spec fails or cannot load, or no spec exists |

Still to come (plan section 7.5): `check-boundaries` and `check-docs` beside step 5.

## `lune run balance`

Plays a fresh factory from config (`src/shared/Logic/Balance.luau`): no cash, no machines, buying the cheapest
available machine the moment it is affordable, with no walking time. It prints each purchase with its time, the wait
before it and the income after, then fails if any wait is over `Economy.pacing.maxWaitSeconds`, buying everything
takes less than `minTotalMinutes` or more than `maxTotalMinutes`, a machine is never bought, or cash reaches
`Economy.maxCash`. Run it after changing any price or machine value.

Exit code 0 means pass and 1 means fail, which is what the hook and CI read.

Type analysis needs Roblox's type definitions. The check reads the luau-lsp version from `rokit.toml` and downloads
`globalTypes.None.d.luau` for that tag into `.cache/luau-lsp-<version>/` the first time. Later runs use the cached
file and need no internet.

The scripts in `tools/` other than `testkit.luau` use Lune's libraries, which luau-lsp does not have definitions for in
this setup, so they are formatted and linted but not type-checked. Their logic lives in `tools/lib/`, which is
type-checked and has specs in `tests/tools/lib/`.

## `lune run gen-index`

Writes the `init.luau` index of each registry folder (now `src/shared/Config/Buildables`; Perks and Modifiers later)
from the `.luau` files in it, sorted. Each entry is `Name = require("@self/Name")`. Run it after adding or removing a
registry file. File names must be letters, digits and underscores, because the name becomes the entry's ID.

## `lune run check-literals`

Scans `src/server/Services`, `src/shared/Logic` and `src/client/Controllers` and prints each number other than 0, 1,
2 or -1 with its file and line. Comments, strings and the text parts of backtick strings are skipped. To keep a number
that is a fixed fact rather than a tuning value, give its line a reason: `local SHIFT = 13 -- const: xorshift step`.
Anything tunable moves to `src/shared/Config`.

## `lune run validate-config`

Loads every config file through `Config/Sources.luau` and checks it with `Config/Schema.luau`, the same rules the game
runs at startup. Prints `Config is valid.` or one line per problem. See `docs/modules/Config.md`.

## `lune run test [filter]`

Finds every `tests/**/*.spec.luau`, in sorted path order, and runs it. With a filter, only specs whose path contains
that text run, for example `lune run test Rng`. Prints one line per failure and a summary.

## testkit

```luau
local testkit = require("../../tools/testkit") -- path from the spec file to tools/
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

describe("EconomyMath.price", function()
	it("doubles every ten levels", function()
		expect(EconomyMath.price(base, 10)).toBe(base * 2)
	end)
end)
```

Matchers: `toBe`, `toEqual` (deep, NaN equals NaN), `toBeCloseTo(expected, tolerance?)`, `toBeNil`, `toBeTruthy`,
`toThrow(fragment?)` (plain-text match), and `never.toBe`, `never.toEqual`, `never.toBeNil`.

`describe` runs its body at once to register cases. Cases run afterwards, in registration order. Each failed matcher
raises an error, which fails its case and is reported with the case's full name.

Specs mirror `src/`: a spec for `src/shared/Logic/Rng.luau` lives at `tests/shared/Logic/Rng.spec.luau`.

## The pre-commit hook

`.githooks/pre-commit` runs `lune run check` and refuses the commit when it fails. Git does not turn on hooks from a
clone by itself, so each clone runs this once:

```powershell
git config core.hooksPath .githooks
```

## CI

`.github/workflows/check.yml` runs on every push to any branch: checkout, Rokit v1.2.0 and the pinned tools,
`wally install`, then `lune run check`. The result shows on pull requests as the "Check" status.
