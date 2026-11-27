# 0014. Separate Dev and Live experiences; Daniel publishes Live

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decided by:** Build plan (section 7.6), set up by Daniel in task 1

## Context

Testing must never touch real player saves, and a bad publish must not reach players by accident.

## Decision

Two private experiences exist: **Dropper Tycoon Dev** and **Dropper Tycoon Live**. Each has its own data stores. The
agent may publish to Dev to run the QA checklist on a real server. Publishing to Live is Daniel's click in v1, on
purpose.

## Alternatives considered

- **One experience with a test flag.** Test data would share stores with real players.
- **Automated publish through Open Cloud.** Possible later. Left out because a manual click is a useful safety check.

## Consequences

- A release is a short manual checklist (build plan section 7.6, later `docs/RUNBOOK.md`).
