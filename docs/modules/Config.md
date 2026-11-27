# Config

Files: `src/shared/Config/` (`init.luau` the loader, `Sources.luau`, `Schema.luau`, the data files),
`src/shared/Types/Config.luau`, `src/shared/Logic/Validate.luau`, `src/shared/Util/Freeze.luau`.
Specs: `tests/shared/Config/`, `tests/shared/Logic/Validate.spec.luau`, `tests/shared/Util/Freeze.spec.luau`.
Plan sections 4.9 and 5. Decision: ADR 0017.

Every number someone might tune lives in a data file here. Code reads it through `Config`, which checks it and
freezes it.

```luau
local Config = require(ReplicatedStorage.Shared.Config) -- from shared code: require("../Config")
Scheduler.every("FactorySim", Config.Tuning.Timing.simRate, step)
```

## Data files

| File | Holds | Rules (in `Schema.luau`) |
| --- | --- | --- |
| `Build.luau` | `version`, the build version on every log line | Three whole numbers, like `1.2.3` |
| `Flags.luau` | `Features` switches, `Log` levels (`default` and per-tag `tags`) | Feature names camelCase and true or false; tag names PascalCase; levels debug, info, warn or error |
| `Tuning.luau` | `Timing.simRate`, `Timing.maxCatchUpSteps` | Whole numbers, 1 to 60 and 1 to 30 |
| `Buildables/` | One file per machine (none yet), indexed by `gen-index` | Each entry's `id` equals its file name |

The ranges in `Schema.luau` are limits on what is sensible, not tuning values. Tuning values stay in the data files.

## How a value is guarded

1. **Types.** Each data file is annotated with its type from `Types/Config.luau`, so a missing or misspelled field
   fails type analysis.
2. **Schema.** `lune run validate-config` (also a step of the check) runs `Schema.validate` on the raw files and
   prints one line per problem:

   ```
   Config has 1 problem. Fix these in src/shared/Config:
     Tuning.Timing.simRate: must be at least 1, got 0
   ```

3. **Startup.** `Config/init.luau` runs the same schema in Roblox and stops with the same message if anything fails.
4. **Frozen.** The loader deep-freezes every table, so a write such as `Config.Tuning.Timing.simRate = 20` throws.

## Adding a config file

1. Add its type to `Types/Config.luau` and to the `Config` type there.
2. Create the data file, annotated with that type.
3. Add it to `Sources.luau` and its rules to `Schema.luau`.
4. Add a spec case in `tests/shared/Config/Config.spec.luau` that breaks one value and expects the message.

A new file in a registry folder, such as `Buildables/`, needs none of this: `lune run gen-index` adds it to the index.

## Validate

A rule checks one value and appends a line per problem. Rules nest, keys are visited in sorted order.

| Rule | Accepts |
| --- | --- |
| `Validate.number({ integer?, min?, max? })` | A number, never NaN, inside the inclusive bounds |
| `Validate.boolean()` | true or false |
| `Validate.string({ oneOf?, pattern?, hint? })` | Text, one of a list or matching a Lua pattern; `hint` words the pattern for people |
| `Validate.optional(rule)` | nil, or a value passing `rule` |
| `Validate.record(fields)` | A table with these fields. Fields not listed are reported as misspelled |
| `Validate.map(keyRule, valueRule)` | A table whose every key and value pass their rules |
| `Validate.registry(entryRule?)` | File name to entry; each entry's `id` matches its file name |
| `Validate.run(value, rule, root)` | Runs a rule; returns the list of problem lines |

## Freeze

`Freeze.deep(value)` freezes a table and every table inside it, in place, and returns it. Already frozen tables are
skipped, so a table that contains itself does not loop.
