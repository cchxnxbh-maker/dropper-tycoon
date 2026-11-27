# 0004. Rojo syncs code; the place file holds the world

- **Status:** Accepted
- **Date:** 2026-11-16
- **Decided by:** Build plan recommendation, accepted by Daniel

## Context

Code must live in files under Git so the agent can edit it, the check can test it, and every change can be undone. The
map and models are built visually in Studio and do not diff well as text.

## Decision

Rojo syncs `src/` into Studio as described by `default.project.json`. All code lives in files and is never edited
inside Studio. The map, plot template and models live in `place/Game.rbxl`, stored with Git LFS, and are committed at
each milestone and around large world edits. Rojo ignores unknown instances, so syncing code never deletes anything
built in Studio.

## Alternatives considered

- **Studio's own Script Sync.** Still in beta, and it has no single project file under Git that says where everything
  goes. The wider toolchain (luau-lsp) reads Rojo's sourcemap.
- **Model files managed by Rojo syncback.** Possible later. Starting with the place file is simpler.

## Consequences

- Code is diffable, testable and reversible. The world is versioned too, but only as whole snapshots.
- Moving the world into model files later is a one-time export.
