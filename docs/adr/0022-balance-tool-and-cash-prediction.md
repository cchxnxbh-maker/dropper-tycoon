# 0022. The balance tool joins the check; the cash counter is predicted from the client's factory mirror

- **Status:** Proposed
- **Date:** 2026-11-28
- **Decided by:** Claude's recommendation, waiting for Daniel

## Context

Phase 1 ends with twelve grey-box machines and the balance tool (plan section 10), and the plan's guard 3
(section 5.2) asks that a fresh player be simulated from config on every check, failing when a wait breaks the pacing
targets. CLAUDE.md already lists `balance` as joining the check when its system arrives; changing the check needs a
record. Separately, the cash counter jumped once per arriving item, while CLAUDE.md asks the client to predict it with
the same simulation, easing gaps under 1% over 0.3 seconds and snapping larger ones.

## Decision

1. **`lune run balance`** (`tools/balance.luau` over `Logic/Balance.luau`) plays a fresh factory with the real
   `FactorySim`: no cash, no machines, buying the cheapest available machine the moment it can (ties to the lower ID),
   with no walking time. It prints every purchase and fails when a wait exceeds `Economy.pacing.maxWaitSeconds`,
   buying everything takes outside `minTotalMinutes` to `maxTotalMinutes`, a machine is never bought, or cash reaches
   `Economy.maxCash` (ADR 0009). It runs as step 7 of the check, after `validate-config` and before the unit tests.
2. **Starting targets**: no wait over 150 seconds, and all of tier 1 in 12 to 25 minutes of simulated saving, so with
   walking a first session of about 20 minutes (the fun gate's length). The twelve machines are priced to give about
   16.5 minutes. All are starting values for playtests.
3. **Cash prediction**: `CashSync` now carries the server time it was sent. `client/Net/FactoryMirror.luau` keeps the
   client's copy of the factory sim (shared with the item drawing). The HUD shows the last server cash plus
   `FactorySim.earnedBetween` from the step at that server time to now, through `Logic/CashDisplay`: a gap up to
   `Tuning.Sync.cashEaseShare` (1%) eases over `cashEaseSeconds` (0.3 s), anything bigger snaps. The label changes at
   most `cashPerSecond` (10) times a second.
4. **Only the best conveyor and collector are drawn**, matching the simulation, so an upgrade replaces the old part on
   screen instead of drawing over it.

## Alternatives considered

- **Balance as a separate command, not in the check.** A price change could then silently break pacing; the plan wants
  the guard on every change. It takes well under a second.
- **A smarter simulated player** (saving for the best value per cash). Greedy cheapest-first is simple, close to how a
  new player plays, and gives stable numbers; it can be swapped later without changing the targets.
- **Predict cash from the income rate alone.** Simpler, but drifts between arrivals and disagrees with the server's
  step-by-step payments; the same sim gives the same numbers.

## Consequences

- Any change to a price, a dropper's value or interval, or a multiplier must keep the pacing targets, or move them in
  `Economy.pacing` on purpose.
- The check has eight steps.
- The counter can briefly show cash the server has not paid yet (at most a few steps ahead, then corrected); purchases
  are always decided by the server's number.
- The theme and name decision, still open, now takes number 0023.
