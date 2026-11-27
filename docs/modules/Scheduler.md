# Scheduler

File: `src/shared/Util/Scheduler.luau`. Specs: `tests/shared/Util/Scheduler.spec.luau`. Plan section 4.1.

The game loop. There is no global update function: each system registers its own named step.

```luau
Scheduler.every("FactorySim", Config.Tuning.Timing.simRate, function(dt) ... end, function(skipped) ... end)
Scheduler.onRender("ItemVisuals", function(dt, alpha) ... end, "FactorySim")  -- client only
```

| Function | Does |
| --- | --- |
| `Scheduler.every(name, rate, step, onSkipped?)` | A fixed-rate step. `step(dt)` always gets the same dt |
| `Scheduler.onRender(name, render, follows?)` | A per-frame callback, `render(dt, alpha)`. `alpha` is the progress of the fixed step named in `follows`, else 0 |
| `Scheduler.remove(name)` | Unregisters. Unknown names are ignored |
| `Scheduler.update(frameDt)` | Runs due fixed steps. Connected to `RunService.Heartbeat` in both `Main` scripts |
| `Scheduler.render(frameDt)` | Runs render callbacks. Connected to `RunService.RenderStepped` in the client `Main` |
| `Scheduler.alpha(name)` | A fixed step's progress, in [0, 1) |
| `Scheduler.reset()` | Removes everything, for tests |

Rules:

- At most `Config.Tuning.Timing.maxCatchUpSteps` (5) steps of one kind run in a frame. Time beyond that goes to `onSkipped`
  once, as seconds, so the owner pays it by formula (for the factory, the income-rate formula). A stall never costs
  cash and never spirals.
- Steps run in name order, never in require order. Names are unique across fixed and render steps.
- Each step runs inside a MicroProfiler label with its name.
- A step that errors is logged once (`[ERROR] [Scheduler] step failed`) and keeps being called; other steps still run.
- The module never touches RunService itself. Only the `Main` scripts connect it, inside a Trove.
