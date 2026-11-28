# Architecture

How the game is put together, as it is built today. The founding design is sections 3 and 4 of the build plan; this
file follows what the code actually does and says where it differs. Each system has its own page in `docs/modules/`,
and every decision behind it is in `docs/adr/`.

Update this file in the same branch whenever a system, boundary or owner changes (plan section 9).

## The big picture

The game has three layers.

1. **Pure logic** (`src/shared/Logic`). Plain Luau that knows nothing about Roblox: no `game`, no clock, no bare
   `pairs`. It is tested in the terminal with Lune, in seconds, without Studio.
2. **Server services** (`src/server/Services`). They own every piece of state that is saved or scored, and they are
   the only code that changes it.
3. **Client controllers** (`src/client/Controllers`). They display state and send requests. They never decide
   anything.

Between client and server there is exactly one door: the remotes listed in `src/shared/Network/Remotes.luau`.

```
            CLIENT (one per player)                         SERVER (one per game server)
  ┌──────────────────────────────────────┐      ┌───────────────────────────────────────────┐
  │ Main.client.luau                     │      │ Main.server.luau                          │
  │   Controllers: Ping, PlotSign, Hud,  │      │   Services, in start order:               │
  │   Pad, FactoryView, DevPanel         │      │   Data → Economy → Plot → Factory →       │
  │   UI: Kit, Screens (Hud, DevPanel)   │      │   Purchase → Dev                          │
  │   Views: PlotSign, PurchasePad       │      │   Net: ServerNet → Pipeline → Handlers    │
  │   Net: ClientStore ◀ StateSync       │      │                                           │
  │   Net: ClientNet ────────────────────┼──────┼─▶ (every request checked before a handler)│
  │         ◀────────────────────────────┼──────┼── ServerNet.send (state, answers)         │
  └──────────────────────────────────────┘      │   DataService ─▶ ProfileStore ─▶ stores   │
                    │                           └───────────────────────────────────────────┘
                    │      SHARED (ReplicatedStorage.Shared, both sides read it)  │
                    └──▶  Config · Logic · Network · Types · Util  ◀──────────────┘
```

Planned services (Prestige, Offline, Leaderboard, Analytics, Monetization) take their places in the order as they are
built. The full order is in the next section.

## Where code lives (ADR 0004)

| Folder | In Roblox | Holds |
| --- | --- | --- |
| `src/server` | ServerScriptService.Server | Services, Net, Migrations, DevCommands, server-only Config, Vendor, Dev |
| `src/client` | StarterPlayerScripts.Client | Controllers, Net (ClientNet), UI Kit and Screens, Views, Dev |
| `src/shared` | ReplicatedStorage.Shared | Config, Logic, Network, Types, Util. Exploiters can read all of it |
| `src/first` | ReplicatedFirst.First | Loading screen only (empty so far) |
| `Packages/` | ReplicatedStorage.Packages | Wally packages: Signal, Trove (and `t`, unused, to be removed) |
| `place/Game.rbxl` | the place file | Map and models. Plots are built by code until art arrives (ADR 0020) |

Only the two `Main` files are Scripts. Everything else is a ModuleScript with `--!strict` on line one. StarterGui stays
empty: UI is built by code (ADR 0007).

## Start-up

Both entry points stay thin: they apply log settings from config, init every module, then start every module, in
order, then drive the Scheduler from `RunService`.

**Server order (ADR 0020):** Data, Economy, Prestige, Plot, Factory, Purchase, Offline, Leaderboard, Analytics,
Monetization, Dev. Built so far: Data, Economy, Plot, Factory, Purchase, Dev. A service may call only services earlier in the order, and there
are no circular requires. Dev is last because dev commands may call anything.

After the services, `ServerNet` starts with the handler table and a session gate (`DataService.isPlaying`), and in
Studio the abuse suite runs against the real remotes.

**Client order:** ClientNet first (controllers talk through it), then StateSync (it fills ClientStore from what the
server sends), then the controllers.

