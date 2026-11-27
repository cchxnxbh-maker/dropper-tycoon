# Rng

File: `src/shared/Logic/Rng.luau`. Specs: `tests/shared/Logic/Rng.spec.luau`. Plan section 8.4, ADR 0016.

Seeded, reproducible randomness. Pure Luau, so Lune specs and the live server draw the same numbers from the same seed.

```luau
Rng.seed(sessionSeed)            -- server Main, once; the seed is logged
local loot = Rng.stream("Loot")  -- the same name always returns the same generator
loot:nextInteger(1, 6)
```

| Function | Does |
| --- | --- |
| `Rng.seed(seed)` | Sets the session seed and forgets old streams |
| `Rng.sessionSeed()` | The seed, or nil before `seed` |
| `Rng.stream(name)` | The named generator. Throws if `seed` was not called |
| `Rng.new(seed, name?)` | A standalone generator, for tests and tools |
| `gen:nextU32()` | A whole number in [0, 2^32) |
| `gen:nextNumber()` | A number in [0, 1), 53 random bits |
| `gen:nextInteger(min, max)` | A whole number in [min, max], no modulo bias |
| `gen:pick(list)` | One element of a non-empty array |
| `gen:shuffle(list)` | Shuffles in place |

Rules:

- `math.random` and `Random.new` are not used anywhere. The linter bans `math.random`.
- Give each system its own stream name, so adding draws in one system never shifts another.
- A stream depends only on the seed and its name, not on creation order.
- Algorithm: xoshiro128**, state filled by SplitMix32 from an FNV-1a hash of the name and seed. The spec pins the first
  outputs; changing them breaks saved repro bundles and needs a decision record.
