# Backlog

Ideas and known gaps for later, with an ID that `TODO(B-n)` comments can name. Newest last. When one is done, delete
its line in the same branch.

| ID | What | Why it waits |
| --- | --- | --- |
| B-1 | Count a strike when a handler refuses a request the client could never honestly send (purchase `unknown`, `owned`, `locked`, `tooFar`) | The pipeline has no strike call for handlers yet; refusals are logged |
| B-2 | Draw items on other players' plots within 150 studs (plan section 4.12) | Needs every plot's factory state sent to nearby players; own plot first |
| B-3 | Path-based state patches in ClientStore for the whole save (plan section 4.8) | Only cash and the factory need mirroring in Phase 1 |
| B-4 | Remove the unused `t` package from `wally.toml` and regenerate `wally.lock` on Daniel's PC | Wally cannot run in the cloud container |
