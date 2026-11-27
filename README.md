# Dropper Tycoon

A dropper tycoon game for Roblox. Code lives in `src/` as files under Git, and Rojo syncs it into Roblox Studio.

Task 3 replaces this README with the full one. For now it covers getting the project running.

## First-time setup (Windows)

You need Git with LFS, Rokit and Roblox Studio installed (task 1).

```powershell
git clone https://github.com/cchxnxbh-maker/dropper-tycoon.git
cd dropper-tycoon
git lfs install
rokit install          # installs Rojo, Wally, Lune, Selene and StyLua at the versions in rokit.toml
wally install          # downloads packages into Packages/ and writes wally.lock
rojo plugin install    # installs the Rojo plugin into Roblox Studio
```

If Rokit asks whether to trust a tool, answer yes. They're the tools listed in `rokit.toml`.

## Running the game in Studio

1. In the project folder, run `rojo serve`. Leave it running.
2. Open Roblox Studio and open the **Dropper Tycoon Dev** place (or `place/Game.rbxl` once it exists).
3. In Studio, open the **Plugins** tab, click **Rojo**, then **Connect**.
4. Press **Play**. The Output window should show:
   ```
   [Server] Dropper Tycoon server started
   [Client] Dropper Tycoon client started
   ```

Edit code in the files, never in Studio. Rojo pushes every saved change into Studio.

## Where things go

| Folder | In Roblox | Holds |
| --- | --- | --- |
| `src/server` | ServerScriptService.Server | All server code |
| `src/client` | StarterPlayer.StarterPlayerScripts.Client | All client code |
| `src/shared` | ReplicatedStorage.Shared | Config, pure logic, network definitions, shared types and utilities |
| `src/first` | ReplicatedFirst.First | Loading screen |
| `Packages` (generated) | ReplicatedStorage.Packages | Wally packages: Signal, Trove, t |
| `tests` | not synced | Specs run by Lune |
| `tools` | not synced | Lune scripts, such as the check |
| `place` | not synced | `Game.rbxl`, the map and models, stored with Git LFS |
