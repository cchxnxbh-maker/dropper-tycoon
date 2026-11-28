# Factory

Files: `src/shared/Logic/FactorySim.luau`, `src/shared/Logic/KindTypes.luau`, `src/shared/Logic/Kinds/`,
`src/shared/Logic/FactoryLayout.luau`, `src/shared/Logic/Levels.luau`, `src/shared/Config/Factory.luau`, `src/shared/Config/Buildables/`,
`src/server/Services/FactoryService.luau`, `src/client/Controllers/FactoryViewController.luau`. Specs:
`tests/shared/Logic/FactorySim.spec.luau`, `tests/shared/Logic/FactoryLayout.spec.luau`, `tests/shared/Logic/Levels.spec.luau`. Plan sections 4.1, 4.3 and
4.4. Decisions: ADR 0002, ADR 0021, ADR 0023.

```luau
local defs = Levels.defs(Config.Buildables, ownedIds, levels)   -- owned machines with their levels
local sim = FactorySim.new(defs, { length = FactoryLayout.length(Config.Factory), rate = 10, tick = 0, starts = nil })
FactorySim.step(sim)                 -- one fixed step; returns the cash that arrived
FactorySim.skip(sim, seconds)        -- time past the catch-up cap, paid by the income rate
FactorySim.incomeRate(sim)           -- cash per second
FactorySim.starts(sim)               -- each dropper's start step, for a rebuild or the client
FactorySim.itemsAt(sim, tick, out, maxPerDropper)  -- where each item is, for drawing
FactorySim.earnedBetween(sim, fromTick, toTick)     -- cash arriving in between, without stepping

FactoryService.rebuild(player, ownedIds, levels)   -- after a purchase or on join; tells the client
FactoryService.remove(player)
FactoryService.getIncomeRate(player)
```

## How it works

One player's factory is one line: a conveyor winding across their plot, droppers above it, upgraders over it and a
collector after its end. Each machine's kind (`Logic/Kinds/<Kind>.luau`) adds it to the line, at its level
(`Logic/Levels`, ADR 0023):

| Kind | Params | What it adds | Each level above 1 |
| --- | --- | --- | --- |
| Conveyor | `speed` (studs a second) | The line runs at the fastest owned conveyor | No levels |
| Collector | `multiplier`, `perLevel` | Items are paid at the collector; the best one counts. No collector, no income | Multiplier + `perLevel` |
| Dropper | `itemValue`, `interval` (seconds), `at` (studs along the belt), `perLevel` | One item every interval | Value + `perLevel` times the base |
| Upgrader | `multiplier`, `at`, `perLevel` | Multiplies items dropped before `at` | Multiplier + `perLevel` |

No items are stored. A dropper drops on steps that are multiples of its interval (from step 0), from the step it
joined a running line; each item arrives `ceil((length - at) / speed * rate)` steps later and is worth `itemValue`
times every upgrader past it times the collector. So the step that pays is a formula, a step allocates nothing, and
the income rate is exact. A rebuild keeps the step count and every running dropper's start, so items on the belt still
arrive.

FactoryService steps every sim through the Scheduler (`FactorySim`, 10 a second) and adds what arrives to cash with
`EconomyService.add(player, amount, "factory")`. Time the Scheduler skipped is paid by the rate.

## Drawing items

After each rebuild the client gets `FactoryState`: owned IDs, levels, `starts`, the step at a server time, and the income
rate. FactoryViewController builds the same sim and every frame asks `itemsAt` for the step that matches
`workspace:GetServerTimeNow()`, then moves pooled box parts there with `BulkMoveTo`. Boxes are anchored and never
collide, touch or block. Only the player's own plot is drawn (backlog B-2).

## The machines (tier 1)

24 machines, each needing the one above it, every number a starting value (`lune run balance` shows the pacing they
give). Levels go up to `Economy.levels.maxLevel` (10), each costing `priceGrowth` (1.6) times the one before.

