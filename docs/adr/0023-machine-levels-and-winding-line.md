# 0023. Machine levels, a winding line and faster pacing

- **Status:** Proposed
- **Date:** 2026-11-28
- **Decided by:** Daniel asked for levels, a longer track and more machines after the first fun gate; the details are
  Claude's recommendation, waiting for Daniel

## Context

The first fun gate (plan section 10, Phase 1) found the wait between purchases too long: up to about 2.5 minutes, so
the game did not give the steady stream of small rewards other droppers give. Daniel asked for a much longer track,
more things to buy, and upgrades for machines already bought. The plan allows two changes to the loop before a
rethink; this is the first.

## Decision

1. **Machine levels.** A machine with a `levelPrice` can be raised from level 1 to `Economy.levels.maxLevel` (10).
   Level 2 costs `levelPrice` and each next level `priceGrowth` (1.6) times the one before (`Logic/Levels.luau`). A
   kind opts in with a `perLevel` param: a dropper's items gain `perLevel` times the base value per level, an
   upgrader's and a collector's multiplier gain `perLevel`. Conveyors have no levels.
2. **Levels are sold on the machine's own pad.** Once a machine is bought its pad stays and sells the next level,
   until the top level. Standing on it keeps buying, one level every `Factory.padRetrySeconds` (0.5 s), while the cash
   lasts. No menu is added (Phase 1 does not allow menus). `RequestPurchase` keeps its shape: the server works out
   what the pad sells (`Purchase.offer`), so the client still sends only an ID.
3. **Save schema version 4** adds `factory.levels`: machine ID to level, only for levels above 1. A save stores
   levels, never prices (migration `v004_machine_levels`, fixture `v004`).
4. **A winding line.** `Factory.line` is now a `path` of corners joined by straight runs along x or z. The tier 1
   line runs in three rows joined by 30-stud bends, 420 studs in all (it was 90). `FactoryLayout` draws one
   belt box per run, turns machines with the belt, and checks that the path runs straight, fits the plot, and that no
   machine sits on a bend or on another machine.
5. **24 machines** in tier 1 (it was 12): 10 droppers, 8 upgraders, 3 conveyors, 3 collectors. Early droppers sit
   near the collector so their cash comes at once; later droppers sit further back so their items pass more arches.
   Each dropper's and upgrader's pad sits beside it on the belt; the bends are 30 studs so the pads fit between the
   rows. A pad the player cannot afford is drawn grey on their screen.
6. **Faster pacing targets.** `Economy.pacing.maxWaitSeconds` drops from 150 to 40, counting levels as purchases. The
   balance tool buys the cheapest thing any pad sells, machine or level, and stops once every machine is owned. The
   config gives a longest wait of 22 seconds, about 190 purchases, and every machine in about 18 minutes. Every number
   is a starting value for the next fun gate.

## Alternatives considered

- **A separate upgrade menu.** Fast to use, but Phase 1 allows no menus, and walking to pads keeps the player moving
  around the factory.
- **A level pad beside each machine pad.** Twice the pads on a plot that already holds 24; the same pad is simpler.
- **Turning bends with rotated parts.** Runs along x or z keep every box axis-aligned, which the current layout code
  and checks rely on. Real models in Phase 2 can follow the same path.

## Consequences

- A player standing on a pad right after buying a machine starts buying its levels at once. That is the intended
  "hold to upgrade" feel; it is a point to watch in the next fun gate.
- Cash now reaches millions within 20 minutes. The prestige proposal's "rebirth at 1M cash" (about 45 minutes) needs
  revisiting in the Phase 2 balance pass.
- Cash drops, a clicker boost and a parkour course follow in their own change, on top of this one.
