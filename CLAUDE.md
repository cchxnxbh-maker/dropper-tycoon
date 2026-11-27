# CLAUDE.md: rules for the coding agent

Read this file at the start of every session. It is the agent's memory between sessions, together with `docs/`.
Keep it under 200 lines. When a rule here changes, write a decision record in `docs/adr/` in the same branch.

## The project

A dropper-factory tycoon for Roblox. Droppers make items, conveyors carry them to a collector, cash buys more machines,
and rebirth trades the factory for prestige points that buy permanent perks. Six plots per server, PC first.

- **Director:** Daniel. He does not write code. He describes tasks, playtests, and approves merges and publishes.
- **Agent:** Claude Code. It writes all code, tests and docs, and checks its own work with machines, because nobody
  reviews code by eye.
- **Founding document:** the build plan ("Dropper Tycoon on Roblox Build Plan.md", kept in the project files). When
  reality differs from the plan, write a decision record. Do not rewrite the plan to match.
- **Decisions:** `docs/adr/README.md` lists every decision made so far and the ones still open.

## Three principles

1. **The repository is the memory.** If a later session needs to know it, write it in `CLAUDE.md`, `docs/` or a
   decision record. Chat history does not survive.
2. **Machines check the code, Daniel checks the game.** Type checking, lint, format and tests pass before any commit.
3. **Small steps, each one playable.** Every task ends with something Daniel can see or do in Studio.

## Forbidden actions

- Never edit scripts inside Studio. Files are the truth and Rojo syncs them in. The Studio connection is for
  playtesting, reading output, reading state and placing models.
- Never commit on a failing check. Never delete, skip or weaken a test or a check to get a pass. Changing a check needs
  a decision record and Daniel's approval.
- Never publish to the **Live** experience. Publishing to Live is Daniel's click (ADR 0014).
- Never merge to `main` without Daniel's go-ahead.
- Never put secrets, API keys or trust decisions in `src/shared` or anywhere a client can read.
- Never add a dependency (Wally package, vendored module or tool) without a decision record.
- Never change `rokit.toml` pins casually. Update them on purpose, in their own commit, with a reason.
- Never change the save schema without a new migration and a fixture test (plan section 12.1).
- Keep only the project place open in Studio while the agent is connected. Connected clients can read and change any
  open place.

## Architecture rules

Three layers: pure logic that knows nothing about Roblox, server services that own all state, client controllers that
only display it. Full detail: plan sections 3 and 4, later `docs/ARCHITECTURE.md`.

**Server authority (ADR 0002).** The server decides everything that is saved or scored: cash, purchases, ownership,
rebirths, prestige points, time. The client only asks and displays.

- Items are numbers on the server. Each client draws the parts. Dropped parts never affect cash.
- The client runs the same simulation to predict the cash counter. A gap under 1% eases to the server value over
  0.3 seconds; a larger gap snaps.
- Client time is never trusted. Logic receives `now` as an argument.

**Remotes.**

- Every remote is declared once, in `src/shared/Network/Remotes.luau`, with its payload check and rate limit. No other
  file creates a remote.
- Clients send IDs only, never prices, amounts or positions.
- RemoteEvents by default. A RemoteFunction only from client to server. The server never invokes a client.
- `ServerNet` checks every request (payload type, rate limit, session state is `Playing`) before a handler sees it.
  Handlers then check ownership, distance and price. A failure drops the request and counts a strike.

**State ownership.** Each piece of state has exactly one owner (plan section 3.4). Others read through its public
functions or listen to its signals.

| State | Owner |
| --- | --- |
| Saved player data | `DataService` (the only module that requires ProfileStore, ADR 0003) |
| Cash and multipliers | `EconomyService` |
| Prestige points, perks, unlocked tiers | `PrestigeService` |
| Owned buildables | `PurchaseService` |
| Plots and plot models | `PlotService` |
| Running factory simulation | `FactoryService` |
| Client copy of player data | `ClientStore`, written only by the network layer |

**Dependencies and communication.**

- Server services start in this order: Data, Economy, Prestige, Plot, Factory, Purchase, Offline, Leaderboard,
  Analytics, Monetization. A service may call only services earlier in the order. No circular requires.
- Need a result: call a public function. Something happened: fire a signal on the owner. Signals carry facts, never
  requests.
- No module reads another module's tables. Public functions only.
- Client code never requires server code.
- Parts and models link to code through CollectionService tags plus attributes (tag `Buildable`, attribute
  `BuildableId`). Gameplay never stores state in parts.
- No service framework (ADR 0006). Each service is a plain module with `init` and `start`. The two `Main` files stay
  thin: init everything, then start everything, in order.

**Where code goes (ADR 0004).**

| Folder | In Roblox | Holds |
| --- | --- | --- |
| `src/server` | ServerScriptService.Server | Services, Net, Migrations, Vendor (ProfileStore) |
| `src/client` | StarterPlayerScripts.Client | Controllers, UI screens, UI kit, views |
| `src/shared` | ReplicatedStorage.Shared | Config, Logic, Network, Types, Util. Assume exploiters read all of it |
| `src/first` | ReplicatedFirst.First | Loading screen only |
| `place/Game.rbxl` | the place file | Map, plot template, models (Git LFS) |

