# Dropper Tycoon

A dropper-factory tycoon for Roblox. Droppers make items, conveyors carry them to a collector, and cash buys more
machines. When the factory is big enough, a rebirth trades it for prestige points that buy permanent perks. Six players
share a server, each with their own plot. PC first.

The name and theme are still open. Code is written by Claude Code and directed and playtested by Daniel.

**Status:** Phase 0, foundation. The repository scaffold, the agent rules and the check are in place. Connecting the
agent to Studio (task 5) and the first game systems come next.

## How the project works

- All code lives in files in `src/`. **Rojo** syncs those files into Roblox Studio while you work, so nobody edits
  scripts inside Studio.
- The map and models live in `place/Game.rbxl`.
- The agent's rules are in [`CLAUDE.md`](CLAUDE.md). Every decision and the reason for it is in
  [`docs/adr/`](docs/adr/README.md).

## First-time setup (Windows)

You need Git (with Git LFS), Rokit and Roblox Studio installed. Task 1 covered these.

1. Open **PowerShell**: press the Windows key, type `PowerShell`, press Enter.
2. Go to your home folder and download the project:
   ```powershell
   cd $HOME
   git clone https://github.com/cchxnxbh-maker/dropper-tycoon.git
   cd dropper-tycoon
   ```
   If you already have the project at `%USERPROFILE%\dropper-tycoon`, skip this step and run `cd $HOME\dropper-tycoon`.
3. Install the tools and packages:
   ```powershell
   git lfs install
   rokit install
   wally install
   rojo plugin install
   ```
   `rokit install` gets Rojo, Wally, Lune, Selene and StyLua at the exact versions in `rokit.toml`. If it asks whether
   to trust a tool, answer yes. `wally install` downloads the code packages into a `Packages` folder.
   `rojo plugin install` adds the Rojo button to Studio.

## Getting the latest changes

Each time you start a session, update your copy:

```powershell
cd $HOME\dropper-tycoon
git checkout main
git pull
wally install
```

To try a branch the agent is working on before it is merged, run `git fetch` and then `git checkout <branch-name>`.
Run `git checkout main` to go back.

## Running the game in Studio

1. In PowerShell, in the project folder, run `rojo serve`. Leave that window open.
2. Open Roblox Studio and open the **Dropper Tycoon Dev** place.
3. In Studio, open the **Plugins** tab, click **Rojo**, then **Connect**.
4. Press **Play**. The **Output** window (View tab, then Output) should show:
   ```
   [Server] Dropper Tycoon server started
   [Client] Dropper Tycoon client started
   ```
5. To stop syncing, click the PowerShell window and press **Ctrl+C**.

Every saved change to a file in `src/` appears in Studio straight away.

## Checking the code

One command decides whether a change is acceptable:

```powershell
lune run check
```

It checks formatting (StyLua), lint (Selene), types (luau-lsp) and runs the tests, and stops at the first failure.
It ends with `Check passed` or `Check FAILED at step ...`. GitHub runs the same check on every push, and the result
shows on each pull request. To run only the tests, use `lune run test`.

### Turn on the check before each commit (once per PC)

1. Open PowerShell in the project folder:
   ```powershell
   cd $HOME\dropper-tycoon
   git pull
   ```
2. Install the new type checker (luau-lsp). If Rokit asks whether to trust it, answer yes:
   ```powershell
   rokit install
   ```
3. Tell Git to use the project's hooks folder:
   ```powershell
   git config core.hooksPath .githooks
   ```
4. Run the check once. The first run downloads Roblox's type definitions, so it needs internet:
   ```powershell
   lune run check
   ```

From now on, `git commit` runs the check first and refuses the commit if it fails.

### Try it: a broken file is refused

1. Make a file with a deliberate mistake and try to commit it:
   ```powershell
   Set-Content -Path src\shared\Broken.luau -Value "--!strict`nlocal x: number = `"not a number`"`nreturn x"
   git add src\shared\Broken.luau
   git commit -m "test: this commit should be refused"
   ```
   The check prints `Check FAILED at step ...` and Git makes no commit.
2. Clean up:
   ```powershell
   git restore --staged src\shared\Broken.luau
   Remove-Item src\shared\Broken.luau
   ```

## Publishing

There are two experiences: **Dropper Tycoon Dev** for testing and **Dropper Tycoon Live** for players. Each has its own
saved data, so testing never touches real players. The agent may publish to Dev. Publishing to Live is always your
click. The full release steps will be in `docs/RUNBOOK.md`.

## Where things go

| Folder | In Roblox | Holds |
| --- | --- | --- |
| `src/server` | ServerScriptService.Server | All server code: services, network checks, save migrations |
| `src/client` | StarterPlayer.StarterPlayerScripts.Client | All client code: controllers, UI, item visuals |
| `src/shared` | ReplicatedStorage.Shared | Config, pure logic, network definitions, shared types and utilities |
| `src/first` | ReplicatedFirst.First | Loading screen |
| `Packages` (generated) | ReplicatedStorage.Packages | Wally packages: Signal, Trove, t |
| `tests` | not synced | Tests run by Lune |
| `tools` | not synced | Lune scripts, such as the check |
| `place` | not synced | `Game.rbxl`, the map and models, stored with Git LFS |
| `docs` | not synced | Decision records, and later the architecture doc, module docs, QA checklist and runbook |

## Troubleshooting

- **`rokit`, `rojo` or `wally` is "not recognized".** Close PowerShell and open a new window so it picks up the new
  tools. If that fails, run `rokit install` again in the project folder.
- **The Rojo button is missing in Studio.** Close Studio, run `rojo plugin install`, then open Studio again.
- **Rojo says it cannot connect.** Check that `rojo serve` is still running in PowerShell and shows port 34872.
- **Nothing prints when you press Play.** Make sure Rojo shows as connected before pressing Play.
- **`luau-lsp` is "not recognized" during the check.** Run `rokit install` in the project folder, then open a new
  PowerShell window.
- **The check says it could not download type definitions.** Check your internet connection and run it again. It only
  needs to download once.

## More

- [`CLAUDE.md`](CLAUDE.md): the rules the coding agent follows.
- [`docs/adr/`](docs/adr/README.md): decision records.
- [`CHANGELOG.md`](CHANGELOG.md): what changed, newest first.
