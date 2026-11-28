# Factory

Files: `src/shared/Logic/FactorySim.luau`, `src/shared/Logic/KindTypes.luau`, `src/shared/Logic/Kinds/`,
`src/shared/Logic/FactoryLayout.luau`, `src/shared/Config/Factory.luau`, `src/shared/Config/Buildables/`,
`src/server/Services/FactoryService.luau`, `src/client/Controllers/FactoryViewController.luau`. Specs:
`tests/shared/Logic/FactorySim.spec.luau`, `tests/shared/Logic/FactoryLayout.spec.luau`. Plan sections 4.1, 4.3 and
4.4. Decisions: ADR 0002, ADR 0021.

```luau
local sim = FactorySim.new(defs, { length = 90, rate = 10, tick = 0, starts = nil })
FactorySim.step(sim)                 -- one fixed step; returns the cash that arrived
FactorySim.skip(sim, seconds)        -- time past the catch-up cap, paid by the income rate
FactorySim.incomeRate(sim)           -- cash per second
FactorySim.starts(sim)               -- each dropper's start step, for a rebuild or the client
FactorySim.itemsAt(sim, tick, out, maxPerDropper)  -- where each item is, for drawing
FactorySim.earnedBetween(sim, fromTick, toTick)     -- cash arriving in between, without stepping

FactoryService.rebuild(player, ownedIds)   -- after a purchase or on join; tells the client
FactoryService.remove(player)
FactoryService.getIncomeRate(player)
```

## How it works

One player's factory is one line: a straight conveyor on their plot, droppers above it, upgraders over it and a
collector after its end. Each machine's kind (`Logic/Kinds/<Kind>.luau`) adds it to the line:

| Kind | Params | What it adds |
| --- | --- | --- |
| Conveyor | `speed` (studs a second) | The line runs at the fastest owned conveyor |
| Collector | `multiplier` | Items are paid at the collector; the best one counts. No collector, no income |
| Dropper | `itemValue`, `interval` (seconds), `at` (studs along the belt) | One item every interval |
| Upgrader | `multiplier`, `at` | Multiplies items dropped before `at` |

No items are stored. A dropper drops on steps that are multiples of its interval (from step 0), from the step it
joined a running line; each item arrives `ceil((length - at) / speed * rate)` steps later and is worth `itemValue`
times every upgrader past it times the collector. So the step that pays is a formula, a step allocates nothing, and
the income rate is exact. A rebuild keeps the step count and every running dropper's start, so items on the belt still
arrive.

FactoryService steps every sim through the Scheduler (`FactorySim`, 10 a second) and adds what arrives to cash with
`EconomyService.add(player, amount, "factory")`. Time the Scheduler skipped is paid by the rate.

## Drawing items

After each rebuild the client gets `FactoryState`: owned IDs, `starts`, the step at a server time, and the income
rate. FactoryViewController builds the same sim and every frame asks `itemsAt` for the step that matches
`workspace:GetServerTimeNow()`, then moves pooled box parts there with `BulkMoveTo`. Boxes are anchored and never
collide, touch or block. Only the player's own plot is drawn (backlog B-2).

## The machines (tier 1)

Twelve machines, every number a starting value (`lune run balance` shows the pacing they give):

| Machine | Kind | Price | What it does | Needs |
| --- | --- | --- | --- | --- |
| StarterConveyor | Conveyor | Free | Belt, 8 studs a second | |
| BasicCollector | Collector | Free | Pays items at 1x | StarterConveyor |
| CoalDropper | Dropper | Free | $2 every 2 s | BasicCollector |
| CopperDropper | Dropper | $30 | $5 every 2.5 s | CoalDropper |
| Washer | Upgrader | $150 | 1.5x at 60 studs | CopperDropper |
| IronDropper | Dropper | $500 | $12 every 3 s | CopperDropper |
| FastConveyor | Conveyor | $900 | Belt, 14 studs a second | Washer |
| SilverDropper | Dropper | $1,500 | $30 every 3 s | IronDropper |
| Polisher | Upgrader | $3,500 | 2x at 75 studs | SilverDropper, Washer |
| GoldDropper | Dropper | $7,000 | $80 every 4 s | SilverDropper |
| BigCollector | Collector | $16,000 | Pays items at 1.5x | Polisher |
| DiamondDropper | Dropper | $22,000 | $250 every 5 s | GoldDropper, BigCollector |

A better conveyor or collector replaces the old one on the line, and only the best of each is shown
(`FactoryLayout.rank`, `PlotService/Builder.showBestOfKind`).

## Layout

`Config/Factory.luau` places the line on every plot (in plot studs; negative z is the front, where the spawn is) and
sizes the grey boxes. `Logic/FactoryLayout` turns a machine into boxes and a pad into a box, and `problems` checks
the factory fits: line and collector on the plot, every `at` on the belt, every pad on the plot and clear of the
spawn, the line and other pads. `validate-config` runs it.

## Adding a machine

1. Add `src/shared/Config/Buildables/<Id>.luau` (copy one of the same kind), with its pad position.
2. Add its name to `Strings.Buildables` under its ID with a lowercase first letter.
3. Run `lune run check`. It regenerates the index and checks params, requirements, the name and the layout.

## Known traps

- Changing a conveyor's speed or a dropper's `at` changes travel times; items already on the belt arrive by the new
  numbers after the next rebuild.
- `interval` is rounded to whole steps, so 0.25 seconds at 10 steps a second becomes 0.3 (shown in the income rate).
