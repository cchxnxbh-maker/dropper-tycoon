# 0011. A thin in-repo remote wrapper with one definitions file

- **Status:** Accepted
- **Date:** 2026-11-16
- **Decided by:** Build plan recommendation, accepted by Daniel

## Context

Every client-to-server message is an attack surface. Checks scattered across handlers get forgotten.

## Decision

Every remote is declared once in `src/shared/Network/Remotes.luau`, with its payload check (using `t`) and rate limit
beside it. `ClientNet` and `ServerNet` are a thin wrapper we own. `ServerNet` runs the same pipeline before any handler:
payload type, rate limit, session state is `Playing`. RemoteEvents by default; a RemoteFunction only from client to
server; the server never invokes a client. The Studio abuse suite is generated from the definitions file, so a new
remote is tested automatically.

## Alternatives considered

- **A code-generating library (such as Zap or ByteNet).** Faster serialisation, but another tool and build step that a
  six-player tycoon does not need.

## Consequences

- One file shows every way a client can talk to the server.
- If we switch libraries later, call sites stay the same as long as the wrapper API is kept.
