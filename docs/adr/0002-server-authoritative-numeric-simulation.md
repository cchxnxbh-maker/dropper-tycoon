# 0002. Server-authoritative simulation, with items as numbers

- **Status:** Accepted
- **Date:** 2026-11-16
- **Decided by:** Daniel (build plan section 2, "Item simulation", option B)

## Context

A dropper tycoon spawns a lot of items. If those items are physical parts on the server, an exploiter can push them
around through physics, the server pays the physics cost for six factories, and income cannot be computed exactly for
tests or offline earnings.

## Decision

The server computes items as numbers: their value and arrival time come from a pure simulation (`FactorySim` in
`src/shared/Logic`). Each client runs the same simulation only to draw the parts and to predict the cash counter. The
drawn parts have no effect on cash.

The server decides everything that is saved or scored: cash, purchases, ownership, rebirths, prestige points and time.
Clients send requests that carry IDs only, never prices, amounts or positions. The client's predicted cash is corrected
by the server value every second: a gap under 1% eases over 0.3 seconds, a larger gap snaps.

## Alternatives considered

- **A: server-side physical parts on conveyors.** Simple to picture, but open to physics exploits, nondeterministic,
  heavy on the server, and offline earnings would need a separate approximation.

## Consequences

- No physics exploits on income. Runs are deterministic, so tests and bug replays are exact.
- Offline earnings are a formula over the same simulation.
- We maintain one shared simulation module and a correction rule.
- Changing this later means rewriting `FactoryService` and the item views. Saves and config would not change.
