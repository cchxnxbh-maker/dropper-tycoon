# 0009. Version 1 game rules

- **Status:** Accepted
- **Date:** 2026-11-16
- **Decided by:** Daniel (build plan section 2 and project inputs)

## Context

These design answers shape the save format, config and balance checks, so code must respect them.

## Decision

| Topic | Rule |
| --- | --- |
| Players per server | 6, one plot each. Light social: leaderboards and visiting. No player-versus-player |
| How players buy | Walk-over pads plus a shop list. Both send the same request |
| v1 content size | Small: 2 base tiers with about 25 buy buttons, plus 1 tier unlocked with prestige points |
| Offline earnings | Capped at 2 hours at half rate, paid once. Prestige perks raise the cap and the rate |
| Number scale | Cash stays under 1e15 per rebirth cycle. The balance tool fails if a simulated cycle goes over |
| Rebirth | A prestige currency with perks, not a single multiplier. Details in ADR 0010 |
| Audience | Launch to players 16 and over, then qualify for younger audiences. Content rated Minimal or Mild |
| Devices | PC for v1. Input goes through an action layer and UI is scale-based, so touch and gamepad can follow |
| Monetization | None in v1. After launch: game passes and developer products, never random rewards |
| Art and sound | Greybox first, then free Creator Store assets Daniel approves |

## Alternatives considered

The options for each topic are listed in build plan section 2.

## Consequences

- Whole numbers stay exact and leaderboards stay simple.
- A `Monetization` service stub and a multiplier pipeline exist from the start, so the post-launch phase adds files.
