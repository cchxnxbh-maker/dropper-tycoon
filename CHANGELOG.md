# Changelog

## Unreleased

- feat: core utilities. `Log` (tagged levelled lines), `Rng` (seeded named streams, ADR 0016), `FixedStep` and `Scheduler` (fixed 10 Hz steps, at most 5 per frame, skipped time paid by formula), with specs for frame-rate independence at 30, 60 and 144 frames per second and the catch-up cap. Both `Main` scripts now drive the Scheduler, and the server logs its session seed.
- tool: the check (`lune run check`): StyLua, Selene with the project rules, luau-lsp type analysis and Lune unit tests through the new `tools/testkit.luau`. Runs before every commit through `.githooks/pre-commit` and on every push in GitHub Actions (ADR 0015).
- docs: agent rules (`CLAUDE.md`), full README with Windows steps, decision-record template and records 0001 to 0014 for the decisions made so far.
- tool: repository scaffold (folder structure, Rojo project, pinned tools and packages, lint and format configs, Git LFS rules).