The server seeds `Rng` once per session and logs the seed, so a session can be replayed (ADR 0016).

## Who owns which state

Each piece of state has exactly one owner. Others read it through the owner's public functions or listen to its
signals. Nobody reads another module's tables.

| State | Owner | Read with | Change with | Status |
| --- | --- | --- | --- | --- |
| Saved player data, session state | `DataService` | `get(player)` (frozen snapshot), `getState`, `isPlaying`, `profileLoaded` | `mutate(player, reason, fn)`, all or nothing | Built (ADR 0019) |
| Plots and plot models | `PlotService` | `getPlot(player)`, `getPlotIndex(player)` | Assigned on load, freed on leave | Built (ADR 0020) |
| Dev panel access, `dev` save section | `DevService` | `isAllowed(player)` | `run(player, command)` | Built (ADR 0020) |
| Remote instances, rate buckets, strikes | `ServerNet` | none | none | Built (ADR 0018) |
| Cash | `EconomyService` | `getCash`, `cashChanged` | `add`, `trySpend` | Built (ADR 0021) |
| Running factory simulation | `FactoryService` | `getIncomeRate` | `rebuild` | Built (ADR 0021) |
| Owned buildables | `PurchaseService` | `owns` | `tryPurchase` | Built (ADR 0021) |
| Multipliers, prestige points, perks, tiers | `PrestigeService` | `getPoints`, `hasPerk` | `rebirth`, `tryBuyPerk` | Phase 2 |
| Client copy of player data | `ClientStore` | `get(key)`, `changed(key, fn)` | Only `Net/StateSync` | Built, two entries (ADR 0021) |

Only `DataService` requires ProfileStore (ADR 0003). Saves store IDs, never prices or rates, so rebalancing never
needs a migration.

## How modules talk

| Situation | Use |
| --- | --- |
| I need a result now | Call a public function of a service earlier in the order |
| Something happened | Fire a signal on the owner. Signals carry facts, never requests |
| Client and server | A remote from `Remotes.luau`, nothing else |
| A part or model and code | A CollectionService tag plus attributes, named once in `Util/WorldKeys.luau` |

Gameplay never stores state in parts. Parts display state.

## Server authority (ADR 0002)

The server decides everything that is saved or scored: cash, purchases, ownership, rebirths, prestige points and time.
Items are numbers on the server; each client draws its own parts, and dropped parts never affect cash. The client may
run the same simulation to predict the cash counter, corrected by the server: a gap under 1% eases over 0.3 seconds, a
larger gap snaps. Client time is never trusted, and logic receives `now` as an argument.

## The network (ADR 0011, ADR 0018)

Every remote is declared once in `Remotes.luau` with a payload rule (built from `Logic/Validate`), a rate limit and a
valid example. `Network/RemoteFolder.luau` is the only code that creates remote instances.

A client request goes through this pipeline in `server/Net/Pipeline.luau` before its handler sees it:

1. Shape limits (`Network/Guard.luau`): string length, table depth and size, no instances or functions.
2. The payload rule.
3. The rate limit (a token bucket, `Logic/RateLimiter.luau`).
4. The session gate: the player's state is `Playing`.

A failure drops the request and counts a strike; 30 strikes in a minute kick the player. Handlers (one file per
request in `server/Net/Handlers/`) then check ownership, distance and price. Clients send IDs only. Remotes are
RemoteEvents, and the server never invokes a client.

`ClientNet` checks its own requests with the same rules and keeps itself to 80% of each limit, so an honest client
never trips the server. The abuse suite in `Network/AbuseCases.luau` is generated from the definitions: it runs in the
unit tests and, in Studio, through the real remotes at the start of every playtest.

## Saves (ADR 0019)

`DataService` loads a player's profile through ProfileStore, migrates a copy from its saved `schemaVersion` to the
current one (`server/Migrations/`, one file per version), checks it against `Logic/SaveSchema.luau`, and only then
marks the player `Playing`. A save from a newer build is refused untouched. A save that fails its check is copied to a
quarantine store, never overwritten, and the player is asked to rejoin. `mutate` keeps a change only if the save stays
valid. Session states are Loading, Playing, Releasing and Ended (`Logic/SessionState.luau`).

