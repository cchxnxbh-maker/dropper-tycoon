# 0001. Record decisions as short decision records

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decided by:** Build plan (section 9), accepted by Daniel

## Context

The coding agent starts every session with no memory, and Daniel does not review code line by line. Without a written
record, a later session cannot tell a deliberate choice from an accident, and may undo it.

## Decision

Every significant decision gets a record in `docs/adr/NNNN-title.md`, using `0000-template.md`. A record is written when
a row in section 2 of the build plan is decided, when a dependency is added, or when a check changes. Accepted records
are not edited. A new record supersedes an old one. `docs/adr/README.md` is the index.

The build plan stays as the founding document. When reality differs from it, a record says why.

## Alternatives considered

- **Keep decisions only in the build plan.** The plan is long and lives outside the repository, so an agent working in
  the repo would not see it reliably.
- **Keep decisions in chat or commit messages.** Neither survives in a form a new session reads.

## Consequences

- Any session can learn why the code is the way it is by reading one folder.
- Each decision costs a few minutes of writing.
