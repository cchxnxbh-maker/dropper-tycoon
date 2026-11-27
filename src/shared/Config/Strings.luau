--!strict
-- Strings: all player-facing text, grouped by system and then by key (plan section 5.1). Code never writes a sentence a
-- player sees; it reads one from here, so wording changes in one place and translation can come later.
-- Read it through `Config`, which validates and freezes it.
--
-- State owned: none. Read-only data.
--
-- Usage:
--     local Config = require("../Config")
--     player:Kick(Config.Strings.Net.kicked)

local Types = require("../Types/Config")

local Strings: Types.Strings = {
	Net = {
		-- Shown when the server disconnects a player for sending far too many bad or rapid requests.
		kicked = "You were disconnected for sending too many requests. Please rejoin.",
	},
}

return Strings
