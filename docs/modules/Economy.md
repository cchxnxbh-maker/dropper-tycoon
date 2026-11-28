# Economy and purchases

Files: `src/server/Services/EconomyService.luau`, `src/server/Services/PurchaseService.luau`,
`src/shared/Logic/Purchase.luau`, `src/shared/Logic/NumberFormat.luau`, `src/shared/Config/Economy.luau`,
`src/server/Net/Handlers/RequestPurchase.luau`, `src/client/Controllers/PadController.luau`,
`src/client/Views/PurchasePad.luau`, `src/client/Controllers/HudController.luau`, `src/client/UI/Screens/Hud.luau`,
`src/client/Net/ClientStore.luau`, `src/client/Net/StateSync.luau`. Specs: `tests/shared/Logic/Purchase.spec.luau`,
`tests/shared/Logic/NumberFormat.spec.luau`. Plan sections 3.4, 3.6 and 4.5. Decision: ADR 0021.

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

## Buying a machine

1. A pad shows for each machine that is not owned and whose requirements are all owned.
2. The player steps on it. PadController sends `RequestPurchase { buildableId }`, and asks again every
   `Factory.padRetrySeconds` while they stand there, so it buys the moment the cash is there.
3. ServerNet checks the payload, rate and session; PurchaseService asks `Purchase.check`: the machine exists, is not
   owned, its requirements are owned, the character is within `FactoryLayout.padRadius` of the pad, and the cash is
   there. A refusal is sent back as `PurchaseRefused`; the HUD shows "Not enough cash yet" for that one reason.
4. Cash is spent (and saved), the machine is saved in `factory.owned`, its grey boxes are placed, the pads change and
   the factory is rebuilt. If saving the machine fails, the cash is refunded.

## The client copy

`ClientStore` holds `cash` and `factory` (the last `FactoryState`). Only `Net/StateSync.luau` writes it. The HUD shows
cash and cash per second at the top of the screen.

## Known traps

- A machine removed from config stays in old saves as an unknown ID; PurchaseService ignores it with a warning. Never
  rename an ID (plan section 5.2).
- Handler refusals (`unknown`, `owned`, `locked`, `tooFar`) are logged as warnings but do not count a strike yet
  (backlog B-1).
