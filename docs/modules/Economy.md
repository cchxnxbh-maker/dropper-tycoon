# Economy and purchases

Files: `src/server/Services/EconomyService.luau`, `src/server/Services/PurchaseService.luau`,
`src/shared/Logic/Purchase.luau`, `src/shared/Logic/NumberFormat.luau`, `src/shared/Config/Economy.luau`,
`src/server/Net/Handlers/RequestPurchase.luau`, `src/client/Controllers/PadController.luau`,
`src/client/Views/PurchasePad.luau`, `src/client/Controllers/HudController.luau`, `src/client/UI/Screens/Hud.luau`,
`src/client/Net/ClientStore.luau`, `src/client/Net/StateSync.luau`, `src/client/Net/FactoryMirror.luau`,
`src/shared/Logic/CashDisplay.luau`, `src/shared/Logic/Balance.luau`, `tools/balance.luau`. Specs: `tests/shared/Logic/Purchase.spec.luau`,
`tests/shared/Logic/NumberFormat.spec.luau`, `tests/shared/Logic/CashDisplay.spec.luau`,
`tests/shared/Logic/Balance.spec.luau`. Plan sections 3.4, 3.6 and 4.5. Decisions: ADR 0021, ADR 0022.

```luau
EconomyService.getCash(player)                   -- 0 while the save is not loaded
EconomyService.add(player, amount, reason)       -- up to Economy.maxCash
EconomyService.trySpend(player, cost, reason)    -- saves at once
EconomyService.reset(player)                     -- dev panel only
EconomyService.cashChanged                       -- signal: (player, cash)

PurchaseService.tryPurchase(player, id)          -- nil when bought, else the reason
PurchaseService.owns(player, id)
PurchaseService.reset(player)                    -- dev panel only

Purchase.available(owned, buildables, ids)       -- which pads show
Purchase.check(request)                          -- nil, or "unknown" | "owned" | "locked" | "tooFar" | "notEnoughCash"
NumberFormat.cash(1234) --> "1,234"   NumberFormat.cash(15234) --> "15.2K"   NumberFormat.rate(2.5) --> "2.5"
```

## Cash

EconomyService holds each player's cash in memory while they play and writes it into the save every
`Tuning.Sync.cashSaveSeconds`, at once on every spend, and when the session stops. ProfileStore saves to Roblox on its
own schedule. The client gets `CashSync` at most `Tuning.Sync.cashPerSecond` times a second, only when cash changed.
Cash is never negative and never above `Economy.maxCash` (1e15, ADR 0009).

## Buying a machine or a level

1. A pad shows for each machine that is not owned and whose requirements are all owned, and stays after it is bought
   to sell the machine's next level, until `Economy.levels.maxLevel` (ADR 0023). `Purchase.offer` says what a pad
   sells; the client uses it for the labels and the server for the check.
2. The player steps on it. PadController sends `RequestPurchase { buildableId }`, and asks again every
   `Factory.padRetrySeconds` while they stand there, so it buys the moment the cash is there, and on a level pad keeps
   buying levels.
3. ServerNet checks the payload, rate and session; PurchaseService asks `Purchase.check`: the machine exists, is not
   owned (or, for a level, is owned, has levels and is below the top), its requirements are owned, the character is
   within `FactoryLayout.padRadius` of the pad, and the cash is there. A refusal is sent back as `PurchaseRefused`; the HUD shows "Not enough cash yet" for that one reason.
4. Cash is spent (and saved), the machine is saved in `factory.owned` (a level in `factory.levels`), its grey boxes
   are placed, the pads change and the factory is rebuilt. If saving fails, the cash is refunded.

Level prices: level 2 costs the machine's `levelPrice`, each next level `Economy.levels.priceGrowth` times the one
before, rounded (`Logic/Levels.luau`).

## The client copy

`ClientStore` holds `cash` (the last `CashSync`: cash and the server time it was sent) and `factory` (the last
`FactoryState`). Only `Net/StateSync.luau` writes it. The HUD shows cash and cash per second at the top of the screen.

The cash counter is predicted between server updates (ADR 0022): the last server cash plus
`FactorySim.earnedBetween` on the client's mirror of the factory (`Net/FactoryMirror`), from the step at the sync's
server time to now. `Logic/CashDisplay` eases a gap up to `Tuning.Sync.cashEaseShare` (1%) over `cashEaseSeconds`
(0.3 s) and snaps anything bigger, such as a purchase. The label changes at most `cashPerSecond` times a second.

## Pacing

`Economy.pacing` holds the targets `lune run balance` checks on every run of the check: no wait over
`maxWaitSeconds` (40) for any purchase, machine or level, and every tier 1 machine bought in between
`minTotalMinutes` and `maxTotalMinutes` (walking not counted). The simulated player buys the cheapest thing any pad
sells. Today: longest wait 22 s, about 190 purchases, every machine in about 18 minutes. Every value is a starting
value for playtests (ADR 0023).

## Known traps

- A machine removed from config stays in old saves as an unknown ID; PurchaseService ignores it with a warning. Never
  rename an ID (plan section 5.2).
- Handler refusals (`unknown`, `owned`, `maxLevel`, `locked`, `tooFar`) are logged as warnings but do not count a strike yet
  (backlog B-1).
