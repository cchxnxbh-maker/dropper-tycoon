# 0008. Lune runs unit tests with a small in-repo runner

- **Status:** Accepted
- **Date:** 2026-11-16
- **Decided by:** Build plan recommendation, accepted by Daniel

## Context

The agent runs the tests after every change, so they must take seconds and run without Studio.

## Decision

Pure logic in `src/shared/Logic` never touches `game`, so Lune can run it from the terminal. Specs live in `tests/` as
`*.spec.luau` and use `tools/testkit.luau` (about 100 lines, with `describe`, `it` and `expect`). The same specs run
inside Studio for integration tests against a mock data store.

## Alternatives considered

- **Jest Lua.** Richer, with mocking and snapshots, but it runs only inside Roblox and needs an extra launcher from the
  command line. If mocking or snapshots become necessary, switching is one decision record away.

## Consequences

- Tests run in seconds. Logic must stay pure to be testable this way, which the boundary check enforces.
- We own a small runner.
