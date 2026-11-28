--!strict
-- Remotes: every way the client and server talk, in one file (plan section 3.6, ADR 0011). No other file declares a
-- remote. `ServerNet` creates one RemoteEvent per entry; `ClientNet` finds them.
--
-- Rules for a new entry: client requests start with `Request` and carry IDs only, never prices, amounts or
-- positions. Give each request a rate limit that fits how often a real player could press the button, and an example
-- that passes its rule. The abuse suite then tests it automatically. Add one handler file in `server/Net/Handlers/`.
--
-- Assume every exploiter can read this file. Nothing here is a secret.
--
-- State owned: none.
--
-- Usage:
--     ClientNet.send(Remotes.RequestTestPing, { label = "hello" })
--     ServerNet.send(player, Remotes.TestPong, { label = "hello", serverTime = os.time() })

local Net = require("./Net")
local Validate = require("../Logic/Validate")

local Remotes = Net.define({
	-- The test remote from task 8: the client says hello, the server answers with TestPong. It proves the pipeline
	-- end to end until real requests arrive, and it changes no state.
	RequestTestPing = Net.toServer({
		payload = Validate.record({
			label = Validate.string({ pattern = "^%w+$", hint = "like hello (letters and digits)", maxLength = 32 }),
		}),
		rate = { burst = 5, perSecond = 2 },
		example = { label = "hello" },
	}),
	TestPong = Net.toClient({
		payload = Validate.record({
			label = Validate.string({ maxLength = 32 }),
			serverTime = Validate.number({ min = 0 }),
		}),
	}),
	-- The dev panel asks the server to run one dev command by name (task 10). The server decides who may: Studio, the
	-- experience owner and the allow-list in `server/Config/DevAccess.luau`. Anyone else is ignored.
	RequestDevCommand = Net.toServer({
		payload = Validate.record({
			command = Validate.string({
				pattern = "^%u%w*$",
				hint = "like AddTestCounter (PascalCase)",
				maxLength = 40,
			}),
		}),
		rate = { burst = 5, perSecond = 3 },
		example = { command = "AddTestCounter" },
	}),
	-- What the dev panel shows. Sent only to players allowed to use it: on join, and after each command.
	DevPanelState = Net.toClient({
		payload = Validate.record({
			testCounter = Validate.number({ integer = true, min = 0 }),
		}),
	}),
})

return Remotes
