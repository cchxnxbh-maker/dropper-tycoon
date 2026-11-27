# 0013. A private GitHub repository and a single place

- **Status:** Accepted (assumptions from the build plan, in use since task 1)
- **Date:** 2026-11-27
- **Decided by:** Build plan assumptions. Daniel created the private repository and the experiences in task 1

## Context

The build plan listed two assumptions that needed a yes or no: a private GitHub repository, and one place instead of
several.

## Decision

- The code lives in a private GitHub repository, `cchxnxbh-maker/dropper-tycoon`.
- The game is one place per experience. Extra worlds would be later content, and plot themes are data, so a second
  world is content work.

## Alternatives considered

- **A public repository.** Would expose server code and anti-exploit checks.
- **Several places with teleports.** Complicates saving and session locking for no v1 benefit.

## Consequences

- No teleport or cross-place save handling in v1.
- Adding places later needs a record covering how saves move between them.
