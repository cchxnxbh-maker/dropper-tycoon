# FixedStep

File: `src/shared/Util/FixedStep.luau`. Specs: `tests/shared/Util/FixedStep.spec.luau`. Plan section 4.1.

An accumulator that turns uneven frame times into whole fixed-length steps. `Scheduler` uses one per fixed step; other
code rarely needs it directly.

```luau
local clock = FixedStep.new(10, 5)            -- 10 steps per second, at most 5 per call
local steps, skipped = clock:advance(frameDt)
for _ = 1, steps do simulate(clock.dt) end
if skipped > 0 then payByFormula(skipped) end
```

| Member | Does |
| --- | --- |
| `FixedStep.new(rate, maxSteps)` | A clock. Throws on a rate that is not positive or a cap below 1 |
| `clock.dt` | The constant step length in seconds |
| `clock:advance(frameDt)` | Returns steps due now (0 to `maxSteps`) and seconds skipped past the cap |
| `clock:alpha()` | Progress toward the next step, in [0, 1), for drawing between states |
| `clock:reset()` | Drops accumulated time |

Rules:

- Negative, NaN and infinite frame times count as 0.
- A tiny tolerance (1e-9 of a step) makes float sums such as 144 frames of 1/144 count as whole steps, so 30, 60 and
  144 frames per second reach each step on the same frame time.
- Steps run plus seconds skipped plus the accumulator always add up to the time put in. Nothing is lost in a stall.
