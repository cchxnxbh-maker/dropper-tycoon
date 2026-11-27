# 0007. UI built from plain view modules over a small kit

- **Status:** Accepted
- **Date:** 2026-11-16
- **Decided by:** Build plan recommendation, accepted by Daniel

## Context

UI must live in Git and be testable, and it must later adapt to touch and gamepad without a rewrite.

## Decision

UI is built by code. Each screen is a module in `src/client/UI/Screens/`, built from a small kit of buttons, lists and a
theme in `src/client/UI/Kit/`. UI state lives in `ClientStore` and `UIController`, separate from the views. StarterGui
stays empty. Layout is scale-based.

## Alternatives considered

- **Fusion or React-Luau.** Reactive and powerful, but another library and another way of thinking to maintain for a
  game with a handful of screens.
- **UI built by hand in Studio.** Not diffable or testable.

## Consequences

- Screens are simple to read and test for mount and unmount leaks.
- Because state is separate, moving to a reactive library later changes only the view layer.
