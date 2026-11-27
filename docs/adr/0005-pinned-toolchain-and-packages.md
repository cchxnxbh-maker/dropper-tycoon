# 0005. Pinned toolchain through Rokit, three packages through Wally

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decided by:** Build plan recommendation, accepted by Daniel. Pins set in task 2 (PR #1)

## Context

An agent session on any machine must get exactly the same tool versions, or the check gives different answers on
different days.

## Decision

Tools are pinned in `rokit.toml` and installed with `rokit install`:

| Tool | Version | Job |
| --- | --- | --- |
| Rojo | 7.7.1 | Syncs `src/` into Studio |
| Wally | 0.3.2 | Packages, with a lockfile |
| Lune | 0.11.1 | Runs tools and pure-logic tests outside Studio |
| Selene | 0.31.0 | Lint |
| StyLua | 2.6.0 | Format |

luau-lsp is added in task 4 with `rokit add`, which pins the release current at that time.

Packages are pinned in `wally.toml` and `wally.lock`: `sleitnick/signal` 2.x, `sleitnick/trove` 1.x and
`osyrisrblx/t` 3.x. ProfileStore is vendored, not a Wally package (ADR 0003).

Pins change only on purpose, in their own commit, with a reason. Adding any dependency needs a decision record.

## Alternatives considered

- **Aftman or Foreman.** Older tool managers. Roblox's own guide now recommends Rokit.
- **Unpinned "latest" tools.** Silent upgrades would change lint and format results between sessions.

## Consequences

- Every session runs the same versions.
- The Wally registry and GitHub release downloads are blocked from the cloud container, so `wally.lock` is produced on
  Daniel's PC and tools may not install in the cloud.