Every schema change adds a migration and a fixture in `tests/fixtures/saves/` (plan section 12.1). In Studio the real
store is used only on the Dev place with API access on; otherwise a mock store.

## The factory (ADR 0021)

Each player's factory is a `Logic/FactorySim`: one line built from the machines they own, each kind adding itself
from `Logic/Kinds/`. Items are not stored. A dropper drops on steps that are multiples of its interval and each item
arrives a fixed number of steps later, so the step that pays is a formula. FactoryService steps every sim at 10 a
second and adds what arrives through EconomyService. The client is sent the numbers to run the same sim
(`FactoryState`) and draws box items itself; no item crosses the network. Grey-box machines and purchase pads are
built by PlotService from `Logic/FactoryLayout` and `Config/Factory.luau`. Buying: the client asks when its character
is on a pad; PurchaseService checks `Logic/Purchase` (exists, not owned, requirements, distance, cash), spends, saves,
places the machine and rebuilds. Details: `docs/modules/Factory.md`, `docs/modules/Economy.md`.

## Timing (plan section 4.1)

There is no global update loop. Each system registers with `Util/Scheduler.luau`: fixed steps at their own rate
(the factory runs at 10 per second) and render callbacks on the client. `Util/FixedStep.luau` runs at most 5 steps in
one frame; time beyond that is paid by formula, so a stall never costs cash and never spirals. Results are the same at
30, 60 and 144 frames per second.

## Configuration (ADR 0017)

Every tunable number lives in `src/shared/Config`, typed by `Types/Config.luau`. `Config/init.luau` loads the files
listed in `Sources.luau`, checks them against `Schema.luau` and deep-freezes them; a bad value stops start-up with a
readable line. Registries (such as `Buildables/`) are folders with a generated `init.luau` index. Server-only values
(the dev allow-list) live in `src/server/Config`.

Logic and services keep numbers out of code: `check-literals` fails on any number other than 0, 1, 2 or -1 without a
`-- const:` reason. Player-facing text goes through `Config/Strings.luau`, asset IDs through `Config/Assets.luau`.

## The world (ADR 0020)

Six plots of 160 studs sit in a ring 250 studs from the origin, built by `PlotService` from `Config/Plots.luau`. A
player gets the lowest free plot once their save loads, and spawns there. Streaming is on (settings in
`default.project.json`): each plot streams as a whole, and a player's own plot stays loaded. Client code binds to
tagged models when they stream in and never assumes an instance exists.

## The check (ADR 0015)

`lune run check` runs, in order and stopping at the first failure: index regeneration, StyLua, Selene, Rojo sourcemap
plus luau-lsp analyze, `check-literals`, `validate-config`, then the unit tests. The pre-commit hook and GitHub Actions
run the same command. Details: `docs/modules/check.md`.

## Differences from the plan

| Plan says | Code does | Why |
| --- | --- | --- |
| `t` for payload rules | `Logic/Validate` | One rule system for config, saves and payloads (ADR 0018) |
| `Util/Signal`, `Util/Trove` | Wally packages `Signal`, `Trove` | Maintained packages (ADR 0005) |
| Plot template in the place file | Plots built by code from config | No art yet; the place file stays nearly empty (ADR 0020) |
| Rate limiter in `server/Net` | `shared/Logic/RateLimiter` | So the client can respect the same limits (ADR 0018) |
| Start order without Dev | Dev added last | Dev commands may call any service (ADR 0020) |
| Buildables name a model in ServerStorage | Buildables give a pad position; grey boxes built by code | No art until Phase 2 (ADR 0021) |
| Items move along conveyor paths | Item positions come from a formula, no item list | No allocation per step, exact income rate (ADR 0021) |
| ClientStore with path patches | Two entries, cash and factory | Enough for Phase 1 (backlog B-3) |
