# 0020. The six-plot place: plots built by code, streaming in the Rojo project, a dev panel

- **Status:** Proposed
- **Date:** 2026-11-28
- **Decided by:** Claude's recommendation, waiting for Daniel

## Context

Task 10 builds the place: six empty plots in a ring, `PlotService`, streaming settings, and the Phase 0 exit test (a
player joins the Dev experience, gets a plot, presses a test button that raises a saved counter, rejoins, and the
counter is still there). ADR 0004 says the place file holds the map and the plot template. The plots are still empty
grey boxes, the theme is not chosen, and the agent cannot commit Studio edits to the place file from the cloud. The
exit test also needs a button and a saved counter, which nothing provides yet.

## Decision

- **Empty plots are built by code until the art pass.** `PlotService.init` builds `Config.Plots.count` plot bases in
  `Workspace.Plots`, placed by `Logic/PlotLayout` in a ring of radius 250 around the origin, each facing the middle,
  with a spawn pad and a sign at the front edge. Sizes and colours are in `Config/Plots.luau`; `validate-config`
  rejects plots that would overlap. When plots get art (Phase 2), a plot template model in `ServerStorage` (in the
  place file, as ADR 0004 says) replaces the code-built base, cloned once per slot at the same CFrames. Until then
  `place/Game.rbxl` holds only the default baseplate and lobby spawn and is not committed.
- **Assignment.** A player gets the lowest free plot once their save has loaded (Playing), and the plot is free
  again when they leave. With all six taken, the player is asked to rejoin. The experience's Max Players is set to 6
  so that does not happen in practice. `Logic/PlotSlots` does the bookkeeping, so it is unit-tested.
- **Spawning.** Characters spawn at the lobby SpawnLocation as usual, then PlotService moves each character of a
  player with a plot onto their spawn pad, after asking Roblox to stream that area in for them. There are no
  per-plot SpawnLocations, so a free plot can never become a spawn point.
- **Streaming settings live in `default.project.json`.** Rojo sets them on `Workspace` when it connects: streaming
  on, minimum radius 128, target radius 640 (all six plots on a PC), stream-out Opportunistic (only under memory
  pressure), integrity mode PauseOutsideLoadedArea (a player waits instead of falling through unloaded ground). They
  are numbers in a JSON file rather than in `Config` because a script cannot set them while the game runs. Each plot
  model streams as one unit, and `PersistentPerPlayer` plus `AddPersistentPlayer` keeps a player's own plot loaded.
  PlotService warns at startup if streaming is off.
- **World links.** Plot models carry the tag `Plot` and the attributes `PlotIndex`, `OwnerUserId` and `OwnerName`,
  named once in `Util/WorldKeys.luau`. The attributes display what PlotService holds; they are not the truth. The
  client draws each sign when its plot streams in (`PlotSignController`).
- **A dev panel shell.** `DevService` is a new last entry in the server start order, after Monetization, because
  dev commands may call any service. Each command is one file in `server/DevCommands/` (a registry folder, indexed
  by `gen-index`), run through one remote, `RequestDevCommand { command }`. The panel shows for every Studio
  playtest, for the account that owns the experience, and for user IDs listed in `server/Config/DevAccess.luau`
  (server-only, so exploiters cannot read it). Anyone else's request is dropped and logged. The first command,
  `AddTestCounter`, adds one to a saved counter.
- **Save schema version 2** adds `dev = { testCounter = 0 }` through migration `v002_dev_counter`, with fixture
  `v002`. DevService owns the `dev` section. It is tiny and harmless to keep; a later migration can drop it.
- **Numbering.** The theme and name decision, still open, now takes number 0021.

## Alternatives considered

- **Build the plots by hand in Studio and commit `place/Game.rbxl`.** Matches ADR 0004 to the letter, but a ring of
  grey boxes is better as data: it is reviewable, tested for overlap and changes with one number. The agent also
  cannot commit the place file from the cloud container.
- **Per-plot SpawnLocations with `Player.RespawnLocation`.** Free plots would be valid spawns for everyone, and
  teams or neutral flags would have to be managed. Moving the character is simpler and streaming-aware.
- **Use the existing join counter for the exit test.** The plan asks for a button the player presses, which also
  proves a request from the client changes saved data end to end.
- **Dev panel only in Studio.** The exit test runs on a real Dev server, so the owner needs the button there too.

## Consequences

- The plot layout is in Git, tested and changed by editing `Config/Plots.luau`.
- When art arrives, PlotService learns to clone a template model; the slots, assignment and signs stay as they are.
- On a published place, the experience owner sees the dev panel, on Live too. Every new dev command must be safe
  for that account to run on Live, or check `game.PlaceId` itself.
- Daniel sets Max Players to 6 for the Dev place, and for Live before launch.