- `src/shared/Logic` is pure Luau: relative requires only, never touches `game`, iterates arrays or sorted keys (no bare
  `pairs`), never reads the clock. That is what lets Lune test it without Studio.
- All tunable numbers live in `src/shared/Config`. Asset IDs appear only in `Config/Assets.luau`. Player-facing text
  goes through `Config/Strings.luau`.
- Adding content is adding a file plus a registry entry. Core systems stay untouched.
- UI is built by code from plain view modules over a small kit (ADR 0007). StarterGui stays empty.

## Code style

- `--!strict` on line one of every module. Only the two `Main` files are Scripts; everything else is a ModuleScript.
- StyLua decides layout. PascalCase for modules and types, camelCase for functions and variables, UPPER_SNAKE for
  constants.
- `task` library only. No `wait`, `spawn`, `delay` or `math.random`. Randomness comes from `Rng.stream(name)`.
- Every connection and instance a module creates goes into a Trove.
- Public functions have full type signatures and a doc comment (parameters, return value, failure cases).
- Each module starts with a header: purpose, state it owns, one usage example.
- Comments explain why, not what. A `TODO` names a backlog item, such as `TODO(B-12)`. No commented-out code.
- Files over 300 lines should be split.

## Tools and commands

Tool versions are pinned in `rokit.toml` (ADR 0005). Packages are pinned in `wally.toml` and `wally.lock`.

| Command | What it does |
| --- | --- |
| `rokit install` | Installs the pinned tools |
| `wally install` | Downloads packages into `Packages/` |
| `rojo serve` | Syncs `src/` into Studio |
| `stylua src tests tools .lune` | Formats code |
| `lune run check` | **The check.** Must pass before every commit (ADR 0015, `docs/modules/check.md`) |
| `lune run test [filter]` | Unit tests only, optionally only specs whose path contains `filter` |

The check runs, in order and stopping at the first failure: StyLua, Selene, Rojo sourcemap plus luau-lsp analyze, then
unit tests. Index regeneration, the literal, boundary and docs checks, and config validation and balance join from
task 7. The pre-commit hook (`.githooks/pre-commit`, turned on with `git config core.hooksPath .githooks`) and GitHub
Actions (`.github/workflows/check.yml`) run the same command. Never commit with `--no-verify`.

Specs live in `tests/` as `*.spec.luau`, mirroring `src/`, and use `tools/testkit.luau` (`describe`, `it`, `expect`).

**Cloud container note.** The Wally registry and GitHub release downloads are blocked from the cloud container, so
`wally install` and `rokit install` fail there. crates.io works: build the pinned versions with
`cargo install --locked <tool> --version <pin>` (stylua needs `--features luau`), and build luau-lsp from its Git tag
with CMake. Lune and Selene do not trust the container's proxy certificate, so fetch their downloads with `curl`:
Roblox type definitions into `.cache/luau-lsp-<pin>/globalTypes.None.d.luau`, and Selene's Roblox library through a
local Selene build that reads a curl-fetched API dump. `wally.lock` is produced on Daniel's PC. Do not hand-edit it.

## The task loop

1. Take a task from Daniel or `docs/BACKLOG.md`. Restate it as acceptance criteria he can check by playing.
2. Work on one short branch per task, named `task/<number>-<slug>` (a cloud session may be assigned a different
   branch name; use that). One task, one branch, one playable result.
3. Write code, tests and docs in files. Rojo syncs them into Studio.
4. Run the check. Then start a playtest through the Studio connection and read the output log for errors.
5. Daniel plays and confirms the acceptance criteria.
6. With his go-ahead, squash-merge to `main` and add a line to `CHANGELOG.md` under Unreleased.

**Same-change rule.** A task is not done until its docs are updated in the same branch: module docs in
`docs/modules/`, decision records in `docs/adr/`, and the changelog.

**Commits.** Prefixes `feat:`, `fix:`, `data:` (config only), `docs:`, `test:`, `tool:`. Tags like `v0.3.0`, one per
milestone and per publish.

**Bugs.** Every fixed bug adds a test. Repro bundles go under `tests/fixtures/repro/`.

## Writing for Daniel

Daniel is on Windows and is new to this tooling. Anything he must run gets plain numbered steps with the exact
PowerShell commands. His clone lives at `%USERPROFILE%\dropper-tycoon`. Ask before installing or configuring anything on
his PC.

## Game rules that code must respect

- Cash stays under 1e15 per rebirth cycle. The balance tool fails if a simulated cycle goes over (ADR 0009).
- Offline earnings: capped at 2 hours at half rate, raised by perks, paid once (ADR 0009).
- Prestige rules: ADR 0010. They are Claude's recommendations that Daniel accepted, and every number is a starting
  value for the balance pass. Keep them labeled that way.
- Content stays rated Minimal or Mild. No random paid rewards, ever.

## Where to read more

- `README.md`: setup and running, for humans.
- `docs/adr/`: every decision and why.
- `docs/ARCHITECTURE.md`, `docs/modules/`, `docs/QA_CHECKLIST.md`, `docs/RUNBOOK.md`: arrive as their systems are
  built. Until then, the build plan is the reference.
