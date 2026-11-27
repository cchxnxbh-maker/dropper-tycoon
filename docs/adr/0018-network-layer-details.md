# 0018. How the network layer is built

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decided by:** Claude's recommendation, accepted by Daniel

## Context

ADR 0011 settles the shape: one `Remotes.luau`, a thin `ClientNet` and `ServerNet`, the same pipeline before every
handler, and an abuse suite generated from the definitions. Task 8 had to fill in what the plan leaves open, and in
two places the plan's sketch does not fit the rest of the code:

- ADR 0011 says payload checks use the `t` package. Packages are not available to Lune tests (or in the cloud
  container), so a `t`-based rule could only be tested inside Studio. Task 7 already built `Logic/Validate.luau`,
  whose rules run in Lune and in Roblox and print readable lines.
- The plan puts `RateLimiter` in `server/Net/`, but the client needs the same bucket maths to stay under the limit,
  and client code may not require server code.

## Decision

- **Payload rules use `Logic/Validate`, not `t`.** `Validate.string` gains `maxLength`; `Validate.number` now
  refuses infinity as it already refused NaN. `t` stays in `wally.toml` for now, unused; it can be removed the next
  time Daniel updates packages on his PC, since `wally.lock` is made there.
- **Shape limits on every request (`Network/Guard.luau`).** Before a remote's own rule runs, every client request
  must be plain data with no NaN, no infinity, no negative numbers, no text over 200 characters and no tables deeper
  than 3 or wider than 32. Clients send IDs only, so an honest request never hits these. The limits are in
  `Config/Tuning.luau` under `Network`.
- **`RateLimiter` is pure and lives in `shared/Logic`.** Token buckets (`burst`, then `perSecond`), time passed in.
  The client keeps itself to 80% of each limit (`clientRateShare`) so network jitter never gives an honest player a
  strike.
- **The pipeline is a pure module, `server/Net/Pipeline.luau`.** Payload check, rate limit, session state is
  Playing, then the handler, in that order. Each failure is a strike; 30 strikes inside 60 seconds kicks the player
  with the text from `Config/Strings.luau`. Handler errors are logged but are not the player's fault, so no strike.
  `ServerNet` is the thin Roblox glue around it. Until the session state machine arrives (task 9), every player in
  the server counts as Playing.
- **Strike thresholds are in shared `Tuning`, not a server-only config.** The plan suggested hiding them. Knowing the
  threshold gives an exploiter nothing: every request is still checked and rate limited whatever the strike count.
- **RemoteEvents only, for now.** `Net.toServer` and `Net.toClient` make events. A client-to-server RemoteFunction can
  be added when a feature needs a reply; the server never invokes a client.
- **Remote instances are made in `Network/RemoteFolder.luau`**, so the future boundary check can say "no file outside
  `Network/` creates a remote" and mean it.
- **One handler file per client request in `server/Net/Handlers/`**, named after its remote and indexed by
  `gen-index`, as plan section 6 asks.
- **The abuse suite runs in two places.** `Network/AbuseCases.luau` builds every hostile request from each remote's
  example (wrong types, missing and unknown fields, huge text, NaN, infinity, negatives, deep and wide tables, then
  100 calls at once). The Lune spec runs them against the pipeline. In every Studio playtest (while
  `Flags.Features.studioAbuseSuite` is on), the player's client fires them through the real RemoteEvents and the
  server, in audit mode, checks each outcome and prints one PASSED or FAILED line. Audit mode skips handlers and
  never kicks, so the suite changes no game state.
- **New client folders `Net/` and `Dev/`, and a server `Dev/` folder.** ADR 0004's table lists the main client
  folders; these join them. `Dev/` holds Studio-only test code.

## Alternatives considered

- **Keep `t`.** Matches ADR 0011 word for word, but the payload rules could then only be tested in Studio, and the
  project would have two ways of writing the same kind of rule.
- **Server-only abuse suite in Studio** that calls the pipeline directly. Simpler, but it would not prove that the real
  RemoteEvents exist, replicate and deliver in order.

## Consequences

- Players: no visible change. An honest player never meets these limits; someone spamming or sending forged requests
  is ignored and, far over the limit, disconnected.
- Adding a client request is one entry in `Remotes.luau` (rule, rate, example) and one handler file. The abuse suite
  covers it with no new test.
- Every Studio playtest prints one abuse-suite line at the start. Switch `studioAbuseSuite` off in `Flags.luau` if it
  ever gets in the way.
- "IDs the player does not own" joins the suite when ownership exists (from task 9 on).
