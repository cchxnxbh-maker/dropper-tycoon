# Network

Files: `src/shared/Network/` (`Remotes.luau`, `Net.luau`, `Guard.luau`, `RemoteFolder.luau`, `AbuseCases.luau`),
`src/shared/Logic/RateLimiter.luau`, `src/server/Net/` (`ServerNet.luau`, `Pipeline.luau`, `Handlers/`),
`src/client/Net/ClientNet.luau`, `src/server/Dev/AbuseSuite.luau`, `src/client/Dev/AbuseClient.luau`,
`src/client/Controllers/PingController.luau`.
Specs: `tests/shared/Network/`, `tests/shared/Logic/RateLimiter.spec.luau`, `tests/server/Net/Pipeline.spec.luau`.
Plan sections 3.6, 4.8 and 8.2. Decisions: ADR 0002, 0011, 0018.

Every message between client and server goes through one of the remotes declared in `Remotes.luau`. The server
checks every request before any handler sees it.

```luau
ClientNet.send(Remotes.RequestTestPing, { label = "hello" })          -- client
ClientNet.on(Remotes.TestPong, function(payload) ... end)              -- client
ServerNet.send(player, Remotes.TestPong, { label = "hello", serverTime = os.time() })  -- server
```

## What happens to a request

1. **Shape limits** (`Guard`): plain data only; no NaN, infinity or negative numbers; text at most
   `Tuning.Network.maxStringLength` (200); tables at most `maxTableDepth` (3) deep and `maxTableEntries` (32) wide.
   Extra arguments beyond the one payload also fail here.
2. **The remote's own rule**, written with `Logic/Validate` in `Remotes.luau`.
3. **The remote's rate limit** for this player: `burst` at once, then `perSecond`.
4. **Session state is Playing.** Until task 9 adds the session state machine, every player counts.
5. **The handler** in `server/Net/Handlers/<RemoteName>.luau`, which checks ownership, distance and price itself.

Steps 1 to 4 failing drop the request and add a strike. `kickAfterStrikes` (30) strikes inside
`strikeWindowSeconds` (60) kicks the player with `Strings.Net.kicked`. A payload rejection logs a warning; rate and
session rejections log at debug, so a lag burst does not flood the output. A handler error logs an error and is not a
strike.

The client checks its own requests against the same rule and keeps to `clientRateShare` (80%) of each limit, so an
honest client never gets a strike.

## Adding a remote

1. Add an entry to `src/shared/Network/Remotes.luau`. A client request:

   ```luau
   RequestPurchase = Net.toServer({
       payload = Validate.record({ buildableId = Validate.string({ pattern = "^%u%w*$", maxLength = 40 }) }),
       rate = { burst = 5, perSecond = 2 },
       example = { buildableId = "CoalDropper" },
   }),
   ```

   A server message: `StateSync = Net.toClient({ payload = <rule> })`. Names are PascalCase; requests start with
   `Request`.
2. For a client request, add `src/server/Net/Handlers/RequestPurchase.luau` returning
   `{ remote = Remotes.RequestPurchase, handle = function(player, payload) ... end }`, then run `lune run gen-index`.
3. Run `lune run check`. The abuse suite already covers the new request.

The example must pass its own rule, or the game refuses to load. A client request without a handler file logs an
error at server start.

## The abuse suite

`AbuseCases.all(Remotes)` builds, for every client request: the request replaced by each kind of bad value, the
request missing, an unknown field, then for each field: missing, wrong types, NaN, infinity, minus infinity, -1, text
one past the limit, 10,000 characters of text, tables too deep and too wide. Then the example once (must be accepted)
and 100 copies at once (must be rate limited). For `RequestTestPing` that is 126 requests.

- **In the check:** `tests/server/Net/Pipeline.spec.luau` runs them against the pipeline.
- **In Studio:** at the start of every playtest, while `Flags.Features.studioAbuseSuite` is on, the server puts the
  first player in audit mode, that player's client fires every case through the real RemoteEvents, and the server
  prints one line:

  ```
  [INFO] [AbuseSuite] PASSED: every hostile request was rejected and state is unchanged cases=126
  ```

  or a `FAILED` line after one error line per mismatch. Audit mode skips handlers and never kicks. Afterwards the
  client sends a normal `RequestTestPing` and logs `[INFO] [Ping] pong label=hello serverTime=...`.

Not yet covered: IDs the player does not own. That needs ownership, which arrives from task 9 on.
