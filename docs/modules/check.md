# The check, the test runner and testkit

Files: `tools/check.luau`, `tools/test.luau`, `tools/testkit.luau`, entry points `.lune/check.luau` and
`.lune/test.luau`, hook `.githooks/pre-commit`, workflow `.github/workflows/check.yml`. Decision: ADR 0015.

## `lune run check`

Runs these steps in order and stops at the first failure:

| # | Step | Command | Fails when |
| --- | --- | --- | --- |
| 1 | Format | `stylua --check src tests tools .lune` | A file is not formatted. Fix with `stylua src tests tools .lune` |
| 2 | Lint | `selene src tests tools .lune` | Any lint error, including `wait`, `spawn`, `delay` or `math.random` |
| 3 | Types | `rojo sourcemap`, then `luau-lsp analyze` on `src`, `tests`, `tools/testkit.luau` | Any type error in strict mode |
| 4 | Unit tests | `tools/test.luau` in the same process | A spec fails or cannot load, or no spec exists |

Still to come (plan section 7.5): index regeneration (task 7) first, then `check-literals` (task 7),
`check-boundaries`, `check-docs`, `validate-config` and `balance` before the tests.

Exit code 0 means pass and 1 means fail, which is what the hook and CI read.

Type analysis needs Roblox's type definitions. The check reads the luau-lsp version from `rokit.toml` and downloads
`globalTypes.None.d.luau` for that tag into `.cache/luau-lsp-<version>/` the first time. Later runs use the cached
file and need no internet.

The `tools/check.luau` and `tools/test.luau` files use Lune's libraries, which luau-lsp does not have definitions for in
this setup, so they are formatted and linted but not type-checked.

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
