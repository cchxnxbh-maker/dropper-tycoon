# 0021. How the first factory works: periodic items, grey boxes by code, pads, in-memory cash

- **Status:** Accepted
- **Date:** 2026-11-28
- **Decided by:** Claude's recommendation, accepted by Daniel (2026-11-28)

## Context

Phase 1 needs a factory a player can buy and watch: droppers, a conveyor, upgraders and a collector, purchase pads,
a cash counter and box items (plan section 10). ADR 0002 already says items are numbers on the server and each client
draws its own parts. Several details were left open: how items are counted without storing them, where the grey-box
machines and pads come from with no art in the place file, how often cash is written to the save, and what the client
is sent so it can draw items.

## Decision

1. **Items follow a formula, not a list.** A dropper drops on every simulation step that is a multiple of its interval
   (counted from step 0) and at or after the step it joined a running line. Every item from that dropper travels the
   same distance at the same speed, so it arrives a fixed number of steps later. `Logic/FactorySim` pays an item on the
   step `drop + travel`, using precomputed values (item value times every upgrader downstream times the collector).
   A step allocates nothing, the income rate is exact (value times steps per second over interval), and a stall past
   the catch-up cap is paid by that rate.
2. **Each kind adds itself.** `Logic/Kinds/<Kind>.luau` holds a kind's params rule and an `apply` that adds the machine
   to the line being built. The line runs with the fastest owned conveyor and the best collector; with no conveyor or
   no collector it does not run. `gen-index` now also indexes `Logic/Kinds`, so a new kind is a new file (recipe B).
3. **The client is sent numbers, never items.** `FactoryState` carries the owned IDs, each dropper's start step, the
   simulation step at a moment of `workspace:GetServerTimeNow()`, and the income rate. The client builds the same sim
   and draws boxes where `FactorySim.itemsAt` says, so they reach the collector on the step the server pays. Only the
   player's own plot is drawn for now.
4. **Grey boxes and pads are built by code** by PlotService (in `PlotService/Builder.luau`) from
   `Logic/FactoryLayout` and `Config/Factory.luau`, like the plots themselves (ADR 0020). A machine is a model tagged
   `Buildable`; a pad is a part tagged `PurchasePad`, shown only while its machine can be bought. Buildable files
   have a `pad` position instead of the plan's `model` name, until real models arrive in Phase 2. `validate-config`
   checks the factory fits on the plot and no pads overlap.
5. **Buying.** The client asks when its character touches a pad, or still stands on it, at most once per
   `Config.Factory.padRetrySeconds`. `Logic/Purchase` decides, in order: exists, not owned, requirements owned,
   character within the pad's half-diagonal plus `padReach`, enough cash. The cash is spent and saved first, then the
   machine is saved as owned; if that second write fails the cash is refunded.
6. **Cash lives in EconomyService's memory while playing** and is written to the save every
   `Tuning.Sync.cashSaveSeconds`, at once on every spend, and on `profileReleasing`. It reaches the client at most
   `Tuning.Sync.cashPerSecond` times a second, only when it changed. It never exceeds `Economy.maxCash` (ADR 0009).
7. **Save schema version 3** adds `economy.cash` (0) and `factory.owned` (a map of ID to true, empty), with migration
   `v003_cash_and_factory` and fixture `v003`. Owned IDs this build does not know are ignored with a warning.
8. **ClientStore starts small**: two entries, `cash` and `factory`, written only by `client/Net/StateSync.luau`.
   Path-based patches for the whole save wait until more state needs mirroring (backlog B-3).
9. **Start order** stays as CLAUDE.md lists it: Data, Economy, Plot, Factory, Purchase, then Dev. PlotService gains a
   `plotAssigned` signal so PurchaseService knows when to set a factory up.

Every number in the five machine files, `Config/Factory.luau` and `Config/Economy.luau` is a starting value for the
balance pass in task 13.

## Alternatives considered

- **Keep a list of items in flight on the server.** Simple to picture, but it allocates every drop, makes the step cost
  grow with the number of items, and still would not be sent to clients. The formula gives the same cash.
- **Send item spawn events to clients.** Costs bandwidth per item and fights the 10 KB a second budget (plan section
  4.12); the client can work them out itself.
- **Build pads and machines by hand in the place file.** Needs Studio work for every change and every machine, and
  cannot be checked in the terminal. Code from config is checked by `validate-config`.
- **Server-side Touched for pads.** The plan already chose client detection plus a server distance check; server
  touch events would also fire for other players walking over someone else's pads.
- **Write cash to the save on every step.** `DataService.mutate` copies and checks the whole save, so ten times a
  second per player is wasted work. ProfileStore saves to Roblox on its own schedule anyway.

## Consequences

- Adding a dropper or upgrader is one config file plus its name in `Strings.Buildables`.
- In-flight items change only slightly on a rebuild: droppers keep their start steps, but if a faster conveyor is
  bought, items already on the belt arrive by the new speed. Cash is never lost or doubled by more than one item per
  dropper at that moment.
- A crash can lose at most `cashSaveSeconds` of factory income; purchases are never lost or unpaid.
- Handler-level failures (a request for a machine the client was never shown, or from too far away) are logged but
  do not yet count a strike; the pipeline has no strike call for handlers (backlog B-1).
- The theme and name decision, still open, now takes number 0022.
