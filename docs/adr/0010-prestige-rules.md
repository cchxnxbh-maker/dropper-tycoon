# 0010. Prestige and rebirth rules

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decided by:** Claude's recommendations, accepted by Daniel. These are not Daniel's own design, and every number is a
  starting value for the first balance pass.

## Context

ADR 0009 chose a prestige currency with perks. The details were left open until Claude drafted a proposal ("Prestige
and Rebirth Proposal" doc, linked from build plan section 2), which Daniel accepted in full on 27 November 2026.

## Decision

- **A rebirth resets** cash and every machine in all tiers, including tier 3. Tier 2's progress unlock locks again.
  Unclaimed offline earnings are paid first.
- **A rebirth keeps** prestige points, perks, perk-unlocked tiers such as tier 3, lifetime cash, rebirth count,
  settings, statistics, the tutorial flag and future game passes. Timed event boosts keep running.
- **Unlock:** once the current cycle has earned 1,000,000 cash, targeted at about 45 minutes for a new player.
- **Points:** `totalPoints = floor(10 * sqrt(lifetimeCash / 1,000,000))`. A rebirth pays the difference from points
  already awarded, times Point Booster. Constants live in `Config/Economy.luau`. Repeated minimum rebirths never beat a
  longer cycle.
- **Perks in v1:** 8 perks, 20 levels, 1,680 points in all.

| Perk | Per level | Levels | Cost per level (points) | Needs first |
| --- | --- | --- | --- | --- |
| Income Boost | +50% income | 5 | 10, 25, 60, 150, 400 | Nothing |
| Faster Droppers | Dropper interval 10% shorter | 3 | 15, 50, 150 | Nothing |
| Longer Offline | Offline cap 2h to 4h, 6h, 8h | 3 | 10, 40, 120 | Nothing |
| Better Offline Rate | Offline rate 50% to 65%, 80% | 2 | 20, 80 | Longer Offline 1 |
| Head Start | Start each cycle with 1,000, then 25,000 cash | 2 | 10, 40 | Nothing |
| Bargain Builder | Tier 1 and 2 machines 10% cheaper | 2 | 30, 120 | Income Boost 2 |
| Point Booster | +10% points per rebirth | 2 | 50, 200 | Income Boost 2 |
| Unlock Tier 3 | Opens the prestige tier | 1 | 100 | Income Boost 2 |

- **No perk refunds in v1.** A respec can be added later without a save change.
- **Stacking:** levels of one perk add; different sources multiply (base income x Income Boost x Faster Droppers x
  events x game passes).
- **Build:** each perk is a data file in `Config/Perks/` with a cost and a list of effects, applied by the multiplier
  pipeline. `PrestigeService` owns points and perks.
- **Guard:** the balance tool simulates 10 rebirth cycles with the cheapest perks bought first, and fails if any cycle
  passes 1e15 cash or the first rebirth misses 45 minutes by more than 15.

## Alternatives considered

The proposal doc lists the alternatives for each rule, including points from cash this cycle, keeping tier 3 machines,
and allowing refunds.

## Consequences

- Save fields are needed for points, points awarded, perk levels, lifetime cash and rebirth count.
- The numbers will change in the balance pass. Changing a number is a `data:` commit, not a new record. Changing a rule
  (what resets, how points are earned) needs a new record.
