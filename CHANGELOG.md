# Changelog

## Unreleased

- tool: the check (`lune run check`): StyLua, Selene with the project rules, luau-lsp type analysis and Lune unit tests through the new `tools/testkit.luau`. Runs before every commit through `.githooks/pre-commit` and on every push in GitHub Actions (ADR 0015).
- docs: agent rules (`CLAUDE.md`), full README with Windows steps, decision-record template and records 0001 to 0014 for the decisions made so far.
- tool: repository scaffold (folder structure, Rojo project, pinned tools and packages, lint and format configs, Git LFS rules).
