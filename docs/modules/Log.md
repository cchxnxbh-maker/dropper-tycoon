# Log

File: `src/shared/Util/Log.luau`. Specs: `tests/shared/Util/Log.spec.luau`. Plan section 4.10.

Tagged, levelled log lines with structured fields. Both server and client use it.

```luau
Log.info("Purchase", "bought", { userId = id, buildable = "CoalDropper" })
-- [INFO] [Purchase] bought buildable=CoalDropper userId=123
```

| Function | Does |
| --- | --- |
| `Log.debug / info / warn / error(tag, message, fields?)` | Writes a line if the tag's level allows it. `error` never throws |
| `Log.configure({ default?, tags? })` | Sets the default level (info) and per-tag levels. Unknown level names throw |
| `Log.enabled(level, tag)` | Whether such a line would be written |
| `Log.format(level, tag, message, fields?)` | The line's text without writing it |
| `Log.setSink(fn?)` | Sends lines elsewhere, for tests. `nil` restores `print` / `warn` |

Rules:

- Keep `message` fixed and put changing values in `fields`, so lines are easy to search and count.
- Fields are printed sorted by key. Strings with spaces, `=` or quotes are quoted.
- Fields carry the user ID and nothing more personal.
- `warn` and `error` lines go to Roblox's `warn`, the rest to `print`.

Coming later: task 7 feeds levels from `Config/Flags.luau` and adds the build version to every line. The repro bundle
(plan section 8.4) will keep recent lines.
