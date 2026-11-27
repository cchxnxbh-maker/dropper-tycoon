# 0015. How the check runs: one Lune command, a pre-commit hook and GitHub Actions

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decided by:** Claude's recommendation for task 4, accepted by Daniel when he merges the pull request

## Context

Plan section 7.5 says one command, `lune run check`, decides whether a change is acceptable, and that a Git
pre-commit hook and CI run the same command. Task 4 builds it. A few details the plan leaves open had to be chosen:
where the scripts live, how type analysis gets Roblox's types, how the hook is installed and what CI uses.

## Decision

- **Entry points in `.lune/`, work in `tools/`.** Lune finds `lune run <name>` scripts in `.lune/`. Those files are
  three lines each and call `tools/check.luau` and `tools/test.luau`, so the plan's `tools/` folder still holds the
  code.
- **Steps today:** StyLua `--check`, Selene, `rojo sourcemap` then `luau-lsp analyze`, then the unit tests. It stops
  at the first failure. Index regeneration and the literal, boundary, docs and config checks join in task 7 and later.
- **luau-lsp 1.70.1 is pinned in `rokit.toml`** (the release current on 2026-11-27). This adds a tool, which is why
  this record exists.
- **Roblox type definitions** come from luau-lsp's own repository at the pinned tag
  (`scripts/globalTypes.None.d.luau`, the level normal game scripts run at). The check downloads the file once into
  `.cache/`, which Git ignores. Updating the luau-lsp pin updates the definitions with it.
- **Selene project rules.** `selene.toml` uses the standard library `project+roblox` (the first library wins where
  both define a name). `project.yml` marks `wait`, `spawn`, `delay` and `math.random` deprecated with the replacement
  in the message, and `selene.toml` makes the `deprecated` lint an error.
- **Pre-commit hook in `.githooks/pre-commit`**, turned on once per clone with `git config core.hooksPath .githooks`.
  Git does not copy hooks on clone, so this keeps the hook in the repository instead of in each PC's `.git` folder.
- **GitHub Actions, `.github/workflows/check.yml`.** Runs on every push to any branch. It uses
  `actions/checkout@v7`, `actions/cache@v6` and `CompeyDev/setup-rokit@v0.2.1` (Rokit v1.2.0), which installs the
  tools from `rokit.toml`, then `wally install`, then `lune run check`.

## Alternatives considered

- **Commit the type definitions file.** No download, but about a megabyte that changes on every update, and easy to
  leave out of step with the analyzer.
- **Hooks through a hook manager (pre-commit, Husky, Lefthook).** Another tool to install on Daniel's PC for one
  three-line script.
- **Run CI on pull requests too.** Every branch is pushed to this repository, so `push` already covers each pull
  request. Running both would double the runs.
- **Install Rokit in CI with its install script from `main`.** Unpinned. The action takes a pinned Rokit version.

## Consequences

- One command means the same thing on Daniel's PC, in a cloud session and in CI.
- The first check on a new machine needs internet to fetch the definitions. After that it works offline.
- The hook can be skipped with `git commit --no-verify`. CLAUDE.md forbids that for the agent, and CI catches it.
- Cloud sessions cannot download tools through Rokit, so they build the same pinned versions another way. That does
  not change what the check runs.
- Changing what the check enforces still needs a decision record and Daniel's approval (CLAUDE.md).
