# 0012. Feature flags and tuning live in code for v1

- **Status:** Accepted
- **Date:** 2026-11-16
- **Decided by:** Build plan recommendation, accepted by Daniel

## Context

Some games change values on live servers without publishing. That adds a service, a failure mode and a second source
of truth.

## Decision

Flags (`Config/Flags.luau`) and tuning values (`Config/Tuning.luau`, `Config/Economy.luau`) live in code and change by
publishing. All config loads through one module, so a live source can be added behind it later.

## Alternatives considered

- **Values changeable without publishing.** Useful for live events, not needed before launch.

## Consequences

- Every value change goes through the check and the balance tool.
- A balance fix needs a publish.
