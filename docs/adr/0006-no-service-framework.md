# 0006. No service framework: plain modules with init and start

- **Status:** Accepted
- **Date:** 2026-11-16
- **Decided by:** Build plan recommendation, accepted by Daniel

## Context

Roblox games often use a framework such as Knit to wire services together. A framework adds concepts to learn and a
dependency that can go unmaintained.

## Decision

Each server service and client controller is a plain ModuleScript with `init` and `start` functions. The two `Main`
entry points require them, call every `init`, then every `start`, in a fixed order. On the server that order is Data,
Economy, Prestige, Plot, Factory, Purchase, Offline, Leaderboard, Analytics, Monetization. A service may call only
services earlier in the order.

## Alternatives considered

- **Knit or a similar framework.** Less boilerplate, but more magic, and its remote handling would conflict with our
  single definitions file (ADR 0011).

## Consequences

- Nothing hidden: the start order is readable in one file and checkable by a script.
- A little repeated boilerplate per module.
- Switching later changes wiring code, not game logic.
