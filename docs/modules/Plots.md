# Plots

Files: `src/server/Services/PlotService/` (`init.luau` holds who has which plot, `Builder.luau` makes the parts), `src/shared/Logic/PlotLayout.luau`, `src/shared/Logic/PlotSlots.luau`,
`src/shared/Config/Plots.luau`, `src/shared/Util/WorldKeys.luau`, `src/client/Controllers/PlotSignController.luau`,
`src/client/Views/PlotSign.luau`, streaming settings in `default.project.json`. Specs:
`tests/shared/Logic/PlotLayout.spec.luau`, `tests/shared/Logic/PlotSlots.spec.luau`. Plan sections 3.4, 4.4 and 4.8.
Decision: ADR 0020.

```luau
PlotService.getPlot(player)        -- the player's plot Model, or nil while loading
PlotService.getPlotIndex(player)   -- 1 to 6, or nil
PlotService.plotAssigned           -- signal: (player) once they have a plot
PlotService.placeMachine(player, def)   -- grey-box parts of a bought machine, in the plot's Machines folder
PlotService.showPads(player, defs)      -- replaces the purchase pads, in the plot's Pads folder
PlotService.clearFactory(player)        -- removes every machine and pad
PlotService.toWorld(player, point)      -- a plot point from config, in world space
```

The factory parts are described in `docs/modules/Factory.md`.

## The layout

Six square plots of 160 studs sit in a ring 250 studs from the origin, plot 1 on the +X axis and the rest
counter-clockwise seen from above. Each faces the middle, so its spawn pad and sign are at the edge nearest the lobby
spawn. Everything is built at server start in `Workspace.Plots`, from `Config/Plots.luau`. Each plot model holds:

| Part | What it is |
| --- | --- |
| `Base` | The ground of the plot, the model's primary part |
| `Spawn` | The yellow pad where the owner's character arrives |
| `Sign` | Shows the owner and the plot number. The client writes the text |

The model's pivot is the centre of the base's top face, facing the middle. `validate-config` fails if a change to
`Config/Plots.luau` would make neighbours overlap or put the spawn pad or sign off the plot.

## Who gets which plot

1. The player joins and spawns at the lobby SpawnLocation while their save loads.
2. When the save is loaded (`DataService.profileLoaded`), they get the lowest free plot. The log shows
   `[Plot] plot assigned plot=N free=M`.
3. Their character is moved onto the plot's spawn pad, after Roblox streams that area in. Every respawn after that,
   including after falling off the map, lands on the pad too.
4. When they leave, the plot is free again (`[Plot] plot released`).

If all six plots are taken, a seventh player is asked to rejoin (`Strings.Plot.serverFull`). Max Players set to 6
keeps that from happening.

## Streaming

Rojo sets these on `Workspace` from `default.project.json` when it connects, and they are saved with the place:

| Setting | Value | Why |
| --- | --- | --- |
| `StreamingEnabled` | true | Plan section 4.8 |
| `StreamingMinRadius` | 128 | Always loaded around the player |
| `StreamingTargetRadius` | 640 | All six plots on a PC |
| `StreamOutBehavior` | Opportunistic | Drops far parts only when memory runs low |
| `StreamingIntegrityMode` | PauseOutsideLoadedArea | A player waits rather than falls through unloaded ground |

Each plot model streams as one whole unit. The owner's plot is persistent for them (`PersistentPerPlayer` plus
`AddPersistentPlayer`), so it never streams out. If streaming is off at startup, the server log warns
`Workspace.StreamingEnabled is off`: reconnect Rojo.

## Signs on the client

`PlotSignController` binds a `PlotSign` view to every model tagged `Plot` when it streams in, and drops it when it
streams out. The sign reads "Free plot", "Your factory" (your own) or "<name>'s factory", with "Plot N" below. It
reads the model's attributes, which PlotService sets:

| Attribute | Value |
| --- | --- |
| `PlotIndex` | 1 to 6 |
| `OwnerUserId` | the owner's user ID, 0 while free |
| `OwnerName` | the owner's display name, "" while free |

The attributes only display the assignment. The truth is in PlotService.