| Machine | Kind | Price | Level 2 | What it does |
| --- | --- | --- | --- | --- |
| StarterConveyor | Conveyor | Free | None | Belt, 8 studs a second |
| BasicCollector | Collector | Free | $44 | Pays items at 1x, +0.1 a level |
| CoalDropper | Dropper | Free | $7 | $1 every 2 s at 405 studs, +50% a level |
| CopperDropper | Dropper | $27 | $27 | $3 every 2.5 s at 390 studs, +50% a level |
| Washer | Upgrader | $88 | $73 | 1.5x at 413 studs, +0.1 a level |
| TinDropper | Dropper | $240 | $97 | $8 every 3 s at 370 studs, +50% a level |
| IronDropper | Dropper | $620 | $230 | $16 every 3 s at 350 studs, +50% a level |
| FastConveyor | Conveyor | $1,200 | None | Belt, 14 studs a second |
| Sorter | Upgrader | $1,900 | $640 | 1.5x at 360 studs, +0.1 a level |
| SilverDropper | Dropper | $3,300 | $1,100 | $35 every 3 s at 320 studs, +50% a level |
| Polisher | Upgrader | $5,700 | $1,800 | 1.5x at 335 studs, +0.1 a level |
| GoldDropper | Dropper | $9,700 | $3,100 | $70 every 3 s at 260 studs, +50% a level |
| Smelter | Upgrader | $16,000 | $5,000 | 1.5x at 240 studs, +0.1 a level |
| BigCollector | Collector | $28,000 | $8,600 | Pays items at 2x, +0.1 a level |
| EmeraldDropper | Dropper | $46,000 | $14,000 | $180 every 3.5 s at 210 studs, +50% a level |
| Painter | Upgrader | $75,000 | $23,000 | 1.5x at 185 studs, +0.1 a level |
| RubyDropper | Dropper | $120,000 | $37,000 | $380 every 3.5 s at 160 studs, +50% a level |
| Engraver | Upgrader | $200,000 | $61,000 | 1.5x at 110 studs, +0.1 a level |
| TurboConveyor | Conveyor | $310,000 | None | Belt, 22 studs a second |
| SapphireDropper | Dropper | $460,000 | $130,000 | $850 every 4 s at 90 studs, +50% a level |
| Plater | Upgrader | $740,000 | $220,000 | 1.6x at 60 studs, +0.1 a level |
| DiamondDropper | Dropper | $1,200,000 | $360,000 | $1900 every 4 s at 30 studs, +50% a level |
| Crystallizer | Upgrader | $1,900,000 | $570,000 | 1.6x at 45 studs, +0.1 a level |
| MegaCollector | Collector | $3,000,000 | $900,000 | Pays items at 3x, +0.1 a level |

A better conveyor or collector replaces the old one on the line, and only the best of each is shown
(`FactoryLayout.rank`, `PlotService/Builder.showBestOfKind`).

## Layout

`Config/Factory.luau` places the line on every plot (in plot studs; negative z is the front, where the spawn is) and
sizes the grey boxes. The line is a `path` of corners joined by runs along x or z: three rows of 120 studs joined by
two bends of 30, 420 studs in all, ending at the front row's left end with the collector. Each dropper and upgrader
has its pad beside it, on the belt's left (`FactoryLayout.padPoint`): the back two rows' pads share the wide gap
between them, and the front row's pads face the spawn. Droppers hang their post on the belt's right, away from the
pad. Conveyors and collectors are not on one spot of the belt, so their pads keep a `pad` position in config, in two
short rows near the spawn. A pad the player cannot afford yet is drawn grey (`Factory.colors.padLocked`), on that
player's screen only. `Logic/FactoryLayout` turns a machine into
boxes (one belt box per run, machines turned with the belt) and a pad into a box, and `problems` checks the factory
fits: the path runs straight and stays on the plot with its collector, every `at` is on the belt, off the bends and at
least a dropper's width from the next machine, and every pad is on the plot and clear of the spawn, the line and other
pads. `validate-config` runs it.

## Adding a machine

1. Add `src/shared/Config/Buildables/<Id>.luau` (copy one of the same kind), with its pad position and, for levels,
   a `levelPrice`.
2. Add its name to `Strings.Buildables` under its ID with a lowercase first letter.
3. Run `lune run check`. It regenerates the index and checks params, requirements, the name and the layout.

## Known traps

- Changing a conveyor's speed or a dropper's `at` changes travel times; items already on the belt arrive by the new
  numbers after the next rebuild.
- `interval` is rounded to whole steps, so 0.25 seconds at 10 steps a second becomes 0.3 (shown in the income rate).
