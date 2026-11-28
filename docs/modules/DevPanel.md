# Dev panel

Files: `src/server/Services/DevService.luau`, `src/server/DevCommands/`, `src/server/Config/DevAccess.luau`,
`src/server/Net/Handlers/RequestDevCommand.luau`, `src/client/Controllers/DevPanelController.luau`,
`src/client/UI/Screens/DevPanel.luau`, `src/client/UI/Kit/`. Plan section 4.10. Decision: ADR 0020.

A small box on the left of the screen for developers. It shows the saved test counter and one button per command:
**Add 1**, **Give cash** (`Economy.devCashGift`, $100,000) and **Reset factory**.

## Who sees it

- Everyone in a Studio playtest.
- The account that owns the experience, on any server (Dev and Live).
- The user IDs in `src/server/Config/DevAccess.luau`. That file is server-only, so exploiters cannot read it.

The server decides. It sends the panel's state (`DevPanelState`) only to allowed players, and the panel appears when
the first state arrives. A request from anyone else is dropped and logged as `[Dev] command refused: not allowed`.

## Commands

Each command is one file in `src/server/DevCommands/`, named in PascalCase, returning
`{ run = function(player): boolean }`. The client sends `RequestDevCommand { command = "<FileName>" }`; DevService
checks access, runs it, logs `[Dev] command ran` and sends the new state. After adding or removing a file, run
`lune run gen-index`.

| Command | What it does |
| --- | --- |
| `AddTestCounter` | Adds one to `dev.testCounter` in the save. The Phase 0 exit test checks it survives a rejoin |
| `GiveCash` | Adds `Config.Economy.devCashGift` cash. Studio and the Dev place only |
| `ResetFactory` | Takes every machine away and sets cash to 0, so the start can be played again. Studio and the Dev place only |

The owner sees the panel on Live too, so every command must be safe to run there, or check `game.PlaceId` itself.
