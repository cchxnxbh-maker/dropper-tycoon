# 0016. Our own seeded random generator (xoshiro128**)

- **Status:** Proposed (becomes Accepted when Daniel approves the task 6 merge)
- **Date:** 2026-11-27
- **Decided by:** Claude's recommendation, for Daniel to accept

## Context

All randomness must come from `Rng.stream(name)`, derived from a logged session seed, so a repro bundle replays a bug
exactly (plan section 8.4). `Rng` lives in `src/shared/Logic`, which must be pure Luau so Lune can test it without
Studio. Roblox's `Random` class does not exist in Lune, and its algorithm is not documented, so a sequence seen in a
Lune test is not guaranteed to match the one a live server produces. `math.random` is banned.

## Decision

`Rng` implements xoshiro128** itself, on 32-bit integers through `bit32`. A stream's state is filled by SplitMix32 from
an FNV-1a hash of the stream name mixed with the session seed. A stream depends only on the seed and its own name, never
on which streams were created first. A spec pins the first outputs for three seeds; those values were checked against
an independent Python implementation of the same steps.

## Alternatives considered

- **Roblox `Random`.** Not available in Lune, and its sequence could change with an engine update, which would break
  saved repro bundles without warning.
- **A Wally package.** Adds a dependency for about 100 lines of code, and still has to be checked for purity.
- **A simpler generator (LCG or xorshift32).** Shorter, but with visibly weaker statistics. xoshiro128** costs only a
  few more lines.

## Consequences

- Specs and the live server draw the same numbers from the same seed.
- Each draw costs a few `bit32` calls, which is fine for gameplay rolls but not meant for per-particle effects. Client
  visual noise that never affects state can use a cheap local stream.
- Changing the algorithm or the seeding breaks every saved repro bundle. The pinned-sequence spec catches it, and the
  change needs a new decision record.
